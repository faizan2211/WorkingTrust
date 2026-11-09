/// One authorized task conversation returned by `GET /api/conversations`.
class ProjectConversation {
  const ProjectConversation({
    required this.taskId,
    required this.name,
    required this.preview,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.closed,
    required this.flagged,
  });

  final String taskId;
  final String name;
  final String preview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool closed;
  final bool flagged;

  bool get unread => unreadCount > 0;

  factory ProjectConversation.fromJson(Map<dynamic, dynamic> json) {
    final taskId = _text(json['taskId']);
    if (taskId == null) {
      throw const FormatException('Conversation is missing its task id.');
    }

    return ProjectConversation(
      taskId: taskId,
      name: _text(json['name']) ?? 'WorkingTrust',
      preview: _text(json['preview']) ?? 'No messages yet',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      unreadCount: switch (json['unreadCount']) {
        final int value => value < 0 ? 0 : value,
        final String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
      closed: json['closed'] == true,
      flagged: json['flagged'] == true,
    );
  }
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
