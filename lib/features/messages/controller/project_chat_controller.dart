import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../notifications/controller/notification_controller.dart';
import '../../notifications/services/notification_service.dart';
import '../../profile/controller/profile_controller.dart';
import '../models/project_chat.dart';
import '../services/project_chat_service.dart';

enum ChatStatus { idle, loading, ready, empty, error }

/// One authorized project conversation, read from the backend.
class ProjectChatController extends ChangeNotifier {
  ProjectChatController(this.taskId);

  final String taskId;

  final ProjectChatService _service = ProjectChatService.instance;
  final List<ChatMessage> _messages = [];

  Chat? _chat;
  ChatStatus _status = ChatStatus.idle;
  String _errorMessage = '';
  bool _loading = false;
  bool _sending = false;

  ChatStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == ChatStatus.loading;
  bool get isSending => _sending;
  int get bodyLimit => ProjectChatService.bodyLimit;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// The server's own `closed` flag. Until a thread has been read, nothing is
  /// known about it, so nothing is claimed.
  bool get isClosed => _chat?.closed ?? false;
  bool get isFlagged => _chat?.flagged ?? false;

  /// Whether the server has answered for this thread at all. Until it has, the
  /// pane has no title, no participants and nothing to write into.
  bool get isLoaded => _chat != null;
  bool get canReply => isLoaded && !isClosed && !_sending;

  String get projectTitle => _chat?.projectTitle ?? 'Project chat';

  /// Whoever the backend labels the messages that are not this account's. A
  /// thread this account started has no such label yet, so the participant the
  /// route names for the other side of this role is used instead.
  String get otherName {
    final thread = _chat;
    for (final message in _messages.reversed) {
      if (!isMine(message)) return message.displayName;
    }
    if (thread == null) return 'WorkingTrust';
    return _isAdmin
        ? (thread.freelancerName ?? thread.clientName)
        : thread.clientName;
  }

  String? get otherAvatarUrl {
    final thread = _chat;
    if (thread == null) return null;
    return _isAdmin ? thread.freelancerAvatarUrl : thread.clientAvatarUrl;
  }

  /// Staff accounts see the freelancer as the other party; everyone else is
  /// talking to the client, who has no login of their own.
  bool get _isAdmin => ProfileController.instance.role == 'ADMIN';

  /// The server's own label for this account's rows. It writes `You`, or
  /// `You (as <client>)` when staff posts on a client's behalf, so the words
  /// carry ownership even before this device has read its session.
  static bool _labelSaysMine(String displayName) =>
      displayName == 'You' || displayName.startsWith('You (');

  bool isMine(ChatMessage message) {
    final id = ProfileController.instance.userId;
    if (id.isNotEmpty) return message.senderId == id;
    return _labelSaysMine(message.displayName);
  }

  /// Reading the thread first, then clearing the unread rows that brought the
  /// user here. A notification that refuses to clear is not worth failing the
  /// chat over.
  Future<void> open() async {
    // A route can only be reached with an id from a notification, but an empty
    // one must not become a request to `/api/tasks//chat`.
    if (taskId.isEmpty) {
      _status = ChatStatus.error;
      _errorMessage = 'This message did not name a project.';
      notifyListeners();
      return;
    }
    await load();
    await clearUnread();
  }

  Future<void> load({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent && _chat == null) {
      _status = ChatStatus.loading;
      notifyListeners();
    }
    try {
      final thread = await _service.load(taskId);
      _chat = thread;
      _messages
        ..clear()
        ..addAll(thread.messages);
      _status = thread.messages.isEmpty ? ChatStatus.empty : ChatStatus.ready;
      _errorMessage = '';
    } on NetworkException catch (e) {
      _fail(e);
    } catch (e) {
      _fail(NetworkException('Could not load this conversation.'));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Answers true only once the server has stored the message. The row the
  /// `POST` returns is what lands in the list, so nothing here is ever shown
  /// ahead of the backend agreeing.
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return false;
    if (isClosed) {
      _errorMessage = 'This conversation is closed.';
      notifyListeners();
      return false;
    }
    if (body.length > bodyLimit) {
      _errorMessage = 'A message can be up to $bodyLimit characters.';
      notifyListeners();
      return false;
    }

    _sending = true;
    notifyListeners();
    try {
      final entry = await _service.send(taskId, body: body);
      _messages.add(entry);
      _status = ChatStatus.ready;
      _errorMessage = '';
      return true;
    } on NetworkException catch (e) {
      _fail(e);
      return false;
    } catch (e) {
      _fail(NetworkException('Your message was not sent.'));
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> clearUnread() async {
    try {
      await NotificationService.instance.markTaskChatRead(taskId);
      await NotificationController.instance.refresh(silent: true);
    } catch (_) {
      // The unread count is the shell's business; a lost PATCH only means the
      // bell still shows a number.
    }
  }

  void _fail(NetworkException e) {
    _errorMessage = e.statusCode == 401
        ? NotificationController.sessionExpired
        : e.message;
    // Rows already on screen stay there; only a thread that never loaded can
    // take over the whole pane.
    if (_chat == null) _status = ChatStatus.error;
  }
}
