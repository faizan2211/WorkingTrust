import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/notification_model.dart';

/// One `GET /api/notifications` answer, kept together because the backend
/// counts unread itself: `{"notifications": [...], "unread": 0}`.
class NotificationFeed {
  const NotificationFeed({required this.notifications, required this.unread});

  final List<NotificationModel> notifications;
  final int unread;
}

/// Reads and mutates the notifications the backend has already created.
///
/// There is deliberately no create call here: rows come from real events on
/// the server (bids, submissions, withdrawals, admin actions), never from a
/// client.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final ApiClient _apiClient = ApiClient();

  /// Authenticated by the NextAuth session cookie the shared [ApiClient]
  /// attaches, not by a bearer token.
  Future<NotificationFeed> fetch() async {
    final response = await _apiClient.get(ApiEndpoints.notifications);
    if (response is! Map) {
      throw NetworkException('The server did not return your notifications.');
    }
    final data = Map<String, dynamic>.from(response);
    final rows = data['notifications'];
    return NotificationFeed(
      notifications: rows is List
          ? [
              for (final row in rows)
                if (row is Map)
                  NotificationModel.fromJson(Map<String, dynamic>.from(row)),
            ]
          : const [],
      // The count is advisory: a missing or odd value just means no badge.
      unread: switch (data['unread']) {
        final int value => value < 0 ? 0 : value,
        final String value => int.tryParse(value) ?? 0,
        _ => 0,
      },
    );
  }

  Future<void> markRead(String id) => _patch({'id': id});

  Future<void> dismiss(String id) => _patch({'id': id, 'dismiss': true});

  Future<void> markAllRead() => _patch({'all': true});

  /// Reads a project's conversation on the web's terms: the backend marks the
  /// `CHAT_MESSAGE` rows whose href names that task, and that is the only
  /// read state a chat has. There is no per-message receipt.
  Future<void> markTaskChatRead(String taskId) => _patch({'taskId': taskId});

  Future<void> _patch(Map<String, dynamic> body) async {
    await _apiClient.patch(ApiEndpoints.notifications, body: body);
  }
}
