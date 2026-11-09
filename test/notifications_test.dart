import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/messages/screens/project_chat_screen.dart';
import 'package:working_trust/features/notifications/controller/notification_controller.dart';
import 'package:working_trust/features/notifications/screens/notifications_screen.dart';
import 'package:working_trust/features/profile/screens/proposals_screen.dart';

import 'fake_backend.dart';

late FakeBackend _backend;

/// The shell's bell chip, ignoring any badge a tab body draws.
final Finder _bellBadge = find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(Badge),
);

/// The feed's own list, so gestures cannot land on a tab body behind it.
final Finder _feedList = find.descendant(
  of: find.byType(NotificationsScreen),
  matching: find.byType(ListView),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _advance(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await _settle(tester);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  double width = 390,
  double height = 1800,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      routes: Map.of(AppRoutes.routes)..remove(Navigator.defaultRouteName),
      home: const HomeScreen(),
    ),
  );
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

/// Signs in through the cookie jar, then opens the feed through the bell.
Future<void> _openFeed(WidgetTester tester) async {
  _backend.issueSessionCookie();
  await _pumpShell(tester);
  await tester.tap(find.byTooltip('Notifications').first);
  await _settle(tester);
  expect(find.byType(NotificationsScreen), findsOneWidget);
}

void main() {
  setUp(() async {
    _backend = FakeBackend();
    await _backend.install();
    NotificationController.instance.endSession();
  });

  tearDown(() => NotificationController.instance.endSession());

  testWidgets('a signed-out device never asks for notifications', (
    tester,
  ) async {
    await _pumpShell(tester);
    expect(_backend.countOf('/api/notifications'), 0);
    expect(_bellBadge, findsNothing);
  });

  testWidgets('the bell shows the unread count the server reported', (
    tester,
  ) async {
    _backend.issueSessionCookie();
    await _pumpShell(tester);
    expect(_backend.countOf('/api/notifications'), 1);
    // Two seeded rows have a null readAt; the third is read.
    expect(
      find.descendant(of: _bellBadge, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('the request rides the session cookie, not a bearer token', (
    tester,
  ) async {
    _backend.issueSessionCookie();
    await _pumpShell(tester);
    final request = _backend.requests.lastWhere(
      (r) => r.url.path == '/api/notifications',
    );
    expect(request.headers['cookie'], contains('next-auth.session-token'));
    expect(request.headers['authorization'], isNull);
  });

  testWidgets('the feed shows the real titles, bodies, types and ages', (
    tester,
  ) async {
    await _openFeed(tester);

    expect(find.text('Your bid was awarded'), findsOneWidget);
    expect(find.text('Message from Hana'), findsOneWidget);
    expect(find.text('Payout on its way'), findsOneWidget);
    expect(
      find.text('Shopify Store Redesign is yours. Add a milestone to begin.'),
      findsOneWidget,
    );
    // The backend's own type values, re-spaced rather than re-invented.
    expect(find.text('Bid awarded'), findsOneWidget);
    expect(find.text('Chat message'), findsOneWidget);
    expect(find.text('8 min ago'), findsOneWidget);
    expect(find.text('5 h ago'), findsOneWidget);
  });

  testWidgets('readAt drives the unread marker', (tester) async {
    await _openFeed(tester);

    expect(find.byKey(const ValueKey('unread-dot-n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot-n2')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot-n3')), findsNothing);
  });

  testWidgets('tapping a row PATCHes just that id', (tester) async {
    await _openFeed(tester);

    await tester.tap(find.text('Your bid was awarded'));
    await _settle(tester);

    expect(_backend.bodyFor('/api/notifications'), {'id': 'n1'});
    expect(find.byKey(const ValueKey('unread-dot-n1')), findsNothing);
    expect(find.byKey(const ValueKey('unread-dot-n2')), findsOneWidget);
  });

  testWidgets('dismiss PATCHes dismiss true and drops the row', (tester) async {
    await _openFeed(tester);

    await tester.tap(find.byTooltip('Dismiss').first);
    await _settle(tester);

    expect(_backend.bodyFor('/api/notifications'), {
      'id': 'n1',
      'dismiss': true,
    });
    expect(find.text('Your bid was awarded'), findsNothing);
    expect(find.text('Message from Hana'), findsOneWidget);
  });

  testWidgets('mark all read PATCHes all true and clears the bell', (
    tester,
  ) async {
    await _openFeed(tester);

    await tester.tap(find.byTooltip('Mark all read'));
    await _settle(tester);

    expect(_backend.bodyFor('/api/notifications'), {'all': true});
    expect(find.byKey(const ValueKey('unread-dot-n1')), findsNothing);
    expect(find.byKey(const ValueKey('unread-dot-n2')), findsNothing);

    await tester.pageBack();
    await _settle(tester);
    expect(_bellBadge, findsNothing);
  });

  testWidgets('an empty feed says so', (tester) async {
    _backend.issueSessionCookie();
    _backend.notifications.clear();
    await _openFeed(tester);

    expect(find.text('No notifications yet.'), findsOneWidget);
  });

  testWidgets('a server failure offers a retry, which then loads', (
    tester,
  ) async {
    _backend.issueSessionCookie();
    _backend.notificationsBroken = true;
    await _openFeed(tester);

    expect(
      find.text('The server had a problem. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    _backend.notificationsBroken = false;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await _settle(tester);
    expect(find.text('Payout on its way'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the rows it already had', (tester) async {
    await _openFeed(tester);
    _backend.notificationsBroken = true;

    await NotificationController.instance.refresh(silent: true);
    await _settle(tester);

    expect(find.text('Your bid was awarded'), findsOneWidget);
  });

  testWidgets('a 401 names the expired session and clears the feed', (
    tester,
  ) async {
    await _openFeed(tester);
    final before = _backend.countOf('/api/notifications');

    _backend.sessionRevoked = true;
    await NotificationController.instance.refresh(silent: true);
    await _settle(tester);

    expect(find.text(NotificationController.sessionExpired), findsOneWidget);
    expect(_backend.countOf('/api/notifications'), before + 1);

    // Nothing is left asking: the feed only re-reads on an event, and there is
    // no event.
    await _advance(tester, const Duration(minutes: 1));
    expect(_backend.countOf('/api/notifications'), before + 1);
  });

  testWidgets('the shell reads the feed once and then stays quiet', (
    tester,
  ) async {
    _backend.issueSessionCookie();
    await _pumpShell(tester);
    expect(_backend.countOf('/api/notifications'), 1);

    await _advance(tester, const Duration(minutes: 2));
    expect(_backend.countOf('/api/notifications'), 1);
  });

  testWidgets('a second read is dropped while one is in flight', (
    tester,
  ) async {
    _backend.slowFeed = true;
    _backend.issueSessionCookie();
    await _pumpShell(tester);
    final before = _backend.countOf('/api/notifications');

    // The fake server is holding this read's answer. A second refresh asked for
    // while it is outstanding is dropped rather than stacked up.
    NotificationController.instance.refresh(silent: true);
    await tester.pump();
    NotificationController.instance.refresh(silent: true);
    await tester.pump();
    expect(_backend.countOf('/api/notifications'), before + 1);

    // Release it, so a held request cannot leak into the next test through the
    // shared controller.
    await _advance(tester, const Duration(milliseconds: 400));
    expect(NotificationController.instance.isRefreshing, isFalse);
  });

  testWidgets('disposing the shell stops the reads', (tester) async {
    _backend.issueSessionCookie();
    await _pumpShell(tester);
    final seen = _backend.countOf('/api/notifications');

    await tester.pumpWidget(const SizedBox());
    await _settle(tester);

    await _advance(tester, const Duration(minutes: 1));
    expect(_backend.countOf('/api/notifications'), seen);
  });

  testWidgets('backgrounding the app pauses it, resuming reloads', (
    tester,
  ) async {
    _backend.issueSessionCookie();
    await _pumpShell(tester);
    final afterOpen = _backend.countOf('/api/notifications');

    final binding = TestWidgetsFlutterBinding.instance;
    // A backgrounded app goes inactive first, and the framework refuses to
    // deliver any other state after that.
    // ignore: invalid_use_of_visible_for_testing_member
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _advance(tester, const Duration(minutes: 1));
    expect(_backend.countOf('/api/notifications'), afterOpen);

    // ignore: invalid_use_of_visible_for_testing_member
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(_backend.countOf('/api/notifications'), afterOpen + 1);
  });

  testWidgets('pull to refresh re-reads', (tester) async {
    _backend.issueSessionCookie();
    // A phone-height viewport, because RefreshIndicator only opens on a pull
    // past half the viewport and the taller shell would swallow the gesture.
    await _pumpShell(tester, height: 800);
    await tester.tap(find.byTooltip('Notifications').first);
    await _settle(tester);
    final before = _backend.countOf('/api/notifications');

    await tester.drag(_feedList, const Offset(0, 450));
    await _settle(tester);

    expect(_backend.countOf('/api/notifications'), greaterThan(before));
  });

  testWidgets('signing out drops every notification body', (tester) async {
    await _openFeed(tester);
    expect(NotificationController.instance.notifications, isNotEmpty);

    NotificationController.instance.endSession();
    await _settle(tester);

    expect(NotificationController.instance.notifications, isEmpty);
    expect(NotificationController.instance.unread, 0);
    expect(find.text('No notifications yet.'), findsOneWidget);
  });

  testWidgets('the feed stays usable at phone, tablet and desktop widths', (
    tester,
  ) async {
    for (final width in const [320.0, 700.0, 1200.0]) {
      _backend.issueSessionCookie();
      await _pumpShell(tester, width: width);
      await tester.tap(find.byTooltip('Notifications').first);
      await _settle(tester);

      expect(
        find.text('Your bid was awarded'),
        findsOneWidget,
        reason: '$width',
      );
      expect(find.text('Withdrawal paid'), findsOneWidget, reason: '$width');
      expect(tester.takeException(), isNull, reason: 'width $width');

      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    }
  });

  testWidgets('a chat message opens the project it names', (tester) async {
    await _openFeed(tester);

    await tester.tap(find.text('Message from Hana'));
    await _settle(tester);
    await _settle(tester);

    expect(find.byType(ProjectChatScreen), findsOneWidget);
    expect(_backend.paths, contains('/api/tasks/t9/chat'));
    // The thread is the server's own, and the row that led here is read.
    expect(find.text('Yes — sending it now.'), findsOneWidget);
    expect(
      _backend.notifications.firstWhere((r) => r['id'] == 'n2')['readAt'],
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a proposal notification opens proposals', (tester) async {
    await _openFeed(tester);

    await tester.tap(find.text('Your bid was awarded'));
    await _settle(tester);

    expect(find.byType(ProposalsScreen), findsOneWidget);
    expect(
      _backend.notifications.firstWhere((r) => r['id'] == 'n1')['readAt'],
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app only ever reads and mutates, never creates', (
    tester,
  ) async {
    await _openFeed(tester);
    await tester.tap(find.byTooltip('Dismiss').first);
    await _settle(tester);

    for (final request in _backend.requests.where(
      (r) => r.url.path == '/api/notifications',
    )) {
      expect(request.method, anyOf('GET', 'PATCH'), reason: '$request');
    }
  });
}
