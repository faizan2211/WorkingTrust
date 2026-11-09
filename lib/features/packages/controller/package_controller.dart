import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../models/package_entry.dart';
import '../services/package_service.dart';

/// Where one kind of package stands.
enum PackageStatus {
  /// Never asked for.
  idle,

  /// `GET /api/packages` is in flight.
  loading,

  /// Rows arrived.
  ready,

  /// The read succeeded and the server has nothing of that kind listed.
  empty,

  /// The read failed, with [PackageController.error] as the wording.
  error,
}

/// The catalog one screen shows at a time, read from the server.
///
/// Each kind is held apart because the two screens are separate: the Buy Bids
/// sheet asks for `BIDS`, the Membership Plan screen for `MEMBERSHIP`. It reads
/// when a screen opens and when its retry button is pressed. Never on a timer.
class PackageController extends ChangeNotifier {
  PackageController._();

  static final PackageController instance = PackageController._();

  final PackageService _service = PackageService.instance;

  final Map<PackageKind, List<PackageEntry>> _packages = {};
  final Map<PackageKind, PackageStatus> _status = {};
  final Map<PackageKind, String> _errors = {};
  final Set<PackageKind> _inFlight = {};

  List<PackageEntry> packages(PackageKind kind) => _packages[kind] ?? const [];

  PackageStatus statusOf(PackageKind kind) =>
      _status[kind] ?? PackageStatus.idle;

  String errorFor(PackageKind kind) => _errors[kind] ?? '';

  bool isLoading(PackageKind kind) => statusOf(kind) == PackageStatus.loading;

  /// Reads one kind. A kind already on screen is not asked for twice: pass
  /// [force] on a retry, when the answer is expected to have moved.
  Future<void> load(PackageKind kind, {bool force = false}) async {
    if (_inFlight.contains(kind)) return;
    final shown = statusOf(kind);
    if (!force &&
        (shown == PackageStatus.ready || shown == PackageStatus.empty)) {
      return;
    }

    _inFlight.add(kind);
    _status[kind] = PackageStatus.loading;
    _errors[kind] = '';
    notifyListeners();
    try {
      final rows = await _service.fetch(kind);
      _packages[kind] = rows;
      _status[kind] = rows.isEmpty ? PackageStatus.empty : PackageStatus.ready;
    } on NetworkException catch (error) {
      _errors[kind] = error.message;
      _status[kind] = PackageStatus.error;
    } catch (error) {
      _errors[kind] = '$error';
      _status[kind] = PackageStatus.error;
    } finally {
      _inFlight.remove(kind);
      notifyListeners();
    }
  }

  /// An account is leaving the screens it was read for; the next one asks again.
  void clear() {
    _packages.clear();
    _status.clear();
    _errors.clear();
    notifyListeners();
  }
}
