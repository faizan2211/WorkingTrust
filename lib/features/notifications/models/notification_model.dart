/// One row of the backend's `Notification` table, as `GET /api/notifications`
/// returns it. Field names match the Prisma record exactly; the backend has no
/// `isRead` flag — a null `readAt` is what unread means.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type,
    this.href,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;

  /// A machine label such as `BID_AWARDED` or `CHAT_MESSAGE`. The backend
  /// stores this as a plain string, so unknown values must display gracefully.
  final String? type;

  /// Where the web app sends the user, e.g. `/messages?task=abc`. Paths only,
  /// and only the web's own route table — most of them have no Flutter screen.
  final String? href;

  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  bool get hasDestination => href != null && href!.isNotEmpty;

  /// The project whose chat this notification points at, read out of a web href
  /// such as `/messages?task=abc123`. The Messages inbox is loaded separately
  /// from the authorized conversation-list endpoint.
  String? get chatTaskId {
    final link = href;
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.path != '/messages') return null;
    final taskId = uri.queryParameters['task'];
    return (taskId == null || taskId.isEmpty) ? null : taskId;
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString(),
      href: json['href']?.toString(),
      readAt: _date(json['readAt']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
    );
  }

  /// The same notification after the backend accepted `PATCH {id: …}`. Only
  /// `readAt` changes; dismissal removes the row from the list entirely.
  NotificationModel markRead() {
    if (isRead) return this;
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      href: href,
      createdAt: createdAt,
      readAt: DateTime.now(),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
