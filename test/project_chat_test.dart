import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/core/utils/link_opener.dart';
import 'package:working_trust/features/messages/controller/project_chat_controller.dart';
import 'package:working_trust/features/messages/models/project_chat.dart';
import 'package:working_trust/features/messages/models/project_conversation.dart';
import 'package:working_trust/features/messages/screens/messages_screen.dart';
import 'package:working_trust/features/messages/screens/project_chat_screen.dart';
import 'package:working_trust/features/notifications/controller/notification_controller.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

/// The chat route takes its task id as a route argument, so a test mounts the
/// screen the way the app does.
Future<void> _pumpChat(WidgetTester tester, {String taskId = 't9'}) async {
  tester.view.physicalSize = const Size(400 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: ProjectChatScreen(taskId: taskId)));
  await _settle(tester);
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width * 3, 1500 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(routes: {'/': (_) => Scaffold(body: screen)}),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _composer() => find.widgetWithText(TextField, 'Write a message');

Finder _draftField() => find.byType(TextField).last;

Finder _sendButton() => find.ancestor(
  of: find.byIcon(Icons.send_rounded),
  matching: find.byType(IconButton),
);

/// One of the thread's own rows, so the composer's draft text never counts.
Finder _bubble(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(_composer(), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
}

Map<String, dynamic> _conversationRow({
  String taskId = 't9',
  String name = 'Hana',
  String preview = 'Can you share the Figma link?',
  int unreadCount = 1,
  DateTime? lastMessageAt,
}) => {
  'taskId': taskId,
  'projectTitle': 'Shopify Store Redesign',
  'name': name,
  'preview': preview,
  'lastMessageAt': (lastMessageAt ?? DateTime.now()).toUtc().toIso8601String(),
  'unreadCount': unreadCount,
  'flagged': false,
  'closed': false,
};

void main() {
  setUp(() async {
    await _backend.install();
    _backend.issueSessionCookie();
    NotificationController.instance.endSession();
    ProfileController.instance.clear();
    // `isMine` needs the account id, which the real app takes from the session.
    ProfileController.instance.userId = 'u1';
    LinkOpener.launch = (Uri _) async => true;
  });

  group('the conversation inbox', () {
    test('parses the backend conversation shape and unread count', () {
      final conversation = ProjectConversation.fromJson(
        _conversationRow(unreadCount: 3),
      );
      expect(conversation.taskId, 't9');
      expect(conversation.name, 'Hana');
      expect(conversation.preview, 'Can you share the Figma link?');
      expect(conversation.unread, isTrue);
      expect(conversation.unreadCount, 3);
    });

    testWidgets('loads conversation rows from the dedicated endpoint', (
      tester,
    ) async {
      await _pump(tester, const MessagesScreen());

      expect(find.text('Hana'), findsOneWidget);
      expect(
        find.text('Can you share the Figma link before we start?'),
        findsOneWidget,
      );
      expect(_backend.countOf('/api/conversations'), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty conversation response shows the empty state', (
      tester,
    ) async {
      _backend.conversationRows.clear();
      await _pump(tester, const MessagesScreen());

      expect(find.text('No project conversations yet'), findsOneWidget);
      expect(find.text('Hana'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed inbox load is visible and can be retried', (
      tester,
    ) async {
      _backend.conversationsBroken = true;
      await _pump(tester, const MessagesScreen());

      expect(find.text('Unable to load conversations.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('reading a thread', () {
    testWidgets('shows the server\'s rows in the server\'s order', (
      tester,
    ) async {
      _backend.seedChat(
        't9',
        messages: [
          FakeBackend.chatRow(
            'Can you share the Figma link before we start?',
            senderId: 'admin1',
            senderName: 'Hana',
            senderRole: 'ADMIN',
            ago: const Duration(days: 1),
          ),
          FakeBackend.chatRow('Yes — sending it now.'),
        ],
      );
      await _pumpChat(tester);

      expect(find.text('Shopify Store Redesign'), findsOneWidget);
      // The oldest row sits above the newest one, which is how the backend sent
      // them; the list is only turned around so the newest sits at the bottom.
      expect(
        tester.getBottomLeft(find.textContaining('Figma link')).dy,
        lessThan(tester.getTopLeft(find.text('Yes — sending it now.')).dy),
      );
      expect(_backend.countOf('/api/tasks/t9/chat'), 1);
    });

    testWidgets('labels each side with the names the backend chose', (
      tester,
    ) async {
      _backend.seedChat(
        't9',
        messages: [
          FakeBackend.chatRow('Yours', senderId: 'u1', senderName: 'Someone'),
          FakeBackend.chatRow(
            'Theirs',
            senderId: 'admin1',
            senderName: 'Hana',
            senderRole: 'ADMIN',
          ),
        ],
      );
      await _pumpChat(tester);

      expect(find.text('Theirs'), findsOneWidget);
      // The account's own rows carry the server's 'You', never a local guess.
      expect(find.text('You'), findsNothing);
      expect(find.text('Hana'), findsWidgets);
    });

    testWidgets('a thread nobody has written in says so and still replies', (
      tester,
    ) async {
      _backend.seedChat('t9', messages: []);
      await _pumpChat(tester);

      expect(find.text('No messages yet on this project.'), findsOneWidget);
      expect(_composer(), findsOneWidget);
    });

    testWidgets('an unread thread is cleared on the server, once', (
      tester,
    ) async {
      await _pumpChat(tester);

      final patch = _backend.requests.lastWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path == '/api/notifications',
      );
      expect(jsonDecode(patch.body), {'taskId': 't9'});
      expect(
        _backend.notifications.firstWhere((row) => row['id'] == 'n2')['readAt'],
        isNotNull,
      );
    });

    testWidgets('a bell that fails still opens the conversation', (
      tester,
    ) async {
      _backend.notificationsBroken = true;
      await _pumpChat(tester);

      expect(find.text('Yes — sending it now.'), findsOneWidget);
      expect(_composer(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a thread the account was not hired on is refused plainly', (
      tester,
    ) async {
      _backend.seedChat('t9', hired: false);
      await _pumpChat(tester);

      expect(
        find.text('Chat unlocks only after you are hired on this project.'),
        findsOneWidget,
      );
      expect(_composer(), findsNothing);
    });

    testWidgets(
      'an expired session says so rather than showing an empty pane',
      (tester) async {
        _backend.sessionRevoked = true;
        await _pumpChat(tester);

        expect(
          find.text(NotificationController.sessionExpired),
          findsOneWidget,
        );
      },
    );

    testWidgets('a failure can be retried, and the retry is the same read', (
      tester,
    ) async {
      _backend.chatBroken = true;
      await _pumpChat(tester);
      expect(
        find.text('The server had a problem. Please try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      _backend.chatBroken = false;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await _settle(tester);

      expect(find.text('Yes — sending it now.'), findsOneWidget);
      expect(_backend.countOf('/api/tasks/t9/chat'), 2);
    });

    testWidgets('a route reached without a task id asks no request', (
      tester,
    ) async {
      await _pumpChat(tester, taskId: '');

      expect(find.text('This message did not name a project.'), findsOneWidget);
      expect(
        _backend.paths.any((path) => path.startsWith('/api/tasks/')),
        isFalse,
        reason: 'an id-less route must not ask the server about a project',
      );
    });

    test('a row that stops carrying a field still opens', () {
      final thread = Chat.fromJson({
        'projectTitle': 'Logo',
        'clientName': 'Hana',
        'messages': [
          {'body': 'ok', 'createdAt': 'not a timestamp'},
          {'body': '', 'displayName': null},
          'junk',
        ],
      });

      expect(thread.projectTitle, 'Logo');
      expect(thread.closed, isFalse);
      expect(thread.messages.length, 2);
      expect(thread.messages.first.displayName, 'WorkingTrust');
      expect(thread.messages.first.fromClient, isFalse);
      expect(thread.messages.last.id, isEmpty);
    });
  });

  group('sending', () {
    testWidgets('shows the message only after the server confirms it', (
      tester,
    ) async {
      _backend.slowChat = true;
      await _pumpChat(tester);
      await _send(tester, 'I can start Monday.');

      // The round trip is still open, so the thread shows no such row and the
      // field still holds the words.
      expect(_bubble('I can start Monday.'), findsNothing);
      expect(
        tester.widget<TextField>(_composer()).controller!.text,
        'I can start Monday.',
      );

      _backend.slowChat = false;
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);

      expect(_bubble('I can start Monday.'), findsOneWidget);
      expect(tester.widget<TextField>(_composer()).controller!.text, isEmpty);
      expect(jsonDecode(_lastChatPost), {
        'body': 'I can start Monday.',
        'attachmentUrl': null,
      });
      expect(_backend.countOf('/api/tasks/t9/chat'), 2);
    });

    testWidgets('a refused send keeps the unsent text for fixing', (
      tester,
    ) async {
      await _pumpChat(tester);
      _backend.chatBroken = true;
      await _send(tester, 'This one will not land.');
      await _settle(tester);

      expect(_bubble('This one will not land.'), findsNothing);
      expect(
        tester.widget<TextField>(_composer()).controller!.text,
        'This one will not land.',
      );
      expect(
        find.text('The server had a problem. Please try again.'),
        findsOneWidget,
      );
      expect(_backend.chatRows['t9'], hasLength(2));
    });

    testWidgets('the second tap of a pair is dropped, not doubled', (
      tester,
    ) async {
      _backend.slowChat = true;
      await _pumpChat(tester);
      await _send(tester, 'Sent once.');
      expect(tester.widget<IconButton>(_sendButton()).onPressed, isNull);

      await _settle(tester);
      expect(_backend.chatRows['t9'], hasLength(3));
      expect(_bubble('Sent once.'), findsOneWidget);
    });

    testWidgets('an empty draft asks the server nothing', (tester) async {
      await _pumpChat(tester);
      await _send(tester, '   ');
      await _settle(tester);

      expect(_backend.countOf('/api/tasks/t9/chat'), 1);
      expect(_composer(), findsOneWidget);
    });

    testWidgets('the composer takes exactly the backend\'s 2000 characters', (
      tester,
    ) async {
      await _pumpChat(tester);
      await tester.enterText(_composer(), 'x' * 2001);
      await tester.pump();

      expect(
        tester.widget<TextField>(_composer()).controller!.text.length,
        2000,
      );
    });

    testWidgets('a closed thread cannot write into it', (tester) async {
      _backend.seedChat('t9', closed: true);
      await _pumpChat(tester);

      expect(find.text('This conversation is closed.'), findsOneWidget);
      final field = tester.widget<TextField>(_draftField());
      expect(field.enabled, isFalse);
      expect(field.decoration!.hintText, 'This conversation is closed');
      expect(tester.widget<IconButton>(_sendButton()).onPressed, isNull);
    });

    test(
      'a send is refused locally before it can break the server\'s rule',
      () async {
        final controller = ProjectChatController('t9');
        await controller.load();

        expect(await controller.send('x' * 2001), isFalse);
        expect(
          controller.errorMessage,
          'A message can be up to 2000 characters.',
        );
        expect(_backend.countOf('/api/tasks/t9/chat'), 1);
        controller.dispose();
      },
    );

    test('a suspended account is told in the backend\'s own words', () async {
      final controller = ProjectChatController('t9');
      await controller.load();
      _backend.accountSuspended = true;

      expect(await controller.send('Try me.'), isFalse);
      expect(controller.errorMessage, 'Account suspended.');
      controller.dispose();
    });
  });

  group('attachments', () {
    testWidgets('an existing link opens outside the app', (tester) async {
      Uri? opened;
      LinkOpener.launch = (Uri uri) async {
        opened = uri;
        return true;
      };
      _backend.seedChat(
        't9',
        messages: [
          FakeBackend.chatRow(
            'Here is the brief.',
            senderId: 'admin1',
            senderName: 'Hana',
            senderRole: 'ADMIN',
            file: 'https://files.example/brief.pdf',
          ),
        ],
      );
      await _pumpChat(tester);

      await tester.tap(find.text('https://files.example/brief.pdf'));
      await _settle(tester);
      expect(opened, Uri.parse('https://files.example/brief.pdf'));
    });

    testWidgets('a link no app can handle is reported, not swallowed', (
      tester,
    ) async {
      LinkOpener.launch = (Uri _) async => false;
      _backend.seedChat(
        't9',
        messages: [
          FakeBackend.chatRow(
            'Here is the brief.',
            senderId: 'admin1',
            senderName: 'Hana',
            senderRole: 'ADMIN',
            file: 'https://files.example/brief.pdf',
          ),
        ],
      );
      await _pumpChat(tester);

      await tester.tap(find.text('https://files.example/brief.pdf'));
      await _settle(tester);
      expect(
        find.text('No app on this device can open that link.'),
        findsOneWidget,
      );
    });

    testWidgets('uploading a file is not offered as a feature', (tester) async {
      await _pumpChat(tester);

      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.attachment_rounded), findsNothing);
    });
  });
}

/// The body of the last request that posted to the thread.
String get _lastChatPost => _backend.requests
    .lastWhere(
      (request) =>
          request.method == 'POST' && request.url.path == '/api/tasks/t9/chat',
    )
    .body;
