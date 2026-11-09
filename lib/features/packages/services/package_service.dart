import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../models/package_entry.dart';

/// The `Package` rows the Buy Bids sheet and the Membership Plan screen list.
///
/// One route serves them all: `GET /api/packages?kind=`, which reads the same
/// table the Admin Panel edits and answers with the rows' own ids. Nothing here
/// is seeded — a pack added, repriced, reordered or deactivated in the panel is
/// on the next read, with no change to the app.
class PackageService {
  PackageService._();

  static final PackageService instance = PackageService._();

  final ApiClient _apiClient = ApiClient();

  /// Active packages of one kind. The server filters by `kind`, hides anything
  /// deactivated, and orders by `sortOrder`, so that order is kept as it
  /// arrived.
  Future<List<PackageEntry>> fetch(PackageKind kind) async {
    final response = await _apiClient.get(
      ApiEndpoints.packages,
      queryParameters: {'kind': kind.column},
    );
    final rows = response is Map ? response['packages'] : null;
    if (rows is! List) {
      throw NetworkException('The server did not return any packages.');
    }
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) packageFromJson(row),
    ];
  }
}
