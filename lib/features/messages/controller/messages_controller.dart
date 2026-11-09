import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../models/project_conversation.dart';
import '../models/chat_stamps.dart';
import '../services/project_chat_service.dart';

/// One row of the Messages list.
typedef ConversationRow = ({
  String taskId,
  String name,
  String preview,
  String stamp,
  bool unread,
});

enum ConversationListStatus { idle, loading, ready, empty, error }

/// Loads the server-authorized task conversations and applies local filters.
class MessagesController extends ChangeNotifier {
  static const List<String> filters = ['All', 'Unread'];

  final ProjectChatService _service = ProjectChatService.instance;
  final List<ProjectConversation> _conversations = [];
  String _query = '';
  int _filter = 0;
  bool _loading = false;
  ConversationListStatus _status = ConversationListStatus.idle;
  String _errorMessage = '';

  int get selectedFilter => _filter;
  ConversationListStatus get status => _status;
  bool get isLoading => _status == ConversationListStatus.loading;
  String get errorMessage => _errorMessage;

  List<ConversationRow> get conversations {
    final query = _query.trim().toLowerCase();
    return [
      for (final conversation in _conversations)
        if ((_filter != 1 || conversation.unread) &&
            (query.isEmpty ||
                conversation.name.toLowerCase().contains(query) ||
                conversation.preview.toLowerCase().contains(query)))
          (
            taskId: conversation.taskId,
            name: conversation.name,
            preview: conversation.preview,
            stamp: conversation.lastMessageAt == null
                ? '—'
                : chatStamp(conversation.lastMessageAt!),
            unread: conversation.unread,
          ),
    ];
  }

  Future<void> load({bool silent = false}) async {
    if (_loading) return;
    _loading = true;
    if (!silent && _conversations.isEmpty) {
      _status = ConversationListStatus.loading;
      notifyListeners();
    }

    try {
      final conversations = await _service.loadConversations();
      _conversations
        ..clear()
        ..addAll(conversations);
      _status = _conversations.isEmpty
          ? ConversationListStatus.empty
          : ConversationListStatus.ready;
      _errorMessage = '';
    } on NetworkException catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError('Could not load your conversations.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setFilter(int index) {
    _filter = index;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    if (_conversations.isEmpty) _status = ConversationListStatus.error;
  }
}
