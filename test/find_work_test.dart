import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/core/widgets/app_text_field.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/find_work/controller/find_work_controller.dart';
import 'package:working_trust/features/find_work/models/project_model.dart';
import 'package:working_trust/features/find_work/screens/find_work_screen.dart';
import 'package:working_trust/features/find_work/services/proposal_attachment_service.dart';
import 'package:working_trust/features/find_work/widgets/project_card.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();
FindWorkController get _board => FindWorkController.instance;

/// A short, unambiguous wait: one frame for the notification, then the read.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpBoard(
  WidgetTester tester, {
  double width = 400,
  double height = 2000,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      routes: Map<String, WidgetBuilder>.of(AppRoutes.routes)
        ..remove(Navigator.defaultRouteName),
      home: Scaffold(body: const FindWorkScreen()),
    ),
  );
  await _settle(tester);
}

/// Types into the board's search field and waits out the debounce.
Future<void> _search(WidgetTester tester, String word) async {
  await tester.enterText(find.byType(TextField).first, word);
  await tester.pump(FindWorkController.searchDelay);
  await _settle(tester);
}

List<String> get _ids => [for (final p in _board.results) p.id];

/// The list of paths that carry a query, so a filter can be read back.
List<Uri> get _taskUris => [
  for (final request in _backend.requests)
    if (request.url.path == '/api/tasks') request.url,
];

