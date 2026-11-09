import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/find_work/controller/find_work_controller.dart';
import 'package:working_trust/features/find_work/models/project_model.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/models/profile_entries.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

Map<String, WidgetBuilder> routeTable() =>
    Map<String, WidgetBuilder>.of(AppRoutes.routes)
      ..remove(Navigator.defaultRouteName);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _settle(tester);
}

/// A published project, which is the only kind a proposal can highlight: the
/// bid route stores the id the portfolio route handed back.
PortfolioItem _published(String id, String title) => (
  id: id,
  title: title,
  image: 'https://cdn.example/$id.png',
  kind: 'image',
  link: '',
  status: 'PUBLISHED',
  role: '',
  skills: const [],
  description: '',
);

/// Walks the real path: an open project's Apply Now button. The project comes
/// off the board the fake backend served, so the form is handed exactly the
/// fields `GET /api/tasks` answers with.
Future<void> _openProposal(WidgetTester tester, {double width = 400}) async {
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await FindWorkController.instance.load();
  final ProjectModel project = FindWorkController.instance.byId('t1');
  var opened = false;
  await tester.pumpWidget(
    MaterialApp(
      routes: routeTable(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            if (!opened) {
              opened = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushNamed(
                  context,
                  RouteNames.projectDetail,
                  arguments: project,
                );
              });
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await _settle(tester);
  expect(find.text('Apply Now'), findsOneWidget);
  await _tap(tester, find.text('Apply Now'));
  expect(
    find.text('Submit a proposal'),
    findsOneWidget,
    reason: 'the form should be on screen at ${width}dp',
  );
}

Future<void> _typeCover(WidgetTester tester, String text) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Tell the client why you are the right fit'),
    text,
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    await _backend.install();
    // Only a signed-in device can put a bid on a project.
    _backend.issueSessionCookie();
    ProfileController.instance.clear();
    FindWorkController.instance.clear();
    _backend.storedConnects = 134;
    WalletController.instance.clear();
    // The rate a proposal pre-fills with is the one this device last stored on
    // the profile; the backend never returns it, so the test supplies it.
    ProfileController.instance.update(hourlyRate: '\$10/hr');
    ProfileController.instance.portfolio
      ..add(_published('r1', 'Frenco – Landing Page UI/UX Design'))
      ..add(_published('r2', 'SkillVexa – Landing Page UI/UX Design'));
  });

  testWidgets('the form shows every section from the design', (tester) async {
    await _openProposal(tester);

    for (final label in [
      'Job details',
      'View job',
      'Proposal Details',
      'This proposal requires:  ',
      '40 Bids',
      "When you submit this proposal, you'll have 94 Bids remaining",
      "What is the rate you'd like to bid for",
      'Service fee 20%',
      'Hourly Rate',
      "You'll Receive",
      'Additional Details',
      'Cover Letter',
      'Attachments',
      'Attach files',
      'Up to 5 files, uploaded with your proposal',
      'Portfolio Highlight',
      'Add Portfolio Project',
      'Submit Proposal',
    ]) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the job details card carries the server\'s own numbers', (
    tester,
  ) async {
    await _openProposal(tester);

    expect(find.text('Shopify Store Redesign'), findsWidgets);
    expect(find.textContaining('Finish the remaining setup'), findsWidgets);
    expect(find.text('Medium'), findsWidgets);
    expect(find.text('2 days'), findsWidgets);
    expect(find.text('\$ 230.00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bid rate drives the amount the freelancer receives', (
    tester,
  ) async {
    await _openProposal(tester);

    expect(find.text('\$8.00/hr'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '0.00'), '45.50');
    await tester.pump();

    expect(find.text('\$36.40/hr'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a proposal shorter than the backend\'s minimum is refused '
      'before it leaves the device', (tester) async {
    await _openProposal(tester);

    await _tap(tester, find.text('Submit Proposal'));

    expect(
      find.text('Write a clear proposal (min 20 characters).'),
      findsOneWidget,
    );
    expect(WalletController.instance.value.connects, 134);
    expect(
      _backend.paths.where((path) => path.endsWith('/bid')),
      isEmpty,
      reason: 'nothing was asked of the server',
    );
  });

  testWidgets('a rate the route would reject is caught on the form', (
    tester,
  ) async {
    await _openProposal(tester);

    await tester.enterText(find.widgetWithText(TextField, '0.00'), '3');
    await _typeCover(tester, 'I have rebuilt three Shopify stores this year.');
    await _tap(tester, find.text('Submit Proposal'));

    expect(
      find.text('The bid rate must be between \$5 and \$10000'),
      findsOneWidget,
    );
    expect(_backend.paths.where((path) => path.endsWith('/bid')), isEmpty);
  });

  testWidgets('submitting sends a real bid and spends the Bids', (
    tester,
  ) async {
    await _openProposal(tester);

    await _typeCover(tester, 'I have rebuilt three Shopify stores this year.');
    await _tap(tester, find.text('Submit Proposal'));
    await _settle(tester);

    final sent = _backend.bodyFor('/api/tasks/t1/bid');
    expect(sent['proposal'], 'I have rebuilt three Shopify stores this year.');
    expect(sent['bidAmount'], 10.0);
    expect(_backend.bids, hasLength(1));
    expect(find.text('Proposal sent. 40 Bids deducted.'), findsOneWidget);
    expect(WalletController.instance.value.connects, 94);
    // Popping the form lands back on the project, which now reads Applied.
    expect(find.text('Applied'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the server refusing the bid is shown in its own words', (
    tester,
  ) async {
    await _openProposal(tester);

    _backend.storedConnects = 10;
    await _typeCover(tester, 'I have rebuilt three Shopify stores this year.');
    await _tap(tester, find.text('Submit Proposal'));
    await _settle(tester);

    expect(
      find.text('Not enough connects. Buy a package first.'),
      findsOneWidget,
    );
    expect(find.text('Buy Bids'), findsOneWidget);
    expect(WalletController.instance.value.connects, 134);
    expect(_backend.bids, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portfolio projects can be added and removed', (tester) async {
    await _openProposal(tester);

    expect(find.text('Frenco – Landing Page UI/UX Design'), findsNothing);

    await _tap(tester, find.textContaining('Add Portfolio Project'));
    expect(find.text('Portfolio projects'), findsOneWidget);

    await _tap(tester, find.text('SkillVexa – Landing Page UI/UX Design'));
    await _tap(tester, find.text('Done'));

    expect(find.text('SkillVexa – Landing Page UI/UX Design'), findsOneWidget);

    await _tap(tester, find.byIcon(Icons.close).first);
    expect(find.text('SkillVexa – Landing Page UI/UX Design'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a highlighted project is sent as the server\'s own id', (
    tester,
  ) async {
    await _openProposal(tester);

    await _tap(tester, find.textContaining('Add Portfolio Project'));
    await _tap(tester, find.text('Frenco – Landing Page UI/UX Design'));
    await _tap(tester, find.text('Done'));

    await _typeCover(tester, 'I have rebuilt three Shopify stores this year.');
    await _tap(tester, find.text('Submit Proposal'));
    await _settle(tester);

    expect(_backend.bodyFor('/api/tasks/t1/bid')['portfolioItemIds'], [
      'r1',
    ], reason: 'the id the portfolio route stored, not the title');
  });

  testWidgets('an empty portfolio says so instead of offering a fake list', (
    tester,
  ) async {
    ProfileController.instance.portfolio.clear();
    await _openProposal(tester);

    expect(
      find.text('Publish a project in your profile to highlight one here.'),
      findsOneWidget,
    );
    expect(find.text('Add Portfolio Project'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the font menu restyles the cover letter', (tester) async {
    await _openProposal(tester);

    await _tap(tester, find.text('Font'));
    await _tap(tester, find.text('Monospace'));

    final field = tester.widget<TextField>(
      find.widgetWithText(
        TextField,
        'Tell the client why you are the right fit',
      ),
    );
    expect(field.style?.fontFamily, 'monospace');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the form stays usable from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _openProposal(tester, width: width);
      await _typeCover(tester, 'Short pitch.');
      expect(
        find.text('Submit Proposal'),
        findsOneWidget,
        reason: '${width}dp',
      );
      expect(tester.takeException(), isNull, reason: 'proposal at ${width}dp');
    }
  });

  testWidgets('the route is registered for the proposal form', (tester) async {
    expect(AppRoutes.routes.containsKey(RouteNames.submitProposal), isTrue);
  });
}
