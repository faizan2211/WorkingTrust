import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/project_model.dart';

/// What a submitted proposal costs, as the server's own `Bid` row reports it.
typedef BidReceipt = ({String id, int connectsSpent});

/// The three Find Work routes the backend actually serves.
///
/// Everything else the board used to show — a project fetched by id, saved
/// projects, this account's own bids — has no route, so it has no method here.
class FindWorkService {
  FindWorkService._();

  static final FindWorkService instance = FindWorkService._();

  final ApiClient _apiClient = ApiClient();

  /// `bidSchema`'s ceilings, applied before the request so a proposal that
  /// cannot be stored never leaves the device.
  static const int proposalMin = 20;
  static const int proposalMax = 3000;
  static const double amountMin = 5;
  static const double amountMax = 10000;
  static const int attachmentMax = 5;
  static const int portfolioMax = 3;

  /// `GET /api/tasks` — every open project, newest first, optionally narrowed
  /// to one category slug and one keyword. The server matches [query] against
  /// the title, description, requirements, deliverables, client name and
  /// category name.
  Future<List<ProjectModel>> tasks({
    String query = '',
    String categorySlug = '',
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.tasks,
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (categorySlug.isNotEmpty) 'category': categorySlug,
      },
    );
    final rows = response is Map ? response['tasks'] : null;
    if (rows is! List) {
      throw NetworkException('The server did not return any projects.');
    }
    return [
      for (final row in rows)
        if (row is Map) ProjectModel.fromJson(row),
    ];
  }

  /// `GET /api/categories` — the board's filter list. It carries no task
  /// counts, because the route does not send any.
  Future<List<CategoryModel>> categories() async {
    final response = await _apiClient.get(ApiEndpoints.categories);
    final rows = response is Map ? response['categories'] : null;
    if (rows is! List) {
      throw NetworkException('The server did not return any categories.');
    }
    return [
      for (final row in rows)
        if (row is Map) CategoryModel.fromJson(row),
    ];
  }

  /// `POST /api/tasks/{id}/bid`. The bid is only listed as sent once this
  /// answers 201 with the row the server stored.
  Future<BidReceipt> bid({
    required String taskId,
    required String proposal,
    double? bidAmount,
    List<String> attachmentUrls = const [],
    List<String> portfolioItemIds = const [],
  }) async {
    final text = proposal.trim();
    if (text.length < proposalMin) {
      throw NetworkException(
        'Write a clear proposal (min $proposalMin characters).',
      );
    }
    if (text.length > proposalMax) {
      throw NetworkException(
        'A proposal can be up to $proposalMax characters.',
      );
    }
    if (bidAmount != null && (bidAmount < amountMin || bidAmount > amountMax)) {
      throw NetworkException(
        'The bid rate must be between \$${amountMin.toInt()} and '
        '\$${amountMax.toInt()}.',
      );
    }
    if (attachmentUrls.length > attachmentMax) {
      throw NetworkException(
        'A proposal can carry up to $attachmentMax files.',
      );
    }
    if (portfolioItemIds.length > portfolioMax) {
      throw NetworkException(
        'A proposal can highlight up to $portfolioMax projects.',
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.taskBid(taskId),
      body: <String, dynamic>{
        'proposal': text,
        // The route turns an absent or empty amount into a null bidAmount, so
        // nothing is sent when the freelancer left the rate out.
        'bidAmount': ?bidAmount,
        'attachmentUrls': attachmentUrls.isEmpty ? null : attachmentUrls,
        'portfolioItemIds': portfolioItemIds.isEmpty ? null : portfolioItemIds,
      },
    );
    final row = response is Map ? response['bid'] : null;
    if (row is! Map) {
      throw NetworkException('The server did not confirm your proposal.');
    }
    final spent = row['connectsSpent'];
    return (
      id: row['id']?.toString() ?? '',
      connectsSpent: spent is num ? spent.round() : 0,
    );
  }

  /// Uploads one proposal file through the backend's general upload route and
  /// answers with the URL the bid request stores.
  Future<String> uploadAttachment({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final response = await _apiClient.postFile(
      ApiEndpoints.upload,
      field: 'file',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
    if (!response.isSuccess) {
      throw NetworkException(response.message, statusCode: response.statusCode);
    }
    final url = response.json?['url'];
    if (url is! String || url.isEmpty) {
      throw NetworkException('The server did not store that file.');
    }
    return url;
  }
}
