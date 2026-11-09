import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/core/network/api_client.dart';
import 'package:working_trust/core/network/api_endpoints.dart';
import 'package:working_trust/core/network/network_exceptions.dart';
import 'package:working_trust/core/utils/link_opener.dart';
import 'package:working_trust/features/billing/controller/billing_controller.dart';
import 'package:working_trust/features/billing/services/billing_service.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/membership/widgets/plan_card.dart';
import 'package:working_trust/features/packages/controller/package_controller.dart';
import 'package:working_trust/features/packages/models/package_entry.dart';
import 'package:working_trust/features/packages/services/package_service.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';

import 'fake_backend.dart';

const String checkoutPath = '/api/deposits/stripe/checkout';
const String confirmPath = '/api/deposits/stripe/confirm';
const String catalogPath = '/api/packages';

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// The date the sheet promises for a pack of [days], from the same column the
/// sheet reads.
String _expiry(int days) {
  final day = DateTime.now().add(Duration(days: days));
  return '${_months[day.month - 1]} ${day.day}, ${day.year}';
}

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

/// Opens the shell on [tab]; tab 2 offers Buy Bids, tab 3 offers Membership.
Future<void> _openShell(
  WidgetTester tester, {
  double width = 400,
  int tab = 2,
}) async {
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      routes: routeTable(),
      home: HomeScreen(initialTab: tab),
    ),
  );
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _openBidsSheet(WidgetTester tester, {double width = 400}) async {
  await _openShell(tester, width: width);
  await _tap(tester, find.text('Buy Bids'));
}

Future<void> _openMembership(WidgetTester tester, {double width = 1200}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(routes: routeTable(), initialRoute: RouteNames.membershipPlan),
  );
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

/// Two bid packs plus one that was switched off. Nothing about them matches the
/// list the app used to carry, so a test that finds them read the rows.
void _seedBids(FakeBackend backend) {
  backend.seedPackage(
    'p_speedy',
    name: 'Speedy Pack',
    priceUsd: 22.5,
    connects: 40,
    description: 'A pack for a busy month.',
    validityDays: 90,
    features: ['Opens every category', 'Refills automatically'],
    audience: 'FREELANCER',
    serviceFeePct: 3,
    sortOrder: 2,
  );
  backend.seedPackage(
    'p_steady',
    name: 'Steady Pack',
    priceUsd: 15,
    connects: 20,
    validityDays: 730,
    featured: true,
    sortOrder: 1,
  );
  backend.seedPackage(
    'p_retired',
    name: 'Old Pack',
    priceUsd: 8,
    connects: 10,
    active: false,
    sortOrder: 3,
  );
}

void _seedMembership(FakeBackend backend) {
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
    serviceFeePct: 5,
    sortOrder: 2,
  );
}