void main() {
  setUp(() async {
    await _backend.install();
    _backend.issueSessionCookie();
    ProfileController.instance.clear();
    _backend.storedConnects = 134;
    WalletController.instance.clear();
    _board.clear();
  });

  testWidgets(
    'the board is public, so a signed-out device still sees projects',
    (tester) async {
      await _backend.install();
      _board.clear();
      await _pumpBoard(tester);

      expect(_backend.paths, contains('/api/tasks'));
      expect(_board.status, FindWorkStatus.ready);
      expect(_board.results, hasLength(4));
      expect(
        _backend.requests.first.headers['cookie'],
        isNot(contains('next-auth.session-token')),
        reason: 'the route needs no session',
      );
    },
  );

  testWidgets('the server\'s own order, fields and page size arrive', (
    tester,
  ) async {
    await _pumpBoard(tester);

    expect(_ids, ['t1', 't2', 't4', 't3']);
    final first = _board.byId('t1');
    expect(first.title, 'Shopify Store Redesign');
    expect(first.level, 'Medium');
    expect(first.category, 'E-Commerce');
    expect(first.proposals, 12);
    expect(first.budget, 230);
    expect(first.proposalCost, 40);
    expect(first.duration, '2 days');
    expect(first.clientRating, 4.6);
    expect(first.spentLabel, '\$200k');
    expect(first.paymentVerified, isTrue);
    expect(_board.errorMessage, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deadline written only in hours still gets a label', (
    tester,
  ) async {
    await _pumpBoard(tester);

    expect(_board.byId('t2').duration, '72 hours');
    expect(_board.byId('t3').duration, '3 weeks');
    // The route can leave the spend out, and the card must not guess.
    expect(_board.byId('t2').spentLabel, isNull);
    expect(find.text('No client spend recorded'), findsWidgets);
  });

  testWidgets('the board is read once and only asked again on purpose', (
    tester,
  ) async {
    await _pumpBoard(tester);
    expect(_backend.countOf('/api/tasks'), 1);

    // Nothing on a timer: the clock can run without the app talking.
    await tester.pump(const Duration(seconds: 30));
    expect(_backend.countOf('/api/tasks'), 1);

    await _board.refresh();
    await _settle(tester);
    expect(_backend.countOf('/api/tasks'), 2);

    // The same filters are not asked for twice.
    await _board.load();
    await _settle(tester);
    expect(_backend.countOf('/api/tasks'), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coming back to the foreground reads the board again', (
    tester,
  ) async {
    await _pumpBoard(tester);
    final before = _backend.countOf('/api/tasks');
    final binding = TestWidgetsFlutterBinding.instance;

    // ignore: invalid_use_of_visible_for_testing_member
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(minutes: 1));
    expect(
      _backend.countOf('/api/tasks'),
      before,
      reason: 'nothing on a timer',
    );

    // ignore: invalid_use_of_visible_for_testing_member
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(_backend.countOf('/api/tasks'), before + 1);
  });

  testWidgets('rapid typing costs one request and searches the server', (
    tester,
  ) async {
    await _pumpBoard(tester);

    for (final word in ['s', 'sh', 'sho', 'shop', 'shopify']) {
      await tester.enterText(find.byType(TextField).first, word);
      await tester.pump();
    }
    expect(
      _backend.countOf('/api/tasks'),
      1,
      reason: 'the debounce is running',
    );

    await tester.pump(FindWorkController.searchDelay);
    await _settle(tester);

    expect(_backend.countOf('/api/tasks'), 2);
    expect(_taskUris.last.queryParameters['q'], 'shopify');
    expect(_ids, ['t1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the search button skips the wait but never repeats a word', (
    tester,
  ) async {
    await _pumpBoard(tester);

    await tester.enterText(find.byType(TextField).first, 'landing');
    await tester.pump();
    await tester.tap(find.text('Search Projects'));
    await _settle(tester);

    expect(_taskUris.last.queryParameters['q'], 'landing');
    expect(_backend.countOf('/api/tasks'), 2);

    // Tapping again with nothing changed asks for the same page.
    await tester.tap(find.text('Search Projects'));
    await _settle(tester);
    expect(_backend.countOf('/api/tasks'), 2);
  });

  testWidgets('an in-flight read is never stacked behind a second one', (
    tester,
  ) async {
    _backend.slowTasks = true;
    await _pumpBoard(tester);

    await tester.enterText(find.byType(TextField).first, 'data');
    await tester.pump(FindWorkController.searchDelay);
    final inFlight = _backend.countOf('/api/tasks');
    expect(_board.isRefreshing, isTrue);

    await _board.refresh();
    await _board.load();
    expect(
      _backend.countOf('/api/tasks'),
      inFlight,
      reason: 'a second read is never stacked',
    );

    // The filters move underneath the open read, so exactly one more is made
    // once it lands — with both filters on it.
    _board.setCategory('writing');
    expect(_backend.countOf('/api/tasks'), inFlight);

    await tester.pump(const Duration(milliseconds: 300));
    await _settle(tester);
    expect(_backend.countOf('/api/tasks'), inFlight + 1);
    expect(_taskUris.last.queryParameters['q'], 'data');
    expect(_taskUris.last.queryParameters['category'], 'writing');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a category is the route\'s filter, not a client-side slice', (
    tester,
  ) async {
    await _pumpBoard(tester);

    _board.setCategory('writing');
    await _settle(tester);

    expect(_taskUris.last.queryParameters['category'], 'writing');
    expect(_ids, ['t4']);
  });

  testWidgets('the filter sheet reads the categories once', (tester) async {
    await _pumpBoard(tester);
    expect(_backend.countOf('/api/categories'), 0, reason: 'lazy by design');

    await tester.tap(find.text('Filters'));
    await _settle(tester);

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Web Development'), findsOneWidget);
    expect(_board.categories, hasLength(3));

    await _board.loadCategories();
    expect(_backend.countOf('/api/categories'), 1);
  });

  testWidgets('the filter sheet scrolls on a short screen instead of '
      'overflowing', (tester) async {
    // The category list plus the level chips and the switch are taller than a
    // phone, and the sheet used to be capped at half the screen: the whole
    // filter has to stay reachable by scrolling, with nothing painted over.
    await _pumpBoard(tester, width: 320, height: 640);

    // The hero panel makes the board taller than a short phone's first screen,
    // so the filter pill has to be scrolled to before it can be tapped.
    await tester.ensureVisible(find.text('Filters'));
    await _settle(tester);
    await tester.tap(find.text('Filters'));
    await _settle(tester);

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Web Development'), findsOneWidget);

    await tester.ensureVisible(find.text('Clear all'));
    await _settle(tester);
    expect(
      tester.getRect(find.text('Clear all')).bottom,
      lessThanOrEqualTo(640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('level and payment verified are the device\'s own switches', (
    tester,
  ) async {
    await _pumpBoard(tester);

    _board.toggleLevel('Small');
    await tester.pump();
    expect(_ids, ['t2', 't4']);

    _board.setVerifiedOnly(true);
    await tester.pump();
    expect(_ids, ['t4']);
    expect(_board.hasFilters, isTrue);

    _board.clearFilters();
    await _settle(tester);
    expect(_ids, ['t1', 't2', 't4', 't3']);
    expect(_board.hasFilters, isFalse);
  });

  testWidgets('Matches ranks the loaded board by the profile\'s own title', (
    tester,
  ) async {
    ProfileController.instance.update(title: 'Shopify Store Developer');
    await _pumpBoard(tester);

    _board.setTab(1);
    await tester.pump();

    expect(_ids, contains('t1'));
    expect(_ids.first, 't1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a profile with no title says so instead of showing a fake rank',
    (tester) async {
      await _pumpBoard(tester);

      _board.setTab(1);
      await tester.pump();

      expect(_ids, isEmpty);
      expect(
        find.text('Add your job title in your profile to rank matches.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('an empty board and an empty search each say what happened', (
    tester,
  ) async {
    _backend.tasks.clear();
    await _pumpBoard(tester);

    expect(_board.status, FindWorkStatus.empty);
    expect(find.text('No open projects right now.'), findsOneWidget);

    await _search(tester, 'anything');
    expect(_board.status, FindWorkStatus.empty);
    expect(find.text('No open project matches this search.'), findsOneWidget);
  });

  testWidgets('a failed board offers a retry that then loads', (tester) async {
    _backend.tasksBroken = true;
    await _pumpBoard(tester);

    expect(_board.status, FindWorkStatus.error);
    expect(_board.errorMessage, 'The server had a problem. Please try again.');
    expect(find.text('Retry'), findsOneWidget);

    _backend.tasksBroken = false;
    await tester.tap(find.text('Retry'));
    await _settle(tester);

    expect(_board.status, FindWorkStatus.ready);
    expect(find.textContaining('Shopify Store Redesign'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed refresh keeps the projects already on screen', (
    tester,
  ) async {
    await _pumpBoard(tester);
    expect(_board.results, hasLength(4));

    _backend.tasksBroken = true;
    await _board.refresh();
    await _settle(tester);

    expect(_board.status, FindWorkStatus.ready);
    expect(_board.results, hasLength(4));
    expect(_board.errorMessage, isNotEmpty);
  });

  testWidgets('bookmarks are device state and outlive a reload', (
    tester,
  ) async {
    await _pumpBoard(tester);

    _board.toggleSave('t3');
    await tester.pump();
    expect(_board.byId('t3').saved, isTrue);

    _board.setTab(2);
    await tester.pump();
    expect(_ids, ['t3']);
    expect(find.text('Save Jobs (1)'), findsOneWidget);

    await _board.refresh();
    await _settle(tester);
    expect(_board.byId('t3').saved, isTrue);

    _board.toggleSave('t3');
    expect(_board.byId('t3').saved, isFalse);
  });

  testWidgets('a signed-out device is not even asked to bid', (tester) async {
    await _backend.install();
    _board.clear();
    await _pumpBoard(tester);

    final outcome = await _board.apply(
      _board.byId('t1'),
      proposal: 'I have rebuilt three Shopify stores this year.',
    );

    expect(outcome.sent, isFalse);
    expect(outcome.message, 'Sign in to send a proposal.');
    expect(_backend.paths.where((path) => path.endsWith('/bid')), isEmpty);
    // The Bids figure belongs to the wallet route, and a device with no session
    // never asks it — so it shows no number rather than one it invented.
    expect(
      _backend.paths.where((path) => path.contains('/api/wallet')),
      isEmpty,
    );
    expect(WalletController.instance.value.connects, isNull);
  });

  testWidgets('a proposal is only counted when the route answers 201', (
    tester,
  ) async {
    await _pumpBoard(tester);

    final outcome = await _board.apply(
      _board.byId('t1'),
      proposal: 'I have rebuilt three Shopify stores this year.',
      bidAmount: 40,
      portfolioItemIds: const ['r7'],
    );
    await _settle(tester);

    expect(outcome.sent, isTrue);
    expect(outcome.spent, 40);
    expect(_backend.bids, hasLength(1));
    expect(_backend.bodyFor('/api/tasks/t1/bid')['bidAmount'], 40);
    expect(_backend.bodyFor('/api/tasks/t1/bid')['portfolioItemIds'], ['r7']);
    expect(WalletController.instance.value.connects, 94);
    // The board was read again, so the proposal count is the server's.
    expect(_board.byId('t1').proposals, 13);
    expect(_board.byId('t1').applied, isTrue);
  });

  testWidgets('image and document attachments upload before the bid', (
    tester,
  ) async {
    await _pumpBoard(tester);

    final outcome = await _board.apply(
      _board.byId('t1'),
      proposal: 'I have rebuilt three Shopify stores this year.',
      attachments: [
        ProposalAttachment(
          name: 'audit.png',
          bytes: Uint8List.fromList(List<int>.filled(64, 7)),
          mimeType: 'image/png',
        ),
      ],
    );

    expect(outcome.sent, isTrue);
    expect(_backend.paths, contains('/api/upload'));
    expect(
      _backend.paths.indexOf('/api/upload'),
      lessThan(_backend.paths.indexOf('/api/tasks/t1/bid')),
    );
    expect(_backend.bodyFor('/api/tasks/t1/bid')['attachmentUrls'], [
      'https://cdn.example/audit.png',
    ]);
  });

  testWidgets('PDF proposal attachments use the document MIME type', (
    tester,
  ) async {
    await _pumpBoard(tester);

    final outcome = await _board.apply(
      _board.byId('t1'),
      proposal: 'I have rebuilt three Shopify stores this year.',
      attachments: [
        ProposalAttachment(
          name: 'portfolio.pdf',
          bytes: Uint8List.fromList(List<int>.filled(64, 7)),
          mimeType: 'application/pdf',
        ),
      ],
    );

    expect(outcome.sent, isTrue);
    final upload = _backend.requests.firstWhere(
      (request) => request.url.path == '/api/upload',
    );
    expect(upload.body, contains('Content-Type: application/pdf'));
    expect(_backend.bodyFor('/api/tasks/t1/bid')['attachmentUrls'], [
      'https://cdn.example/portfolio.pdf',
    ]);
  });

  testWidgets('every refusal the backend gives is shown in its own words', (
    tester,
  ) async {
    await _pumpBoard(tester);
    const pitch = 'I have rebuilt three Shopify stores this year.';

    _backend.storedConnects = 5;
    var outcome = await _board.apply(_board.byId('t1'), proposal: pitch);
    expect(outcome.message, 'Not enough connects. Buy a package first.');

    _backend.storedConnects = 134;
    await _board.apply(_board.byId('t2'), proposal: pitch);
    outcome = await _board.apply(_board.byId('t2'), proposal: pitch);
    expect(outcome.message, 'You already applied on this project.');

    outcome = await _board.apply(
      ProjectModel.fromJson({'id': 'gone', 'title': 'Closed'}),
      proposal: pitch,
    );
    expect(outcome.message, 'This project is not open for applications.');

    _backend.accountSuspended = true;
    outcome = await _board.apply(_board.byId('t3'), proposal: pitch);
    expect(outcome.message, 'Account suspended.');

    _backend.accountSuspended = false;
    _backend.sessionRevoked = true;
    outcome = await _board.apply(_board.byId('t4'), proposal: pitch);
    expect(outcome.message, 'Your session has expired. Please log in again.');
    expect(outcome.sent, isFalse);
  });

  testWidgets('a proposal the schema would reject never leaves the device', (
    tester,
  ) async {
    await _pumpBoard(tester);

    final short = await _board.apply(_board.byId('t1'), proposal: 'too short');
    expect(short.message, 'Write a clear proposal (min 20 characters).');

    final rate = await _board.apply(
      _board.byId('t1'),
      proposal: 'I have rebuilt three Shopify stores this year.',
      bidAmount: 2,
    );
    expect(rate.message, 'The bid rate must be between \$5 and \$10000.');

    expect(_backend.paths.where((path) => path.endsWith('/bid')), isEmpty);
  });

  testWidgets('signing out forgets the board and its device-only flags', (
    tester,
  ) async {
    await _pumpBoard(tester);
    _board.toggleSave('t1');
    await tester.pump();

    _board.clear();
    expect(_board.results, isEmpty);
    expect(_board.status, FindWorkStatus.idle);
    expect(_board.savedCount, 0);
    expect(_board.categories, isEmpty);
  });

  testWidgets('a long board builds only the rows it shows', (tester) async {
    // The route sends the whole open set at once, so the screen must not turn
    // that response into one frame of cards.
    for (int i = 0; i < 60; i++) {
      _backend.seedTask(
        'bulk$i',
        title: 'Open project number $i',
        ago: Duration(minutes: 60 - i),
      );
    }
    await _pumpBoard(tester);

    final built = find.byType(ProjectCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));

    // Scrolling asks for the rest, so nothing on the server is unreachable.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectCard).evaluate().length, greaterThan(built));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board keeps its shape at phone, tablet and desktop widths', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      _board.clear();
      await _pumpBoard(tester, width: width);
      // A resize reuses the same widget, so the board is asked for directly.
      await _board.refresh();
      await _settle(tester);

      expect(find.text('Open Projects'), findsOneWidget);
      expect(
        find.widgetWithText(AppTextField, 'Search Projects here...'),
        findsOneWidget,
      );
      expect(find.byType(ProjectCard), findsWidgets, reason: '${width}dp');
      expect(tester.takeException(), isNull, reason: 'board at ${width}dp');
    }
  });
}
