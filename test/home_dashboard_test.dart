import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/theme/app_colors.dart';
import 'package:working_trust/features/finance/controller/overview_controller.dart';
import 'package:working_trust/features/finance/controller/stats_controller.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/home/screens/dashboard_screen.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/screens/transactions_screen.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

/// Opens the shell on the dashboard tab, signed in so the greeting can only
/// show what the session answers with.
Future<void> _pump(
  WidgetTester tester, {
  double width = 400,
  double height = 1600,
}) async {
  await _backend.install();
  _backend.issueSessionCookie();
  ProfileController.instance.clear();
  // The three figures are read again for this board, so a value left over from
  // another test would silence the very traffic these tests count.
  WalletController.instance.clear();
  OverviewController.instance.clear();
  StatsController.instance.clear();
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The app's own table, minus "/" because `home` already owns it.
  final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
    ..remove(Navigator.defaultRouteName);
  await tester.pumpWidget(MaterialApp(routes: table, home: const HomeScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // The rings sweep for 900ms; the assertion is about the settled state.
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the dashboard reports the score, the connects and the money', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Performances'), findsOneWidget);
    expect(find.text('Plan active'), findsOneWidget);

    // The one percentage a route reports, drawn as a ring and as its words.
    expect(find.text('Job Success Score'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Earnings (last 12 months)'), findsOneWidget);
    expect(find.text(r'$1180.00'), findsOneWidget);
    for (final label in [
      'Proposals sent',
      'Were viewed',
      'Interviews',
      'Hires',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // The card that opens on a tap, so the figures it holds are not on screen
    // yet, and the four amounts the overview route totalled.
    expect(find.text('Connects and deposits'), findsOneWidget);
    expect(find.text('Connects on account'), findsNothing);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text(r'$1240.50'), findsOneWidget);
    expect(find.text(r'$230.00'), findsOneWidget);
    expect(find.text(r'$480.00'), findsOneWidget);
    expect(find.text(r'$400.00'), findsOneWidget);
    final amountColors = [
      for (final amount in [r'$1240.50', r'$230.00', r'$480.00', r'$400.00'])
        tester.widget<Text>(find.text(amount)).style!.color,
    ];
    expect(amountColors.toSet(), hasLength(4));
    expect(amountColors, isNot(contains(AppColors.textPrimary)));
    // A seller level and a level progress bar have no route behind them.
    expect(find.text('Level one'), findsNothing);
    expect(find.text('Next evaluation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the greeting is the session, not a name the app invented', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Someone'), findsWidgets);
    expect(find.text('Muhammad Arslan'), findsNothing);
    expect(find.text('Freelancer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ring sweeps once and settles', (tester) async {
    await _pump(tester);

    // One ring, for the one percentage a route reports. Its sweep is a finite
    // tween, so [pumpAndSettle] returned above; a repeating animation would
    // never have let it.
    final rings = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter?.runtimeType.toString() == '_RingPainter',
    );
    expect(rings, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dashboard reads only the routes behind its figures', (
    tester,
  ) async {
    await _pump(tester);

    for (final path in [
      '/api/wallet',
      '/api/reports/overview',
      '/api/reports/my-stats',
    ]) {
      // Once, from the first frame — not again on every build.
      expect(_backend.countOf(path), 1, reason: path);
    }
    // The board is not mounted on this tab, so its endpoints must not be asked
    // either.
    expect(_backend.paths, isNot(contains('/api/tasks')));
    expect(_backend.paths, isNot(contains('/api/categories')));
    expect(_backend.countOf('/api/auth/session'), 1);
  });

  testWidgets('the connects card opens and closes on a tap', (tester) async {
    await _pump(tester);

    final card = find.text('Connects and deposits');
    expect(find.text('Connects on account'), findsNothing);

    await _tap(tester, card);
    expect(find.text('Connects on account'), findsOneWidget);
    // The count is the wallet route's, not a number the screen wrote.
    expect(find.text('134'), findsOneWidget);
    expect(find.text('No deposit is waiting to be credited.'), findsOneWidget);
    expect(find.text('Open wallet'), findsOneWidget);

    await _tap(tester, card);
    expect(find.text('Connects on account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('earnings details opens the transactions screen', (tester) async {
    await _pump(tester);

    await _tap(tester, find.text('Details'));
    expect(find.byType(TransactionsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dashboard stays usable from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _pump(tester, width: width);
      expect(find.text('Earnings'), findsOneWidget, reason: '${width}dp');
      expect(
        find.text('Available for withdrawal'),
        findsOneWidget,
        reason: '${width}dp',
      );
      expect(tester.takeException(), isNull, reason: 'dashboard at ${width}dp');
    }
  });
}