/// The row [backend] filed under [id], as the app would read it off a catalog
/// response.
PackageEntry _pack(FakeBackend backend, String id) =>
    packageFromJson(backend.packages.firstWhere((row) => row['id'] == id));

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
    backend.storedConnects = 134;
    WalletController.instance.clear();
    ProfileController.instance.setAvatar(null);
    _seedBids(backend);
  });

  tearDown(() {
    PackageController.instance.clear();
    BillingController.instance.reset();
    LinkOpener.launch = originalLaunch;
  });

  test('a row is read in the backend\'s own column names', () {
    final package = packageFromJson({
      'id': 'p1',
      'name': 'Launch Pack',
      'kind': 'BIDS',
      'priceUsd': 7.5,
      'connects': 20,
      'description': null,
      'validityDays': 30,
      // Prisma keeps `features` as a text column, so a read carries a string.
      'features': '["Two per day", "", 5]',
      'audience': 'client',
      'featured': true,
      'active': true,
      'sortOrder': 4,
      'serviceFeePct': 2.5,
    });

    expect(package.id, 'p1');
    expect(package.kind, PackageKind.bids);
    expect(package.priceLabel, '\$7.50');
    expect(package.connectsLabel, '20 Bids');
    expect(package.periodLabel, '/ month');
    expect(package.features, ['Two per day']);
    expect(package.audienceLabel, 'For clients');
    expect(package.serviceFeeLabel, '2.5% service fee');
    expect(package.actionLabel, 'Continue With Launch Pack');

    // A row that never says it is off is on, and every optional column may be
    // missing.
    final spare = packageFromJson({'name': 'Bare'});
    expect(spare.active, isTrue);
    expect(spare.kind, PackageKind.bids);
    expect(spare.priceUsd, 0);
    expect(spare.features, isEmpty);
    expect(spare.audienceLabel, isNull);
    expect(spare.serviceFeeLabel, isNull);
    expect(spare.expiresOn, isNull);
  });

  test(
    'the server keeps the two kinds apart and drops inactive rows',
    () async {
      final bids = await PackageService.instance.fetch(PackageKind.bids);
      expect(bids.map((p) => p.name), ['Steady Pack', 'Speedy Pack']);
      expect(bids.map((p) => p.id), ['p_steady', 'p_speedy']);
      expect(
        await PackageService.instance.fetch(PackageKind.membership),
        isEmpty,
      );

      _seedMembership(backend);
      expect(
        (await PackageService.instance.fetch(PackageKind.membership))
            .map((p) => p.name),
        ['Starter', 'Growth'],
      );
    },
  );

  test(
    'a kind the table does not use is refused, not quietly ignored',
    () async {
      await expectLater(
        ApiClient().get(
          ApiEndpoints.packages,
          queryParameters: {'kind': 'CONNECTS'},
        ),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'message',
            'Invalid kind. Use BIDS or MEMBERSHIP.',
          ),
        ),
      );
    },
  );

  testWidgets('the sheet lists the packs the rows carry', (tester) async {
    await _openBidsSheet(tester);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where((data) => data.endsWith('Pack'))
        .toList();
    expect(names, ['Steady Pack', 'Speedy Pack']);
    expect(find.text('Old Pack'), findsNothing);
    expect(find.text('\$15.00'), findsOneWidget);
    expect(find.text('\$22.50'), findsOneWidget);
    expect(find.text('20 Bids · valid for 730 days'), findsOneWidget);
    expect(
      find.text(
        '40 Bids · valid for 90 days · For freelancers · 3% service fee',
      ),
      findsOneWidget,
    );
    expect(find.text('Opens every category'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a pack re-prices the order from that pack', (
    tester,
  ) async {
    await _openBidsSheet(tester);

    // The first row is selected by default, so this is the row's own price.
    expect(find.text('\$15.00 + Tax'), findsOneWidget);
    expect(find.text('154'), findsOneWidget);
    expect(find.text(_expiry(730)), findsOneWidget);

    await _tap(tester, find.text('Speedy Pack'));

    expect(find.text('\$22.50 + Tax'), findsOneWidget);
    expect(find.text('174'), findsOneWidget);
    expect(find.text(_expiry(90)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue sends the id alone and opens the hosted page', (
    tester,
  ) async {
    await _openBidsSheet(tester);
    await _tap(tester, find.text('Continue'));

    expect(
      find.text('Finish the payment in your browser, then come back here.'),
      findsOneWidget,
    );
    expect(launched, hasLength(1));
    expect(
      launched.single.toString(),
      startsWith('https://checkout.stripe.com/'),
    );
    final body = backend.bodyFor(checkoutPath);
    expect(body['packageId'], 'p_steady');
    expect(body['purpose'], 'bids');
    expect(body['returnTo'], '/buy-bids');
    expect(body.containsKey('priceUsd'), isFalse);
    expect(body.containsKey('connects'), isFalse);
    // Nothing is credited, and nothing is asked, until the user says so.
    expect(backend.countOf(confirmPath), 0);
    expect(WalletController.instance.value.connects, 134);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the connects land only once the server confirms them', (
    tester,
  ) async {
    await _openBidsSheet(tester);
    await _tap(tester, find.text('Continue'));
    await _tap(tester, find.text('Check payment'));

    expect(find.text('Your available Bids'), findsNothing);
    expect(find.text('20 Bids added to your account.'), findsOneWidget);
    expect(find.text('Bids: 154'), findsOneWidget);
    expect(WalletController.instance.value.connects, 154);
    expect(backend.storedConnects, 154);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a payment that has not landed is reported, not assumed', (
    tester,
  ) async {
    backend.paymentUnpaid = true;
    await _openBidsSheet(tester);
    await _tap(tester, find.text('Continue'));
    await _tap(tester, find.text('Check payment'));

    expect(find.text('Payment is not completed yet.'), findsOneWidget);
    expect(find.text('Your available Bids'), findsOneWidget);
    expect(backend.countOf(confirmPath), 1);
    expect(WalletController.instance.value.connects, 134);
    expect(backend.storedConnects, 134);

    // The same session can be asked again; nothing is added in between.
    await _tap(tester, find.text('Check payment'));
    expect(backend.countOf(confirmPath), 2);
    expect(WalletController.instance.value.connects, 134);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the browser credits nothing', (tester) async {
    await _openBidsSheet(tester);
    await _tap(tester, find.text('Continue'));
    await _tap(tester, find.text('Cancel'));

    expect(find.text('Your available Bids'), findsNothing);
    expect(backend.countOf(confirmPath), 0);
    expect(WalletController.instance.value.connects, 134);
    expect(backend.storedConnects, 134);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refusal is shown and the pack can be tried again', (
    tester,
  ) async {
    // 13 Bids has no Stripe Price on the server, which is a 500 with its own
    // sentence.
    backend.seedPackage(
      'p_odd',
      name: 'Odd Pack',
      priceUsd: 4,
      connects: 13,
      sortOrder: 0,
    );
    await _openBidsSheet(tester);
    await _tap(tester, find.text('Odd Pack'));
    await _tap(tester, find.text('Continue'));

    expect(
      find.text('No Stripe Price ID configured for 13 Bids.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(WalletController.instance.value.connects, 134);

    await _tap(tester, find.text('Steady Pack'));
    await _tap(tester, find.text('Continue'));
    expect(
      find.text('Finish the payment in your browser, then come back here.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the packs are read from the server as the sheet opens', (
    tester,
  ) async {
    backend.slowPackages = true;
    await _openShell(tester);
    await tester.ensureVisible(find.text('Buy Bids'));
    await tester.tap(find.text('Buy Bids'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Steady Pack'), findsNothing);

    await _settle(tester);

    expect(find.text('Steady Pack'), findsOneWidget);
    expect(
      backend.requests
          .where((request) => request.url.path == catalogPath)
          .map((request) => request.url.query)
          .toList(),
      ['kind=BIDS'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a list that will not load is reported, then retried', (
    tester,
  ) async {
    backend.packagesBroken = true;
    await _openBidsSheet(tester);

    expect(find.text('Unable to load packages.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    backend.packagesBroken = false;
    await _tap(tester, find.text('Retry'));

    expect(find.text('Steady Pack'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row with no server id is never sent to checkout', (
    tester,
  ) async {
    backend.seedPackage('', name: 'Guess Pack', priceUsd: 9, connects: 20);
    await _openBidsSheet(tester);
    await _tap(tester, find.text('Guess Pack'));
    await _tap(tester, find.text('Continue'));

    expect(
      find.text('This package is not listed for purchase yet.'),
      findsOneWidget,
    );
    expect(backend.countOf(checkoutPath), 0);
    expect(launched, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no packs means an honest empty sheet', (tester) async {
    backend.packages.clear();
    await _openBidsSheet(tester);

    expect(find.text('No bid packs are available right now.'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tiers come from rows and buy through the same checkout', (
    tester,
  ) async {
    _seedMembership(backend);
    await _openMembership(tester);

    expect(find.byType(PlanCard), findsNWidgets(2));
    expect(find.text('Simple, Honest Pricing'), findsOneWidget);
    expect(find.text('\$50.00'), findsOneWidget);
    expect(find.text('/ month'), findsNWidgets(2));
    expect(find.text('90 connects'), findsOneWidget);
    expect(find.text('Most Popular'), findsOneWidget);
    expect(find.text('5% service fee'), findsOneWidget);
    expect(find.text('Speedy Pack'), findsNothing);

    await _tap(tester, find.text('Continue With Starter'));

    final body = backend.bodyFor(checkoutPath);
    expect(body['packageId'], 'm_starter');
    expect(body['purpose'], 'membership');
    expect(body['returnTo'], '/deposit');
    expect(
      find.text('Finish the payment in your browser, then come back here.'),
      findsOneWidget,
    );

    await _tap(tester, find.text('Check payment'));

    expect(find.text('Starter is active.'), findsWidgets);
    // A plan buys no Bids, so the balance never moves.
    expect(WalletController.instance.value.connects, 134);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the membership screen says so when there are no tiers', (
    tester,
  ) async {
    await _openMembership(tester);

    expect(
      find.text('Membership plans are not available right now.'),
      findsOneWidget,
    );
    expect(find.byType(PlanCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the membership screen asks for its own kind and retries', (
    tester,
  ) async {
    backend.packagesBroken = true;
    _seedMembership(backend);
    await _openMembership(tester);

    expect(find.text('Unable to load packages.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      backend.requests
          .where((request) => request.url.path == catalogPath)
          .map((request) => request.url.query)
          .toList(),
      ['kind=MEMBERSHIP'],
    );

    backend.packagesBroken = false;
    await _tap(tester, find.text('Retry'));

    expect(find.byType(PlanCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet stays usable from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _openBidsSheet(tester, width: width);
      expect(find.text('Continue'), findsOneWidget, reason: '${width}dp');
      expect(tester.takeException(), isNull, reason: 'sheet at ${width}dp');
      await _tap(tester, find.text('Cancel'));
    }
  });

  group('the checkout contract', () {
    test(
      'a session that has not been paid answers 409, not a receipt',
      () async {
        backend.paymentUnpaid = true;
        final service = BillingService();
        final session = await service.startCheckout(_pack(backend, 'p_steady'));

        final answer = await service.confirmCheckout(session.sessionId);

        expect(answer.fulfilled, isFalse);
        expect(answer.message, 'Payment is not completed yet.');
        expect(answer.paymentStatus, 'open');
      },
    );

    test('confirming twice does not pay for the same pack twice', () async {
      final service = BillingService();
      final session = await service.startCheckout(_pack(backend, 'p_steady'));

      final first = await service.confirmCheckout(session.sessionId);
      final again = await service.confirmCheckout(session.sessionId);

      expect(first.fulfilled, isTrue);
      expect(first.alreadyFulfilled, isFalse);
      expect(first.connects, 20);
      expect(again.fulfilled, isTrue);
      expect(again.alreadyFulfilled, isTrue);
      expect(backend.storedConnects, 154);
    });

    test('a pack outside the configured Stripe Prices is refused', () async {
      backend.seedPackage('p_odd', name: 'Odd Pack', priceUsd: 4, connects: 13);

      await expectLater(
        BillingService().startCheckout(packageFromJson(backend.packages.last)),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'message',
            'No Stripe Price ID configured for 13 Bids.',
          ),
        ),
      );
    });

    test('an unknown id is refused before any page opens', () async {
      final ghost = packageFromJson({
        'id': 'p_missing',
        'name': 'Bids 20',
        'kind': 'BIDS',
        'priceUsd': 15,
        'connects': 20,
      });

      await expectLater(
        BillingService().startCheckout(ghost),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'message',
            'Invalid package.',
          ),
        ),
      );
    });

    test(
      'a signed-out device is refused the way the route refuses it',
      () async {
        final package = packageFromJson(backend.packages.first);
        // A fresh install holds no session, which is what signing out leaves.
        await backend.install();

        await expectLater(
          BillingService().startCheckout(package),
          throwsA(
            isA<NetworkException>().having(
              (error) => error.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      },
    );
  });
}
