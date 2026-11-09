import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/project_conversation.dart';
import '../models/project_chat.dart';

/// The two chat routes the backend actually serves, with no invented extras.
class ProjectChatService {
  ProjectChatService._();

  static final ProjectChatService instance = ProjectChatService._();

  final ApiClient _apiClient = ApiClient();

  Future<List<ProjectConversation>> loadConversations() async {
    final response = await _apiClient.get(ApiEndpoints.conversations);
    final rows = response is Map ? response['conversations'] : null;
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw NetworkException('The server did not return your conversations.');
    }
    try {
      return [for (final row in rows) ProjectConversation.fromJson(row as Map)];
    } on FormatException {
      throw NetworkException('The server returned an invalid conversation.');
    }
  }

  /// `chatSchema`'s own ceilings, applied before the request so a message that
  /// cannot be stored never leaves the device.
  static const int bodyLimit = 2000;
  static const int attachmentLimit = 500;

  /// The whole thread, oldest message first.
  Future<Chat> load(String taskId) async {
    final response = await _apiClient.get(ApiEndpoints.taskChat(taskId));
    if (response is! Map) {
      throw NetworkException('The server did not return this conversation.');
    }
    return Chat.fromJson(response);
  }

  /// Posts one message and answers with the row the server stored, which is the
  /// only copy the app ever shows as sent.
  Future<ChatMessage> send(
    String taskId, {
    required String body,
    String? attachmentUrl,
  }) async {
    final text = body.trim();
    final file = attachmentUrl?.trim() ?? '';
    if (text.isEmpty && file.isEmpty) {
      throw NetworkException('Write a message or attach a file.');
    }
    if (text.length > bodyLimit) {
      throw NetworkException('A message can be up to $bodyLimit characters.');
    }
    if (file.length > attachmentLimit) {
      throw NetworkException('That attachment link is too long.');
    }

    final response = await _apiClient.post(
      ApiEndpoints.taskChat(taskId),
      body: <String, dynamic>{
        'body': text,
        // The route reads a string or nothing; an empty one is not an
        // attachment.
        'attachmentUrl': file.isEmpty ? null : file,
      },
    );
    final row = response is Map ? response['message'] : null;
    if (row is! Map) {
      throw NetworkException('The server did not confirm your message.');
    }
    return ChatMessage.fromJson(row);
  }
}
