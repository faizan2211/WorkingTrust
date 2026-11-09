import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../models/weekly_report.dart';
import '../services/reports_service.dart';
import 'read_state.dart';

/// The two weekly reports, read when a card is opened.
///
/// The freelancer summary needs only a session. The client breakdown is the
/// Pro-only half of the same route, and a 403 from it is kept apart from an
/// ordinary failure as [WeeklyController.isLocked] so the card can say what it
/// actually is — an upgrade prompt, not a retry. The download is the website's
/// own text file: the device shows what the server wrote, never a summary it
/// built itself.
class WeeklyController extends ChangeNotifier {
  WeeklyController._();

  static final WeeklyController instance = WeeklyController._();

  final ReportsService _service = ReportsService.instance;

  final Map<WeeklyScope, WeeklyReport> _reports = {};
  final Map<WeeklyScope, ReadState> _states = {};
  final Map<WeeklyScope, String> _errors = {};
  final Set<WeeklyScope> _locked = {};
  final Set<WeeklyScope> _inFlight = {};
  bool _downloading = false;
  String _downloadError = '';

  ReadState stateOf(WeeklyScope scope) => _states[scope] ?? ReadState.idle;
  String errorFor(WeeklyScope scope) => _errors[scope] ?? '';
  bool isLocked(WeeklyScope scope) => _locked.contains(scope);
  WeeklyReport? reportFor(WeeklyScope scope) => _reports[scope];
  bool isLoading(WeeklyScope scope) =>
      _inFlight.contains(scope) || stateOf(scope) == ReadState.loading;
  bool get isDownloading => _downloading;
  String get downloadError => _downloadError;

  Future<void> load(WeeklyScope scope, {bool force = false}) async {
    if (_inFlight.contains(scope)) return;
    if (!SessionStore.instance.hasSessionCookie) {
      _fail(scope, SessionExpiry.message, expired: true);
      return;
    }
    _inFlight.add(scope);
    _states[scope] = ReadState.loading;
    _errors[scope] = '';
    _locked.remove(scope);
    notifyListeners();
    try {
      final report = await _service.fetchWeekly(scope);
      _reports[scope] = report;
      _states[scope] = ReadState.ready;
    } on WeeklyLocked catch (e) {
      _locked.add(scope);
      _errors[scope] = e.message;
      _states[scope] = ReadState.empty;
    } on NetworkException catch (e) {
      _fail(
        scope,
        SessionExpiry.isExpired(e.statusCode)
            ? SessionExpiry.message
            : e.message,
        expired: SessionExpiry.isExpired(e.statusCode),
      );
    } catch (e) {
      _fail(scope, '$e', expired: false);
    } finally {
      _inFlight.remove(scope);
      notifyListeners();
    }
  }

  /// The report as the server's text file. The screen shows it rather than
  /// claiming a download it cannot complete, because a device has no file to
  /// hand back to the user.
  Future<String?> download(WeeklyScope scope) async {
    if (_downloading) return null;
    if (!SessionStore.instance.hasSessionCookie) {
      _downloadError = SessionExpiry.message;
      notifyListeners();
      return null;
    }
    _downloading = true;
    _downloadError = '';
    notifyListeners();
    try {
      return await _service.fetchWeeklyText(scope);
    } on WeeklyLocked catch (e) {
      _locked.add(scope);
      _downloadError = e.message;
    } on NetworkException catch (e) {
      _downloadError = SessionExpiry.isExpired(e.statusCode)
          ? SessionExpiry.message
          : e.message;
    } catch (e) {
      _downloadError = '$e';
    } finally {
      _downloading = false;
      notifyListeners();
    }
    return null;
  }

  void clear() {
    _reports.clear();
    _states.clear();
    _errors.clear();
    _locked.clear();
    _inFlight.clear();
    _downloadError = '';
    notifyListeners();
  }

  void _fail(WeeklyScope scope, String message, {required bool expired}) {
    _errors[scope] = message;
    _states[scope] = ReadState.failed;
    if (expired) _locked.remove(scope);
  }
}
