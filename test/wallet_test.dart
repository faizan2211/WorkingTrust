import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/membership/screens/membership_plan_screen.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/screens/transactions_screen.dart';
import 'package:working_trust/features/profile/screens/wallet_screen.dart';
import 'package:working_trust/features/settings/screens/settings_screen.dart';

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

/// Opens the wallet the only way a session can: from the Profile modules.
Future<void> _openWallet(WidgetTester tester, {double width = 400}) async {
  await _backend.install();
  _backend.issueSessionCookie();
  ProfileController.instance.clear();
  WalletController.instance.clear();
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(routes: routeTable(), home: const HomeScreen(initialTab: 3)),
  );
  await _settle(tester);
  await _tap(tester, find.text('Wallet'));
}

void main() {
  setUp(() {
    ProfileController.instance.clear();
    WalletController.instance.clear();
  });

  testWidgets(
    'the wallet lists its balance, connects and both activity cards',
    (tester) async {
      await _openWallet(tester);

      expect(find.byType(WalletScreen), findsOneWidget);
      expect(find.text('Available balance'), findsOneWidget);
      expect(find.text(r'$1240.50'), findsOneWidget);
      expect(find.text('Connects on account'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Money activity'), findsOneWidget);
      expect(find.text('Connects activity'), findsOneWidget);
      // The route answered with rows, so the cards list them instead of
      // claiming there is no history.
      expect(find.text('No money activity yet.'), findsNothing);
      expect(find.text('No connects activity yet.'), findsNothing);
      // Each control is named once, so a row can be reached by its label.
      expect(find.text('Buy bids'), findsOneWidget);
      expect(find.text('Buy connects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('connects follow the server count, not a written number', (
    tester,
  ) async {
    await _openWallet(tester);
    expect(find.text('134'), findsOneWidget);

    // A local spend does not move the visible figure; only the route's answer
    // does, which is what the next read reflects.
    _backend.storedConnects = 94;
    await WalletController.instance.refresh();
    await _settle(tester);
    expect(find.text('94'), findsOneWidget);
    expect(find.text('134'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a balance the server has not reported shows as such', (
    tester,
  ) async {
    await _openWallet(tester);
    _backend.storedBalance = null;
    await WalletController.instance.refresh();
    await _settle(tester);

    // The figure is not guessed at: the card says the route gave nothing.
    expect(find.text('—'), findsWidgets);
    expect(find.text('The server has not reported a balance.'), findsOneWidget);
    expect(
      find.textContaining('Payouts are requested from Settings'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('go to withdrawals opens settings on that tab', (tester) async {
    await _openWallet(tester);

    await _tap(tester, find.text('Go to Withdrawals'));
    expect(find.byType(SettingsScreen), findsOneWidget);
    // The tab the account was sent to, not the first section.
    expect(find.text('Withdrawal schedule'), findsOneWidget);
    expect(find.text('Withdrawal now'), findsOneWidget);
    expect(find.text('My Profile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('withdraw earnings reaches the same tab', (tester) async {
    await _openWallet(tester);

    await _tap(tester, find.text('Withdraw earnings'));
    expect(find.text('Withdrawal schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activate plan reaches the pricing tiers', (tester) async {
    await _openWallet(tester);

    await _tap(tester, find.text('Activate plan'));
    expect(find.byType(MembershipPlanScreen), findsOneWidget);
    expect(find.text('Simple, Honest Pricing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buy bids opens the purchase sheet', (tester) async {
    await _openWallet(tester);

    await _tap(tester, find.text('Buy bids'));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Buy Bids'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('find work returns to the shell board', (tester) async {
    await _openWallet(tester);

    await _tap(tester, find.text('Find work'));
    // The shell the account already runs under moves to its board tab; no
    // second shell is mounted and the wallet is left behind.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WalletScreen), findsNothing);
    expect(find.text('Open Projects'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('money activity links to the transactions module', (
    tester,
  ) async {
    await _openWallet(tester);

    await _tap(tester, find.text('Open transactions'));
    expect(find.byType(TransactionsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wallet keeps its route name', (tester) async {
    expect(AppRoutes.routes.containsKey(RouteNames.wallet), isTrue);
  });

  testWidgets('an account with no activity still gets the whole screen', (
    tester,
  ) async {
    await _openWallet(tester);
    _backend.walletTxs.clear();
    _backend.connectLedger.clear();
    _backend.assignments.clear();
    await WalletController.instance.refresh();
    await _settle(tester);

    // The route still answered with this account's money, so its summary and
    // all three ledgers are drawn — each naming its own nothing-yet state.
    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text(r'$1240.50'), findsOneWidget);
    expect(find.text('Money activity'), findsOneWidget);
    expect(find.text('No money activity yet.'), findsOneWidget);
    expect(find.text('Connects activity'), findsOneWidget);
    expect(find.text('No connects activity yet.'), findsOneWidget);
    expect(find.text('Earnings by job'), findsOneWidget);
    expect(find.text('No approved job has paid out yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wallet holds together from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _openWallet(tester, width: width);

      expect(
        find.text('Available balance'),
        findsOneWidget,
        reason: '${width}dp',
      );
      expect(find.text('Quick actions'), findsOneWidget, reason: '${width}dp');
      expect(
        find.text('Go to Withdrawals'),
        findsOneWidget,
        reason: '${width}dp',
      );
      expect(tester.takeException(), isNull, reason: 'wallet at ${width}dp');
    }
  });
}
