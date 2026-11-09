import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../models/transaction_feed.dart';
import '../services/reports_service.dart';
import 'read_state.dart';

/// The transactions feed, one server page at a time.
///
/// The route owns the merge, the ordering, the filtering and the paging, so the
/// controller keeps the pages it has read in the order they arrived. `type` and
/// `client` are sent to the server, and changing either starts again at page
/// one rather than filtering what is already on screen.
class TransactionsController extends ChangeNotifier {
  TransactionsController._();

  static final TransactionsController instance = TransactionsController._();

  /// The rows the app asks for per page; the route clamps anything larger.
  static const int pageSize = 20;

  static const String allClients = 'All Clients';

  final ReportsService _service = ReportsService.instance;

  ReadState _state = ReadState.idle;
  String _error = '';
  bool _expired = false;
  bool _inFlight = false;
  bool _loadingMore = false;

  TransactionFilter _type = TransactionFilter.all;
  String _client = 'all';

  List<TransactionRow> _rows = const [];
  List<String> _clients = const [];
  double? _availableBalance;
  double? _pendingEarnings;
  bool _hasPaymentMethod = false;
  int _total = 0;
  int _page = 0;
  int _totalPages = 1;

  ReadState get state => _state;
  String get error => _error;
  bool get sessionExpired => _expired;
  bool get isLoading => _state == ReadState.loading;
  bool get isLoadingMore => _loadingMore;
  bool get isBusy => _inFlight || _loadingMore;

  List<TransactionRow> get rows => _rows;
  List<String> get clients => _clients;
  double? get availableBalance => _availableBalance;
  double? get pendingEarnings => _pendingEarnings;
  bool get hasPaymentMethod => _hasPaymentMethod;
  int get total => _total;
  bool get hasMore => _page < _totalPages;
  TransactionFilter get type => _type;
  String get client => _client;

  /// The dropdown the screen shows: the server's names, with "all" first.
  List<String> get clientOptions => [allClients, ..._clients];

  Future<void> load({bool force = false}) async {
    if (_inFlight) return;
    if (!force && (_state == ReadState.ready || _state == ReadState.empty)) {
      return;
    }
    if (!SessionStore.instance.hasSessionCookie) {
      _fail(SessionExpiry.message, true);
      return;
    }
    _inFlight = true;
    _error = '';
    _expired = false;
    if (_rows.isEmpty) _state = ReadState.loading;
    notifyListeners();
    try {
      final feed = await _service.fetchTransactions(
        page: 1,
        limit: pageSize,
        type: _type,
        client: _client,
      );
      _rows = feed.rows;
      _page = feed.rows.isEmpty ? 0 : 1;
      _apply(feed);
    } on NetworkException catch (e) {
      _fail(
        SessionExpiry.isExpired(e.statusCode)
            ? SessionExpiry.message
            : e.message,
        SessionExpiry.isExpired(e.statusCode),
      );
    } catch (e) {
      _fail('$e', false);
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  /// The next page, appended to what is already on screen.
  Future<void> loadMore() async {
    if (_inFlight || _loadingMore || !hasMore) return;
    if (!SessionStore.instance.hasSessionCookie) {
      _error = SessionExpiry.message;
      _expired = true;
      notifyListeners();
      return;
    }
    _loadingMore = true;
    _error = '';
    notifyListeners();
    try {
      final feed = await _service.fetchTransactions(
        page: _page + 1,
        limit: pageSize,
        type: _type,
        client: _client,
      );
      _apply(feed);
      // A route that has run out of rows answers with the first page again, so
      // the cursor only moves when new rows actually came.
      if (feed.rows.isNotEmpty && feed.page > _page) {
        _rows = [..._rows, ...feed.rows];
        _page = feed.page;
      } else {
        _totalPages = _page;
      }
    } on NetworkException catch (e) {
      _error = SessionExpiry.isExpired(e.statusCode)
          ? SessionExpiry.message
          : e.message;
      _expired = SessionExpiry.isExpired(e.statusCode);
    } catch (e) {
      _error = '$e';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> setType(TransactionFilter type) async {
    if (type == _type) return;
    _type = type;
    _rows = const [];
    await load(force: true);
  }

  /// [name] is the label on screen; the server takes the bare name or its own
  /// `all` for the first entry.
  Future<void> setClient(String name) async {
    final value = name == allClients ? 'all' : name;
    if (value == _client) return;
    _client = value;
    _rows = const [];
    await load(force: true);
  }

  void clear() {
    _rows = const [];
    _clients = const [];
    _availableBalance = null;
    _pendingEarnings = null;
    _hasPaymentMethod = false;
    _total = 0;
    _page = 0;
    _totalPages = 1;
    _type = TransactionFilter.all;
    _client = 'all';
    _state = ReadState.idle;
    _error = '';
    _expired = false;
    notifyListeners();
  }

  void _apply(TransactionFeed feed) {
    _availableBalance = feed.availableBalance;
    _pendingEarnings = feed.pendingEarnings;
    _hasPaymentMethod = feed.hasPaymentMethod;
    _clients = feed.clients;
    _total = feed.total;
    _totalPages = feed.totalPages;
    _state = feed.total == 0 ? ReadState.empty : ReadState.ready;
  }

  void _fail(String message, bool expired) {
    _error = message;
    _expired = expired;
    _rows = const [];
    _state = ReadState.failed;
  }
}
