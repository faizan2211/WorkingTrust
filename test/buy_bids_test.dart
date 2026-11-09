import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/billing/controller/billing_controller.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/packages/controller/package_controller.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';

import 'fake_backend.dart';

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

Future<void> _openRoute(
  WidgetTester tester,
  String route, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(routes: routeTable(), initialRoute: route),
  );
  await _settle(tester);
  expect(tester.takeException(), isNull, reason: route);
}

/// Opens the shell on Find Work (tab 2), where the bid balance is offered.
Future<void> _openShell(
  WidgetTester tester, {
  double width = 400,
  int tab = 2,
}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
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

void main() {
  late FakeBackend backend;

  setUp(() async {
    backend = FakeBackend();
    await backend.install();
    backend.issueSessionCookie();
    backend.storedConnects = 134;
    WalletController.instance.clear();
    ProfileController.instance.setAvatar(null);
    PackageController.instance.clear();
    BillingController.instance.reset();
    // The sheet lists whatever the server's Package table holds, so a test that
    // wants these packs files them there.
    backend.seedPackage(
      'p_bids20',
      name: 'Bids 20',
      priceUsd: 15,
      connects: 20,
      validityDays: 730,
      sortOrder: 1,
    );
    backend.seedPackage(
      'p_bids50',
      name: 'Bids 50',
      priceUsd: 30,
      connects: 50,
      validityDays: 730,
      sortOrder: 2,
    );
    backend.seedPackage(
      'p_bids100',
      name: 'Bids 100',
      priceUsd: 50,
      connects: 100,
      validityDays: 730,
      sortOrder: 3,
    );
  });

  testWidgets('Buy Bids on Find Work opens the purchase sheet', (tester) async {
    await _openShell(tester);

    await _tap(tester, find.text('Buy Bids'));

    for (final label in [
      'Your available Bids',
      'Select the amount to buy',
      'Your account will be charged',
      'Your new Bids balance will be',
      'These Bids will expire on',
      'Promo code',
      'Apply',
      'Cancel',
      'Continue',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // The packs the catalog lists, each with its own price and validity.
    for (final name in ['Bids 20', 'Bids 50', 'Bids 100']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('\$15.00'), findsOneWidget);
    expect(find.text('\$50.00'), findsOneWidget);
    expect(find.text('20 Bids · valid for 730 days'), findsOneWidget);
    // 134 available.
    expect(find.text('134'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet lists the packs the server sent, in its order', (
    tester,
  ) async {
    await _openShell(tester);
    expect(find.text('Bids: 134'), findsOneWidget);

    await _tap(tester, find.text('Buy Bids'));

    expect(backend.countOf('/api/packages'), 1);
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .where((data) => data.startsWith('Bids '))
          .toList(),
      ['Bids 20', 'Bids 50', 'Bids 100'],
    );
    expect(
      find.text('This package is not listed for purchase yet.'),
      findsNothing,
    );
    expect(WalletController.instance.value.connects, 134);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Bids figure is the server\'s connects, not a device copy', (
    tester,
  ) async {
    // An account that has never bought a pack holds none, and every screen says
    // so because it reads the wallet route rather than a number on the device.
    backend.storedConnects = 0;
    await _openShell(tester);
    expect(find.text('Bids: 0'), findsOneWidget);

    await _tap(tester, find.text('Buy Bids'));

    expect(find.text('Your available Bids'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(backend.countOf('/api/wallet'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening the sheet shows what the Admin Panel changed', (
    tester,
  ) async {
    await _openShell(tester);
    await _tap(tester, find.text('Buy Bids'));

    expect(find.text('\$15.00 + Tax'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));

    // A repriced pack, a renamed one and one taken off sale: the next open of
    // the sheet has to show all three.
    backend.packages.clear();
    backend.seedPackage(
      'p_bids20',
      name: 'Bids 20',
      priceUsd: 18,
      connects: 25,
      validityDays: 730,
      sortOrder: 1,
    );
    backend.seedPackage(
      'p_bids50',
      name: 'Bids 50 Plus',
      priceUsd: 30,
      connects: 50,
      validityDays: 730,
      sortOrder: 2,
    );
    backend.seedPackage(
      'p_bids100',
      name: 'Bids 100',
      priceUsd: 50,
      connects: 100,
      validityDays: 730,
      active: false,
      sortOrder: 3,
    );

    await _tap(tester, find.text('Buy Bids'));

    expect(backend.countOf('/api/packages'), 2);
    expect(find.text('\$18.00 + Tax'), findsOneWidget);
    expect(find.text('25 Bids · valid for 730 days'), findsOneWidget);
    expect(find.text('Bids 50 Plus'), findsOneWidget);
    expect(find.text('Bids 100'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the sheet down re-reads the packs', (tester) async {
    await _openShell(tester);
    await _tap(tester, find.text('Buy Bids'));
    expect(backend.countOf('/api/packages'), 1);

    // The list is dragged down and released, so the packs are read again
    // without leaving the sheet.
    await tester.fling(find.text('Bids 50'), const Offset(0, 260), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(backend.countOf('/api/packages'), 2);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a pack re-prices the order', (tester) async {
    await _openShell(tester);
    await _tap(tester, find.text('Buy Bids'));

    expect(find.text('\$15.00 + Tax'), findsOneWidget);
    expect(find.text('154'), findsOneWidget);

    await _tap(tester, find.text('Bids 100'));

    expect(find.text('\$50.00 + Tax'), findsOneWidget);
    expect(find.text('234'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promo code takes whatever is typed', (tester) async {
    await _openShell(tester);
    await _tap(tester, find.text('Buy Bids'));

    await _tap(tester, find.text('Apply'));
    expect(find.text('Enter a promo code first.'), findsOneWidget);
    // Snacks queue, so let this one expire before the next is shown.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter Code'),
      'ARSLAN',
    );
    await _tap(tester, find.text('Apply'));
    expect(find.text('Promo code ARSLAN applied.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stats card opens the same sheet', (tester) async {
    await _openRoute(tester, RouteNames.stats);

    await _tap(tester, find.text('Buy Bids'));
    expect(find.text('Your available Bids'), findsOneWidget);
    expect(find.text('Select the amount to buy'), findsOneWidget);
    expect(find.text('Bids 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bids card on View Profile opens the sheet', (tester) async {
    await _openRoute(tester, RouteNames.profile);

    await _tap(tester, find.text('Bids'));
    expect(find.text('Select the amount to buy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet stays usable on a narrow screen', (tester) async {
    for (final width in [320.0, 700.0]) {
      await _openShell(tester, width: width);
      await _tap(tester, find.text('Buy Bids'));
      expect(find.text('Continue'), findsOneWidget, reason: '${width}dp');
      expect(tester.takeException(), isNull, reason: 'sheet at ${width}dp');
      await _tap(tester, find.text('Cancel'));
    }
  });

  testWidgets('profile photo upload offers gallery and camera', (tester) async {
    await _openShell(tester, tab: 3);

    await _tap(tester, find.byIcon(Icons.photo_camera_outlined));

    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backing out of the picker leaves the profile untouched', (
    tester,
  ) async {
    await _openShell(tester, tab: 3);

    await _tap(tester, find.byIcon(Icons.photo_camera_outlined));
    await _tap(tester, find.text('Choose from gallery'));

    expect(find.text('Choose from gallery'), findsNothing);
    expect(ProfileController.instance.avatarBytes, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an uploaded photo replaces the seeded one', (tester) async {
    // A session the profile can read, so the photo the device picked is not
    // dropped as an expired account's leftover.
    final backend = FakeBackend();
    await backend.install();
    backend.issueSessionCookie();
    ProfileController.instance.setAvatar(Uint8List.fromList([0]));
    await _openShell(tester, tab: 3);

    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<MemoryImage>();
    expect(images, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
