import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/app/theme/app_colors.dart';
import 'package:working_trust/features/auth/screens/login_screen.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/membership/screens/membership_plan_screen.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/screens/profile_screen.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

const List<String> _entries = [
  'View Profile',
  'Overview',
  'Stats',
  'Wallet',
  'Transactions',
  'Notifications',
  'Proposals',
  'Your Reports',
  'Membership Plan',
  'Settings',
];

/// What each module's own header says, which is not always what the row says.
const Map<String, ({String subtitle, String title})> _moduleTitles = {
  'View Profile': (
    title: 'View Profile',
    subtitle: 'Photo, stats, portfolio & work history',
  ),
  'Overview': (title: 'Overview', subtitle: 'Profile summary at a glance'),
  'Stats': (title: 'My stats', subtitle: 'Earnings, jobs and hours'),
  'Wallet': (title: 'Wallet', subtitle: 'Balance, connects & activity'),
  'Transactions': (
    title: 'Transactions',
    subtitle: 'Balance, withdrawals & history',
  ),
  'Notifications': (title: 'Notifications', subtitle: 'Alerts & reminders'),
  'Proposals': (
    title: 'My proposals',
    subtitle: 'Sent proposals and their status',
  ),
  'Your Reports': (
    title: 'My Reports',
    subtitle: 'Downloadable account reports',
  ),
  'Membership Plan': (
    title: 'Membership Plan',
    subtitle: 'Pricing tiers and their benefits',
  ),
  'Settings': (title: 'Settings', subtitle: 'App preferences'),
};

/// Opens the shell on the Profile tab, the only place the menu is rendered,
/// signed in so the header can only show what the session answers with.
Future<void> _pumpMenu(WidgetTester tester, {double width = 400}) async {
  await _backend.install();
  _backend.issueSessionCookie();
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
    ..remove(Navigator.defaultRouteName);
  await tester.pumpWidget(
    MaterialApp(routes: table, home: const HomeScreen(initialTab: 3)),
  );
  // One frame mounts the tab, the next runs the profile's session read.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => ProfileController.instance.clear());

  testWidgets('profile tab lists every section and the log out action', (
    tester,
  ) async {
    await _pumpMenu(tester);

    // The account the fake session describes, not the identity the mock ships.
    expect(find.text('Someone'), findsOneWidget);
    expect(find.textContaining('@gmail.com'), findsOneWidget);
    expect(find.text('Muhammad Arslan'), findsNothing);
    for (final entry in _entries) {
      expect(find.text(entry), findsOneWidget, reason: entry);
    }
    expect(find.text('Log out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('view profile opens the implemented profile details', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await _tap(tester, find.text('View Profile'));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Total Earning'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings opens the sectioned settings screen', (tester) async {
    await _pumpMenu(tester);

    await _tap(tester, find.text('Settings'));
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Experience Level'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications keeps its existing route', (tester) async {
    await _pumpMenu(tester);
    expect(AppRoutes.routes.containsKey(RouteNames.notifications), isTrue);

    await _tap(tester, find.text('Notifications'));
    expect(find.text('Notifications'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('membership plan is reached from the module list', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await _tap(tester, find.text('Membership Plan'));
    expect(find.byType(MembershipPlanScreen), findsOneWidget);
    expect(find.text('Simple, Honest Pricing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every module opens under the tinted bar, and keeps no logo', (
    tester,
  ) async {
    for (final entry in _moduleTitles.entries) {
      // A fresh root, because the module pushed last iteration is still on the
      // navigator and its row would not be in the menu any more.
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpMenu(tester);
      await _tap(tester, find.text(entry.key));

      final bar = find.byType(AppBar).last;
      final header = tester.widget<AppBar>(bar);
      expect(header.backgroundColor, AppColors.primary, reason: entry.key);
      expect(
        header.foregroundColor,
        AppColors.textOnPrimary,
        reason: entry.key,
      );
      expect(
        header.systemOverlayStyle,
        SystemUiOverlayStyle.light,
        reason: entry.key,
      );
      expect(
        find.descendant(of: bar, matching: find.text(entry.value.title)),
        findsOneWidget,
        reason: entry.value.title,
      );
      // The header answers what the screen holds, not just what it is called.
      expect(
        find.descendant(of: bar, matching: find.text(entry.value.subtitle)),
        findsOneWidget,
        reason: '${entry.key} subtitle',
      );
      // The brand mark belongs to the shell alone; a module the user reached
      // from it has its own title instead.
      expect(
        find.descendant(of: bar, matching: find.byType(Image)),
        findsNothing,
        reason: '${entry.key} wears no logo',
      );
      expect(tester.takeException(), isNull, reason: entry.key);
    }
  });

  testWidgets('log out returns to the login screen', (tester) async {
    await _pumpMenu(tester);

    await _tap(tester, find.text('Log out'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu stays usable from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _pumpMenu(tester, width: width);
      expect(find.text('Log out'), findsOneWidget, reason: '${width}dp');
      expect(tester.takeException(), isNull, reason: 'menu at ${width}dp');
    }
  });
}
