import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/finance/controller/overview_controller.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/notifications/screens/notifications_screen.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

/// A signed-in device with an empty profile, so a section write can go to the
/// backend and the cards start from nothing.
Future<void> _signedIn() async {
  await _backend.install();
  _backend.issueSessionCookie();
  ProfileController.instance.clear();
}

/// Opens [route] directly from the app's own route table on a surface sized to
/// [width].
Future<void> _open(
  WidgetTester tester,
  String route, {
  double width = 400,
  double height = 1600,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
    ..remove(Navigator.defaultRouteName);

  await tester.pumpWidget(MaterialApp(routes: table, initialRoute: route));
  await _settle(tester);
  expect(tester.takeException(), isNull, reason: route);
}

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

Future<void> _type(WidgetTester tester, String hint, String value) async {
  await tester.enterText(find.widgetWithText(TextField, hint), value);
  await _settle(tester);
}

/// Matches a loaded asset image, which is how the brand marks are drawn.
Finder _assetImage(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == name,
);

/// Opens the shell on [tab].
Future<void> _pumpShell(
  WidgetTester tester,
  int tab, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
    ..remove(Navigator.defaultRouteName);
  await tester.pumpWidget(
    MaterialApp(
      routes: table,
      home: HomeScreen(initialTab: tab),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('overview shows the balances and the work behind them', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.overview);

    for (final label in [
      'Work in Progress',
      'In Review',
      'Pending',
      'Available Balance',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // Each figure is the route's own, for the jobs and withdrawals this
    // account holds; none of them is added up on the device.
    expect(find.text(r'$230.00'), findsWidgets);
    expect(find.text(r'$480.00'), findsWidgets);
    expect(find.text(r'$400.00'), findsWidgets);
    expect(find.text(r'$1240.50'), findsWidgets);
    // The sections are the jobs' own statuses, worded as the route words them.
    expect(find.text('Needs revision'), findsWidgets);
    expect(find.text('${_backend.tasks[0]['title']}'), findsWidgets);
    expect(find.text('Escrow secured'), findsNothing);
  });

  testWidgets('an account with no live jobs still shows its four amounts', (
    tester,
  ) async {
    await _signedIn();
    OverviewController.instance.clear();
    _backend.assignments.removeWhere(
      (row) => ['ACTIVE', 'SUBMITTED', 'REJECTED'].contains(row['status']),
    );
    await _open(tester, RouteNames.overview);
    await _settle(tester);

    for (final label in [
      'Work in Progress',
      'In Review',
      'Pending',
      'Available Balance',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Nothing in progress is the server's own zero, not a screen that gave up.
    expect(find.text(r'$0.00'), findsWidgets);
    expect(find.text(r'$1240.50'), findsOneWidget);
    expect(find.text('No active jobs on this account.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats shows earnings, success score and both charts', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.stats);

    for (final label in [
      '12-month earnings',
      'Job Success Score',
      'View insight',
      'Buy Bids',
      'Proposals (0)',
      'Profile metrics',
      'Proposals sent',
      'Hires',
      'Profile Views',
      'Impression & Clicks',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // The score, the total and the connects are what the stats route answered.
    expect(find.text(r'$1180.00'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Bids: 134'), findsOneWidget);
    expect(find.text('No connects scheduled for next month'), findsOneWidget);
    expect(find.text('Last 15 Days'), findsOneWidget);
    expect(find.text('Last 7 Days'), findsOneWidget);

    await _tap(tester, find.text('Impression & Clicks'));
    expect(find.textContaining('Impressions 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats opens the transactions screen from the earnings card', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.stats);

    await _tap(tester, find.text('Transaction history'));
    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text('Quick Filters:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('proposals switches between active, referrals and archived', (
    tester,
  ) async {
    await _signedIn();
    _backend.seedProposalHistory();
    await _open(tester, RouteNames.proposals);
    await _settle(tester);

    // Two active jobs and the one bid still waiting on a client.
    expect(find.text('Active Proposals (3)'), findsOneWidget);
    expect(find.text('Submitted Proposals (1)'), findsOneWidget);
    expect(find.text('${_backend.tasks[0]['title']}'), findsWidgets);

    await _tap(tester, find.text('Referrals'));
    // The backend has no referral route, so the panel is named and left empty
    // rather than borrowed from a bid status.
    expect(find.text('Referrals'), findsNWidgets(2));
    expect(find.text('Nothing here yet.'), findsOneWidget);

    await _tap(tester, find.text('Archived'));
    expect(find.text('Archived proposals (1)'), findsOneWidget);
    expect(find.text('Sent proposals and their status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports show both weekly summaries and the pro badge', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.yourReports);
    await _settle(tester);

    expect(find.text('Weekly Summary'), findsOneWidget);
    expect(find.text('Weekly Summary By Client'), findsOneWidget);
    // The Pro card is locked because the route refused it with a 403.
    expect(find.text('Upgrade to Pro'), findsOneWidget);

    await _tap(tester, find.byTooltip('Download').first);
    expect(find.textContaining('Earnings:'), findsWidgets);
    expect(find.textContaining('Approved:'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transactions lists filters, quick filters and rows', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.transactions);
    await _settle(tester);

    for (final label in [
      'Available balance',
      'Withdrawal now',
      'Pending earnings',
      'Withdrawal schedule',
      'Add a method',
      'From date',
      'To date',
      'Transaction type',
      'Client',
      'Select Download',
      'Quick Filters:',
      'Earning',
      'Withdrawals',
    ]) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    expect(find.text(r'$1240.50'), findsWidgets);
    expect(find.text(r'$880.00'), findsWidgets);
    // The rows are the feed's: the money movements it reports, in its words.
    expect(find.text('Referral bonus'), findsOneWidget);
    expect(find.text('Manual adjustment'), findsOneWidget);
    expect(find.textContaining('Showing 6 of 6.'), findsOneWidget);

    await _tap(tester, find.text('Withdrawals'));
    expect(tester.takeException(), isNull);

    // The download menu hands back the server's own weekly text, because this
    // device has no file to write.
    await _tap(tester, find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly summary'));
    await _settle(tester);
    expect(find.textContaining('Earnings:'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the date window is picked on a calendar', (tester) async {
    await _signedIn();
    await _open(tester, RouteNames.transactions);
    await _settle(tester);

    // Both ends of the window start unset, which is every row the server sent.
    expect(find.text('Any date'), findsNWidgets(2));

    await _tap(tester, find.text('Any date').first);
    expect(find.text('First day of the window'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.text('First day of the window'), findsNothing);
    expect(find.text('Any date'), findsNWidgets(2));

    // Accepting the calendar lands a real day in the field.
    await _tap(tester, find.text('Any date').first);
    await tester.tap(find.text('OK'));
    await _settle(tester);
    expect(find.text('Any date'), findsNWidgets(1));
    expect(find.byTooltip('Clear this date'), findsOneWidget);

    await _tap(tester, find.byTooltip('Clear this date'));
    await _settle(tester);
    expect(find.text('Any date'), findsNWidgets(2));

    // A year tag is the very window the two calendars would state, and the
    // rows follow it: the seed is this month's, so last year holds nothing.
    await _tap(tester, find.text('Last year'));
    expect(find.text('Any date'), findsNothing);
    expect(find.text('No transactions in this range.'), findsOneWidget);

    await _tap(tester, find.text('Last year'));
    await _settle(tester);
    expect(find.text('Any date'), findsNWidgets(2));
    expect(find.text('No transactions in this range.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the work tabs carry a notification bell', (tester) async {
    await _pumpShell(tester, 0);
    expect(find.byTooltip('Notifications'), findsOneWidget);

    await tester.tap(find.byTooltip('Notifications'));
    await _settle(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await tester.pageBack();
    await _settle(tester);
    expect(find.byTooltip('Notifications'), findsOneWidget);

    // Messages and Find Work still surface the bell; the bar itself is icons
    // only, so a destination is reached by its position.
    for (final index in [1, 2]) {
      await tester.tap(find.byType(NavigationDestination).at(index));
      await _settle(tester);
      expect(find.byTooltip('Notifications'), findsOneWidget, reason: '$index');
    }

    await tester.tap(find.byType(NavigationDestination).at(3));
    await _settle(tester);
    expect(find.byTooltip('Notifications'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the profile detail cards hold their empty states', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    for (final heading in [
      'Languages',
      'Education',
      'Linked Accounts',
      'Video Intro',
    ]) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
    // The backend has no route that returns these records, so a device cannot
    // know what the account holds and shows nothing instead of the mock rows.
    for (final empty in [
      'No languages yet',
      'No education yet',
      'No accounts linked',
      'No video intro',
    ]) {
      expect(find.text(empty), findsOneWidget, reason: empty);
    }
    expect(find.textContaining('English'), findsNothing);
    expect(find.text('Virtual University Of Pakistan'), findsNothing);
    expect(_assetImage('assets/icons/github.png'), findsNothing);
  });

  testWidgets('a language can be added from the Languages card', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    await _tap(tester, find.byTooltip('Add to Languages'));
    expect(find.text('Add language'), findsOneWidget);
    await _type(tester, 'Language', 'German');
    await _type(tester, 'Proficiency', 'Elementary');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('German: Elementary'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The row went to the languages route in the backend's own field names.
    expect(_backend.bodyFor('/api/profile/languages'), {
      'name': 'German',
      'proficiency': 'Elementary',
    });
    expect(ProfileController.instance.languages.single.id, 'r1');
  });

  testWidgets('a language can be edited and removed again', (tester) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    await _tap(tester, find.byTooltip('Add to Languages'));
    await _type(tester, 'Language', 'German');
    await _type(tester, 'Proficiency', 'Elementary');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('German: Elementary'), findsOneWidget);

    await _tap(tester, find.byTooltip('Edit Languages'));
    expect(find.text('Edit language'), findsOneWidget);
    expect(find.text('German'), findsOneWidget);
    await _type(tester, 'Proficiency', 'Intermediate');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('German: Intermediate'), findsOneWidget);
    expect(
      _backend.paths.where((path) => path == '/api/profile/languages/r1'),
      isNotEmpty,
    );

    await _tap(tester, find.byTooltip('Edit Languages'));
    expect(find.text('Edit language'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Remove'));
    expect(find.textContaining('German'), findsNothing);
    expect(find.text('No languages yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(ProfileController.instance.languages, isEmpty);
  });

  testWidgets('a language write needs a session and says so without one', (
    tester,
  ) async {
    await _backend.install();
    ProfileController.instance.clear();
    await _open(tester, RouteNames.profile, width: 1200);

    await _tap(tester, find.byTooltip('Add to Languages'));
    await _type(tester, 'Language', 'German');
    await _type(tester, 'Proficiency', 'Elementary');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);

    expect(find.text('Sign in again to save this language.'), findsOneWidget);
    expect(ProfileController.instance.languages, isEmpty);
    expect(_backend.countOf('/api/profile/languages'), 0);
  });

  testWidgets('a session that will not answer is reported under the name', (
    tester,
  ) async {
    await _signedIn();
    _backend.sessionBroken = true;

    await _open(tester, RouteNames.profile, width: 1200);

    expect(find.text('Could not reach the server.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Add to Languages'), findsOneWidget);
  });

  testWidgets('a new service can be linked to the profile', (tester) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    await _tap(tester, find.byTooltip('Add to Linked Accounts'));
    expect(find.text('Link an account'), findsOneWidget);
    await _tap(tester, find.widgetWithText(InkWell, 'LinkedIn'));
    await _type(tester, 'Profile link', 'linkedin.com/in/arslansabir');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the video intro starts empty and offers its add control', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    // The intro route stores a link rather than a file, so the add control
    // opens a form instead of the media picker.
    expect(find.text('No video intro'), findsOneWidget);
    expect(find.byTooltip('Add to Video Intro'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Add video intro'),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove Video Intro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an intro link is stored and can be removed again', (
    tester,
  ) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    await _tap(tester, find.byTooltip('Add to Video Intro'));
    await _type(tester, 'Paste a video link', 'https://youtu.be/intro');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(ProfileController.instance.videoIntro, 'https://youtu.be/intro');
    expect(find.text('https://youtu.be/intro'), findsWidgets);

    await _tap(tester, find.byTooltip('Remove Video Intro'));
    await _settle(tester);
    expect(ProfileController.instance.videoIntro, isEmpty);
    expect(find.text('No video intro'), findsOneWidget);
    expect(_backend.storedVideoIntro, isNull);
  });

  testWidgets('an intro link the route rejects is not kept', (tester) async {
    await _signedIn();
    await _open(tester, RouteNames.profile, width: 1200);

    await _tap(tester, find.byTooltip('Add to Video Intro'));
    await _type(tester, 'Paste a video link', 'not a link');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);

    expect(find.text('Enter a valid video link.'), findsOneWidget);
    expect(ProfileController.instance.videoIntro, isEmpty);
    expect(_backend.storedVideoIntro, isNull);
  });

  testWidgets('the detail cards stay usable from phone to desktop width', (
    tester,
  ) async {
    await _signedIn();
    for (final width in [320.0, 700.0, 1200.0]) {
      await _open(tester, RouteNames.profile, width: width, height: 1400);
      expect(
        find.text('Linked Accounts'),
        findsOneWidget,
        reason: '${width}dp',
      );
      expect(tester.takeException(), isNull, reason: '${width}dp');
    }
  });

  testWidgets('each module names what its screen holds under the title', (
    tester,
  ) async {
    await _signedIn();
    const Map<String, String> subtitles = {
      RouteNames.overview: 'Profile summary at a glance',
      RouteNames.stats: 'Earnings, jobs and hours',
      RouteNames.transactions: 'Balance, withdrawals & history',
      RouteNames.proposals: 'Sent proposals and their status',
      RouteNames.yourReports: 'Downloadable account reports',
      RouteNames.membershipPlan: 'Pricing tiers and their benefits',
      RouteNames.notifications: 'Alerts & reminders',
      RouteNames.settings: 'App preferences',
    };
    for (final entry in subtitles.entries) {
      // A fresh root each time: the previous app is still on the tester when
      // the loop turns, and its bar would answer first.
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, entry.key, width: 320, height: 700);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
        reason: entry.key,
      );
    }
  });

  testWidgets('every new section stays usable from phone to desktop width', (
    tester,
  ) async {
    for (final route in [
      RouteNames.overview,
      RouteNames.stats,
      RouteNames.proposals,
      RouteNames.yourReports,
      RouteNames.transactions,
    ]) {
      for (final width in [320.0, 700.0, 1200.0]) {
        await _open(tester, route, width: width, height: 1400);
        expect(tester.takeException(), isNull, reason: '$route at ${width}dp');
      }
    }
  });
}
