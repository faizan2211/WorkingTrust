import 'package:flutter/material.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

enum NotificationStatus { idle, loading, ready, empty, error }

/// The signed-in user's notifications, shared between the shell's bell and the
/// Notifications screen.
///
/// FCM is only a delivery signal: the database remains the source of truth.
/// The feed reads when the shell opens, when the app resumes, when a push
/// arrives, when the feed screen opens, and on pull-to-refresh — never on a
/// timer, so a session left open on screen produces no polling traffic.
class NotificationController extends ChangeNotifier {
  NotificationController._();

  static final NotificationController instance = NotificationController._();

  static const String sessionExpired =
      'Your session has expired. Please log in again.';

  final NotificationService _service = NotificationService.instance;

  final List<NotificationModel> _notifications = [];
  bool _sessionActive = false;
  bool _paused = false;
  bool _fetching = false;
  bool _mutating = false;
  NotificationStatus _status = NotificationStatus.idle;
  String _errorMessage = '';
  int _unread = 0;

  NotificationStatus get status => _status;
  String get errorMessage => _errorMessage;
  int get unread => _unread;
  bool get hasUnread => _unread > 0;
  bool get isLoading => _status == NotificationStatus.loading;
  bool get isRefreshing => _fetching;
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  /// Called when a session becomes available: loads at once, and from then on
  /// only reloads when the app is resumed.
  void startSession() {
    if (!_signedIn) return;
    _sessionActive = true;
    _paused = false;
    refresh();
  }

  /// Called when the session goes away. Drops every notification body, which is
  /// never written to disk.
  void endSession() {
    _sessionActive = false;
    _paused = false;
    _notifications.clear();
    _unread = 0;
    _status = NotificationStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }

  /// Reloads when the app comes back to the foreground, so the user sees what
  /// arrived while they were away. Nothing is read while it is backgrounded.
  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_sessionActive || !_paused) return;
      _paused = false;
      refresh();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _paused = true;
    }
  }

  /// The backend recognises this device only through its NextAuth cookie, so
  /// asking without one is a guaranteed 401 and pointless traffic.
  bool get _signedIn => SessionStore.instance.hasSessionCookie;

  /// [silent] keeps the current list on screen while it re-reads, which is what
  /// a resume and a pull-to-refresh want; only a cold first load shows a
  /// spinner.
  Future<void> refresh({bool silent = false}) async {
    if (_fetching) return;
    if (!_signedIn) {
      endSession();
      return;
    }
    _fetching = true;
    final cold = _notifications.isEmpty && _status != NotificationStatus.error;
    if (!silent && cold) {
      _status = NotificationStatus.loading;
      notifyListeners();
    }
    try {
      final feed = await _service.fetch();
      _notifications
        ..clear()
        ..addAll(feed.notifications);
      _unread = feed.unread;
      _status = _notifications.isEmpty
          ? NotificationStatus.empty
          : NotificationStatus.ready;
      _errorMessage = '';
    } on NetworkException catch (e) {
      _failFetch(e.message, expired: e.statusCode == 401);
    } catch (e) {
      _failFetch(e.toString(), expired: false);
    } finally {
      _fetching = false;
      notifyListeners();
    }
  }

  /// Marks one read, then updates the row the backend agreed about.
  Future<bool> markRead(String id) {
    return _mutate(() => _service.markRead(id), () {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index == -1) return false;
      if (!_notifications[index].isRead) {
        _notifications[index] = _notifications[index].markRead();
        _unread = _unread > 0 ? _unread - 1 : 0;
      }
      return true;
    });
  }

  /// Dismisses one row (`PATCH` with `dismiss: true` — there is no DELETE).
  Future<bool> dismiss(String id) {
    return _mutate(() => _service.dismiss(id), () {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index == -1) return false;
      final wasUnread = !_notifications[index].isRead;
      _notifications.removeAt(index);
      if (wasUnread && _unread > 0) _unread--;
      if (_notifications.isEmpty) _status = NotificationStatus.empty;
      return true;
    });
  }

  Future<bool> markAllRead() {
    return _mutate(_service.markAllRead, () {
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].markRead();
      }
      _unread = 0;
      return true;
    });
  }

  /// A tap opens nothing on its own: most backend `href`s are web-only paths
  /// this app has no screen for. Reading it is still the honest response, and
  /// the next re-read of the feed re-syncs from the server either way.
  Future<bool> openNotification(NotificationModel notification) {
    if (notification.isRead) return Future.value(true);
    return markRead(notification.id);
  }

  Future<bool> _mutate(
    Future<void> Function() action,
    bool Function() applyLocally,
  ) async {
    if (_mutating) return false;
    _mutating = true;
    var changed = false;
    try {
      await action();
      changed = applyLocally();
      _errorMessage = '';
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        // Signed out mid-tap: forget the feed first, then say why the row did
        // not change. endSession() clears the message, so it goes after.
        endSession();
        _errorMessage = sessionExpired;
      } else {
        _errorMessage = e.message;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _mutating = false;
      if (changed || _errorMessage.isNotEmpty) notifyListeners();
    }
    return changed;
  }

  void _failFetch(String message, {required bool expired}) {
    // An expired session is not retried: the device is signed out, so stop
    // asking and forget the list rather than showing someone else's rows.
    if (expired) {
      endSession();
      _errorMessage = sessionExpired;
      return;
    }
    _errorMessage = message;
    // Whatever was on screen stays there; a failed refresh must not blank it.
    if (_notifications.isEmpty) _status = NotificationStatus.error;
  }

  @override
  void dispose() {
    _sessionActive = false;
    super.dispose();
  }
}
