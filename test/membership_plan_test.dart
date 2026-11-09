import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/core/utils/link_opener.dart';
import 'package:working_trust/features/billing/controller/billing_controller.dart';
import 'package:working_trust/features/membership/screens/membership_plan_screen.dart';
import 'package:working_trust/features/membership/widgets/plan_card.dart';
import 'package:working_trust/features/packages/controller/package_controller.dart';

import 'fake_backend.dart';

const String checkoutPath = '/api/deposits/stripe/checkout';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: MembershipPlanScreen())),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The three tiers as the backend's `Package` table holds them. The screen is
/// given no list of its own.
void _seedTiers(FakeBackend backend) {
  backend.seedPackage(
    'm_starter',
    name: 'Starter',
    kind: 'MEMBERSHIP',
    priceUsd: 35,
    connects: 50,
    description: 'Everything you need to win your first projects.',
    validityDays: 30,
    features: ['Everything in Free', 'Priority placement in search'],
    sortOrder: 1,
  );
  backend.seedPackage(
    'm_growth',
    name: 'Growth',
    kind: 'MEMBERSHIP',
    priceUsd: 50,
    connects: 90,
    description: 'For freelancers running this full time.',
    validityDays: 30,
    features: ['Everything in Free', '48-hour support response'],
    featured: true,
    sortOrder: 2,
  );
  backend.seedPackage(
    'm_pro',
    name: 'Pro',
    kind: 'MEMBERSHIP',
    priceUsd: 99,
    connects: 160,
    description: 'For studios and small teams hiring together.',
    validityDays: 30,
    features: ['Everything in Growth', 'Highest connects allowance'],
    audience: 'CLIENT',
    serviceFeePct: 3,
    sortOrder: 3,
  );
}

void main() {
  late FakeBackend backend;
  late List<Uri> launched;
  late Future<bool> Function(Uri) originalLaunch;

  setUp(() async {
    originalLaunch = LinkOpener.launch;
    launched = [];
    LinkOpener.launch = (uri) async {
      launched.add(uri);
      return true;
    };
    backend = FakeBackend();
    await backend.install();
    backend.issueSessionCookie();
    PackageController.instance.clear();
    BillingController.instance.reset();
    _seedTiers(backend);
  });

  tearDown(() {
    PackageController.instance.clear();
    BillingController.instance.reset();
    LinkOpener.launch = originalLaunch;
  });

  testWidgets('pricing screen matches the supplied reference', (tester) async {
    await _pump(tester, 1200);

    expect(find.text('Simple, Honest Pricing'), findsOneWidget);
    expect(find.textContaining('Applying is always free'), findsOneWidget);
    expect(find.byType(PlanCard), findsNWidgets(3));
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('\$35.00'), findsOneWidget);
    expect(find.text('\$50.00'), findsOneWidget);
    expect(find.text('\$99.00'), findsOneWidget);
    expect(find.text('Most Popular'), findsOneWidget);
    expect(find.text('50 connects'), findsOneWidget);
    expect(find.text('90 connects'), findsOneWidget);
    expect(find.text('160 connects'), findsOneWidget);
    expect(find.text('Continue With Growth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tiers on screen are the rows the server sent', (
    tester,
  ) async {
    await _pump(tester, 1200);

    expect(backend.countOf('/api/packages'), 1);
    // The panel's own columns, drawn as it filed them: this tier's audience and
    // fee on one line, and a bullet only its row carries.
    expect(find.text('For clients · 3% service fee'), findsOneWidget);
    expect(find.text('Everything in Growth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the list down re-reads the tiers', (tester) async {
    await _pump(tester, 1200);
    expect(backend.countOf('/api/packages'), 1);

    // Dragged down and released: the same read the screen asks for on entry,
    // so an Admin Panel change lands without leaving the screen.
    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 260),
      1200,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(backend.countOf('/api/packages'), 2);
    expect(find.byType(PlanCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('revisiting the screen shows what the Admin Panel changed', (
    tester,
  ) async {
    await _pump(tester, 1200);
    expect(find.text('\$99.00'), findsOneWidget);

    // A repriced tier and one taken off sale, filed in the same table the
    // screen reads: the next visit shows both.
    backend.packages.removeWhere((row) => row['id'] == 'm_starter');
    backend.packages.firstWhere((row) => row['id'] == 'm_pro')['priceUsd'] = 80;

    // Leaving the screen and coming back is a new visit, so the tiers are read
    // again.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();
    await _pump(tester, 1200);

    expect(backend.countOf('/api/packages'), 2);
    expect(find.byType(PlanCard), findsNWidgets(2));
    expect(find.text('\$80.00'), findsOneWidget);
    expect(find.text('Starter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a tier asks the server for its page', (tester) async {
    await _pump(tester, 1200);

    await tester.tap(find.text('Continue With Starter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Finish the payment in your browser, then come back here.'),
      findsOneWidget,
    );
    expect(backend.bodyFor(checkoutPath)['packageId'], 'm_starter');
    expect(launched, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards stay usable from phone to desktop width', (tester) async {
    for (final width in [320.0, 480.0, 700.0, 980.0, 1400.0]) {
      await _pump(tester, width);
      expect(find.byType(PlanCard), findsNWidgets(3), reason: '${width}dp');
      expect(tester.takeException(), isNull, reason: 'layout at ${width}dp');
    }
  });
}
