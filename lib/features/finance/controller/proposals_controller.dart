import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../models/my_proposals.dart';
import '../services/proposals_service.dart';
import 'read_state.dart';

/// The proposals this account sent, one server page at a time.
///
/// The bids list is paged because the route pages it; `activeWork` and `counts`
/// come back whole with every answer, so a tab header shows the real number of
/// bids in each status rather than the count of the page currently open.
class ProposalsController extends ChangeNotifier {
  ProposalsController._();

  static final ProposalsController instance = ProposalsController._();

  static const int pageSize = 20;

  final ProposalsService _service = ProposalsService.instance;

  ReadState _state = ReadState.idle;
  String _error = '';
  bool _expired = false;
  bool _inFlight = false;
  bool _loadingMore = false;

  BidStatus _status = BidStatus.all;
  List<ProposalRow> _proposals = const [];
  List<ActiveWorkRow> _activeWork = const [];
  BidCounts _counts = (pending: 0, shortlisted: 0, awarded: 0, rejected: 0);
  int _total = 0;
  int _page = 0;
  int _totalPages = 1;

  ReadState get state => _state;
  String get error => _error;
  bool get sessionExpired => _expired;
  bool get isLoading => _state == ReadState.loading;
  bool get isLoadingMore => _loadingMore;
  bool get isBusy => _inFlight || _loadingMore;

  List<ProposalRow> get proposals => _proposals;
  List<ActiveWorkRow> get activeWork => _activeWork;
  BidCounts get counts => _counts;
  int get total => _total;

  /// A next page exists only once a page is actually on screen: an account with
  /// no bids has nothing to append.
  bool get hasMore => _page > 0 && _page < _totalPages;
  BidStatus get status => _status;

  /// The bids in the status the screen has open; `all` is every bid sent.
  List<ProposalRow> get visible => _proposals;

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
    if (_proposals.isEmpty) _state = ReadState.loading;
    notifyListeners();
    try {
      final feed = await _service.fetch(
        page: 1,
        limit: pageSize,
        status: _status,
      );
      _proposals = feed.proposals;
      _page = feed.proposals.isEmpty ? 0 : 1;
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
      final feed = await _service.fetch(
        page: _page + 1,
        limit: pageSize,
        status: _status,
      );
      _apply(feed);
      if (feed.proposals.isNotEmpty && feed.page > _page) {
        _proposals = [..._proposals, ...feed.proposals];
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

  Future<void> setStatus(BidStatus status) async {
    if (status == _status) return;
    _status = status;
    _proposals = const [];
    await load(force: true);
  }

  void clear() {
    _proposals = const [];
    _activeWork = const [];
    _counts = (pending: 0, shortlisted: 0, awarded: 0, rejected: 0);
    _total = 0;
    _page = 0;
    _totalPages = 1;
    _status = BidStatus.all;
    _state = ReadState.idle;
    _error = '';
    _expired = false;
    notifyListeners();
  }

  void _apply(ProposalFeed feed) {
    _activeWork = feed.activeWork;
    _counts = feed.counts;
    _total = feed.total;
    _totalPages = feed.totalPages;
    _state = feed.total == 0 && feed.activeWork.isEmpty
        ? ReadState.empty
        : ReadState.ready;
  }

  void _fail(String message, bool expired) {
    _error = message;
    _expired = expired;
    _proposals = const [];
    _activeWork = const [];
    _state = ReadState.failed;
  }
}
