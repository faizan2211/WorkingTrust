import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import 'read_state.dart';

/// The shape every read-only financial screen shares.
///
/// A controller holds one value read from one route: it reads when its screen
/// opens, when the retry button is pressed and when the list is pulled, and it
/// never reads on a timer. A refresh that fails is a failure, not a stale
/// number — a balance the server did not just confirm is shown as an error with
/// a retry rather than carried on as if it were current.
abstract class ReadController<T> extends ChangeNotifier {
  ReadState _state = ReadState.idle;
  String _error = '';
  bool _expired = false;
  bool _inFlight = false;
  T? _value;

  ReadState get state => _state;

  /// The server's own wording, or the session line when the cookie is gone.
  String get error => _error;

  /// Whether the retry button would help at all: a 401 needs a sign-in, not a
  /// repeat request.
  bool get sessionExpired => _expired;

  /// Whether a read is in flight, so a screen can show its own spinner without
  /// losing what it already displayed.
  bool get isBusy => _inFlight;

  /// The value, or the shape it has when the account holds nothing. Screens
  /// draw it for [ReadState.ready] and [ReadState.empty]; a [ReadState.failed]
  /// read shows the error card instead.
  T get value => _value ?? emptyValue();

  bool get hasValue => _value != null;

  /// The value a read produces when the account has nothing.
  T emptyValue();

  /// True when [value] should be shown as the empty state rather than a list.
  bool isEmptyValue(T value);

  /// One request to the route this controller owns.
  Future<T> read();

  /// Reads for the screen that just opened. A value already on screen is not
  /// asked for twice unless [force] is set, which is what a pull-to-refresh and
  /// a retry both do.
  Future<void> load({bool force = false}) async {
    if (_inFlight) return;
    if (!force && (_state == ReadState.ready || _state == ReadState.empty)) {
      return;
    }
    if (!SessionStore.instance.hasSessionCookie) {
      _fail(SessionExpiry.message, expired: true);
      return;
    }
    _inFlight = true;
    _error = '';
    _expired = false;
    if (_value == null) _state = ReadState.loading;
    notifyListeners();
    try {
      final next = await read();
      _value = next;
      _state = isEmptyValue(next) ? ReadState.empty : ReadState.ready;
    } on NetworkException catch (e) {
      _fail(
        SessionExpiry.isExpired(e.statusCode)
            ? SessionExpiry.message
            : e.message,
        expired: SessionExpiry.isExpired(e.statusCode),
      );
    } catch (e) {
      _fail('$e', expired: false);
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh, and the refresh a screen asks for after the server has
  /// confirmed an action that could move these figures.
  Future<void> refresh() => load(force: true);

  /// Drop everything this account read: the next screen asks again.
  void clear() {
    _value = null;
    _state = ReadState.idle;
    _error = '';
    _expired = false;
    notifyListeners();
  }

  void _fail(String message, {required bool expired}) {
    _error = message;
    _expired = expired;
    _value = null;
    _state = ReadState.failed;
  }
}
