/// The shape of one project chat, as `GET /api/tasks/<id>/chat` answers it.
///
/// There is no conversation list, no single-message fetch and no edit or delete
/// route: a thread is replaced whole by whatever the server says, and a send
/// answers with exactly the one row it stored.
library;

/// One stored message, already labelled by the backend.
///
/// [displayName] is the server's own answer for who wrote it *from this
/// account's point of view* — `You`, the client's name, or a staff member's
/// name — because a task's client is a name kept on the task, not a login.
/// [fromClient] marks the rows written by the client side, which can only ever
/// be an admin account.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    this.attachmentUrl,
    required this.createdAt,
    required this.senderId,
    required this.displayName,
    required this.fromClient,
  });

  final String id;
  final String body;
  final String? attachmentUrl;
  final DateTime createdAt;
  final String senderId;
  final String displayName;
  final bool fromClient;

  /// Every field is read defensively: the route is shared with the web, and a
  /// row that stops carrying one key must not stop the thread from opening.
  factory ChatMessage.fromJson(Map<dynamic, dynamic> json) => ChatMessage(
    id: _text(json['id']) ?? '',
    body: _text(json['body']) ?? '',
    attachmentUrl: _text(json['attachmentUrl']),
    // A row with no readable time still belongs in the list; it groups with the
    // moment it was read rather than being dropped.
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    senderId: _text(json['senderId']) ?? '',
    displayName: _text(json['displayName']) ?? 'WorkingTrust',
    fromClient: json['isClientSide'] == true,
  );
}

/// A thread: the two participants, the flags that decide whether it can still
/// receive messages, and its messages oldest first.
class Chat {
  const Chat({
    required this.projectTitle,
    required this.clientName,
    this.clientAvatarUrl,
    this.freelancerName,
    this.freelancerAvatarUrl,
    this.flagged = false,
    this.closed = false,
    required this.messages,
  });

  final String projectTitle;
  final String clientName;
  final String? clientAvatarUrl;
  final String? freelancerName;
  final String? freelancerAvatarUrl;
  final bool flagged;
  final bool closed;

  /// The order the backend sent, kept as it arrived.
  final List<ChatMessage> messages;

  factory Chat.fromJson(Map<dynamic, dynamic> json) {
    final rows = json['messages'];
    return Chat(
      projectTitle: _text(json['projectTitle']) ?? 'Project chat',
      clientName: _text(json['clientName']) ?? 'Client',
      clientAvatarUrl: _text(json['clientAvatarUrl']),
      freelancerName: _text(json['freelancerName']),
      freelancerAvatarUrl: _text(json['freelancerAvatarUrl']),
      flagged: json['flagged'] == true,
      closed: json['closed'] == true,
      messages: [
        if (rows is List)
          for (final row in rows)
            if (row is Map) ChatMessage.fromJson(row),
      ],
    );
  }
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
