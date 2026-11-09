import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../../finance/controller/proposals_controller.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../models/project_model.dart';
import '../services/find_work_service.dart';
import '../services/proposal_attachment_service.dart';

enum FindWorkStatus { idle, loading, ready, empty, error }

/// Whether a proposal reached the backend, in the backend's own words.
typedef BidOutcome = ({bool sent, String message, int spent});

/// The Find Work board, read from `GET /api/tasks`.
///
/// The board is one request: the route has no pagination, so every open
/// project arrives at once and the keyword and category filters are the
/// server's own query parameters. What is left to do on the device is the
/// ordering and the two switches the route does not offer — experience level,
/// payment verification, and the saved list.
///
/// It reads on the first open, on pull-to-refresh, when the app comes back to
/// the foreground, and after a proposal is accepted. Never on a timer.
class FindWorkController extends ChangeNotifier {
  FindWorkController._();

  /// One board for the app: the proposal form has to mark the project it
  /// applied on and reload the list the card came from.
  static final FindWorkController instance = FindWorkController._();

  static const List<String> tabs = ['Most Recent', 'Best Matches', 'Save Jobs'];

  /// `Task.difficulty`, in the backend's own three tokens.
  static const List<String> levelOptions = ['Small', 'Medium', 'Large'];

  /// How long typing pauses before a keyword search is sent, so a whole word
  /// does not cost one request per letter.
  static const Duration searchDelay = Duration(milliseconds: 400);

  final FindWorkService _service = FindWorkService.instance;

  final List<ProjectModel> _projects = [];
  final List<CategoryModel> _categories = [];
  final Set<String> _levels = {};

  /// Bookmarks and applications are device state: the backend serves no saved
  /// list and no list of this account's bids, so these two sets are what let
  /// the flags survive a reload of the board.
  final Set<String> _savedIds = {};
  final Set<String> _appliedIds = {};

  Timer? _debounce;
  bool _fetching = false;
  bool _stale = false;
  bool _categoriesRequested = false;
  bool _loadingCategories = false;
  String _loadedKey = '';
  String _query = '';
  String _categorySlug = '';
  int _tab = 0;
  bool _verifiedOnly = false;
  FindWorkStatus _status = FindWorkStatus.idle;
  String _errorMessage = '';

  /// Bumped by [clear]. A read that belongs to an account the device has
  /// already left must not write its projects into the next one's board, and
  /// must not hand its busy flag over to the read that replaced it.
  int _generation = 0;

  FindWorkStatus get status => _status;
  String get errorMessage => _errorMessage;
  int get tab => _tab;
  String get query => _query;
  Set<String> get levels => _levels;
  bool get verifiedOnly => _verifiedOnly;
  bool get isLoading => _status == FindWorkStatus.loading;
  bool get isRefreshing => _fetching;
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get loadingCategories => _loadingCategories;
  String get categorySlug => _categorySlug;

  bool get hasFilters =>
      _levels.isNotEmpty || _verifiedOnly || _categorySlug.isNotEmpty;

  /// The selected category, or null for the whole board.
  CategoryModel? get category {
    for (final item in _categories) {
      if (item.slug == _categorySlug) return item;
    }
    return null;
  }

  int get savedCount => _savedIds.length;

  /// The projects on screen, after the device-side switches. The server's own
  /// newest-first order is kept.
  List<ProjectModel> get results {
    final matches = _projects.where(_visible).toList();
    return _tab == 1 ? _ranked(matches) : matches;
  }

  bool _visible(ProjectModel project) {
    if (_levels.isNotEmpty && !_levels.contains(project.level)) return false;
    if (_verifiedOnly && !project.paymentVerified) return false;
    if (_tab == 2 && !project.saved) return false;
    return true;
  }

  /// Words from the account's job title, which is what the web's "Matches"
  /// tab compares against. The board already carries the whole open set, so
  /// this comparison runs on the device instead of a second endpoint.
  List<String> get _titleWords {
    final title = ProfileController.instance.title.trim().toLowerCase();
    if (title.isEmpty) return const [];
    return title
        .split(RegExp(r'[\s,/-]+'))
        .where((word) => word.length >= 3)
        .toList();
  }

  bool get _hasTitle => _titleWords.isNotEmpty;

  /// The honest empty-state line for the tab that is on screen.
  String get emptyMessage {
    if (_tab == 1) {
      return _hasTitle
          ? 'No open project matches your profile title.'
          : 'Add your job title in your profile to rank matches.';
    }
    if (_tab == 2) return 'No saved projects yet.';
    if (_query.trim().isNotEmpty || _categorySlug.isNotEmpty) {
      return 'No open project matches this search.';
    }
    return 'No open projects right now.';
  }

  /// Scores each project once. The board can hold every open project at once,
  /// so comparing two of them must not rebuild their text a third time.
  List<ProjectModel> _ranked(List<ProjectModel> projects) {
    final words = _titleWords;
    final scored = <({int hits, ProjectModel project})>[];
    for (final project in projects) {
      final haystack =
          '${project.title} ${project.category} ${project.description}'
              .toLowerCase();
      var hits = 0;
      for (final word in words) {
        if (haystack.contains(word)) hits++;
      }
      if (hits > 0) scored.add((hits: hits, project: project));
    }
    scored.sort((a, b) => b.hits.compareTo(a.hits));
    return [for (final row in scored) row.project];
  }

  /// The keyword, category and order the projects on screen were fetched with.
  String get _key => '${_query.trim().toLowerCase()}|$_categorySlug';

  /// Reads the board. A request already in flight is noted instead of stacked:
  /// when it lands, one more read is made if the filters moved underneath it,
  /// so the fastest typist still ends up with the list for their last word.
  Future<void> load({bool force = false}) async {
    final key = _key;
    if (_fetching) {
      if (key != _loadedKey) _stale = true;
      return;
    }
    if (!force && key == _loadedKey && _status != FindWorkStatus.error) return;

    final generation = _generation;
    _fetching = true;
    if (_projects.isEmpty) {
      _status = FindWorkStatus.loading;
      _errorMessage = '';
      notifyListeners();
    }
    try {
      final fetched = await _service.tasks(
        query: _query,
        categorySlug: _categorySlug,
      );
      if (generation != _generation) return;
      _projects
        ..clear()
        ..addAll([
          for (final project in fetched)
            if (project.id.isNotEmpty) _restore(project),
        ]);
      _loadedKey = key;
      _status = _projects.isEmpty ? FindWorkStatus.empty : FindWorkStatus.ready;
      _errorMessage = '';
    } on NetworkException catch (e) {
      if (generation != _generation) return;
      _errorMessage = e.message;
      // A failed reload leaves the list that is already on screen alone.
      if (_projects.isEmpty) _status = FindWorkStatus.error;
    } catch (e) {
      if (generation != _generation) return;
      _errorMessage = '$e';
      if (_projects.isEmpty) _status = FindWorkStatus.error;
    } finally {
      if (generation == _generation) {
        _fetching = false;
        notifyListeners();
      }
    }
    if (_stale) {
      _stale = false;
      await load();
    }
  }

  /// Pull-to-refresh and the return from a submitted proposal: the board is
  /// read again even if nothing on the device changed. While a read is already
  /// running this waits for that one instead of stacking a second identical
  /// request on the server.
  Future<void> refresh() async {
    if (_fetching) return;
    await load(force: true);
  }

  /// A deeper screen changed one of these projects in place.
  void notify() => notifyListeners();

  ProjectModel _restore(ProjectModel project) {
    project
      ..saved = _savedIds.contains(project.id)
      ..applied = _appliedIds.contains(project.id);
    return project;
  }

  ProjectModel byId(String id) => _projects.firstWhere((p) => p.id == id);

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(searchDelay, load);
  }

  /// The search button: skip the wait. An unchanged word is not asked twice.
  Future<void> searchNow() {
    _debounce?.cancel();
    return load();
  }

  void setTab(int index) {
    if (_tab == index) return;
    _tab = index;
    notifyListeners();
  }

  void toggleLevel(String level) {
    if (!_levels.add(level)) _levels.remove(level);
    notifyListeners();
  }

  void setVerifiedOnly(bool value) {
    _verifiedOnly = value;
    notifyListeners();
  }

  /// A category is the server's filter, so picking one means reading again.
  void setCategory(String slug) {
    if (_categorySlug == slug) return;
    _categorySlug = slug;
    notifyListeners();
    load();
  }

  /// `GET /api/categories` is read when the filter sheet opens, not at
  /// startup — the board itself does not need it.
  Future<void> loadCategories() async {
    if (_categoriesRequested || _loadingCategories) return;
    final generation = _generation;
    _categoriesRequested = true;
    _loadingCategories = true;
    notifyListeners();
    try {
      final rows = await _service.categories();
      if (generation != _generation) return;
      _categories.addAll(rows);
    } on NetworkException catch (e) {
      if (generation != _generation) return;
      // The board still works without the list; the sheet just says so.
      _errorMessage = e.message;
      _categoriesRequested = false;
    } finally {
      if (generation == _generation) {
        _loadingCategories = false;
        notifyListeners();
      }
    }
  }

  void clearFilters() {
    _levels.clear();
    _verifiedOnly = false;
    final filtered = _categorySlug.isNotEmpty;
    _categorySlug = '';
    notifyListeners();
    if (filtered) load();
  }

  void toggleSave(String id) {
    if (!_savedIds.add(id)) _savedIds.remove(id);
    byId(id).saved = _savedIds.contains(id);
    notifyListeners();
  }

  /// Uploads the picked files through the backend's media route, then sends the
  /// proposal. Success is only reported when `POST /api/tasks/{id}/bid` answers
  /// 201 with the row it stored.
  Future<BidOutcome> apply(
    ProjectModel project, {
    required String proposal,
    double? bidAmount,
    List<ProposalAttachment> attachments = const [],
    List<String> portfolioItemIds = const [],
  }) async {
    if (!SessionStore.instance.hasSessionCookie) {
      return (sent: false, message: 'Sign in to send a proposal.', spent: 0);
    }
    _errorMessage = '';
    try {
      final urls = <String>[];
      for (final file in attachments) {
        urls.add(
          await _service.uploadAttachment(
            bytes: file.bytes,
            filename: file.name,
            mimeType: file.mimeType,
          ),
        );
      }
      final receipt = await _service.bid(
        taskId: project.id,
        proposal: proposal,
        bidAmount: bidAmount,
        attachmentUrls: urls,
        portfolioItemIds: portfolioItemIds,
      );
      _appliedIds.add(project.id);
      project.applied = true;
      // The proposal count is the server's, so the board is read again rather
      // than written down by hand.
      unawaited(load(force: true));
      // The bid spent connects and put a row on the proposals list, so both
      // screens read their own routes again rather than being written down —
      // including the wallet, which is the only place the app learns what the
      // account has left to spend.
      unawaited(WalletController.instance.refresh());
      unawaited(ProposalsController.instance.refresh());
      return (
        sent: true,
        message: 'Proposal sent.',
        spent: receipt.connectsSpent,
      );
    } on NetworkException catch (e) {
      return (
        sent: false,
        message: e.statusCode == 401
            ? 'Your session has expired. Please log in again.'
            : e.message,
        spent: 0,
      );
    } catch (e) {
      return (sent: false, message: '$e', spent: 0);
    }
  }

  /// Signs the board out. Bookmarks and application marks are device state, so
  /// the next account on this device must not inherit the previous one's.
  void clear() {
    _debounce?.cancel();
    _generation++;
    _fetching = false;
    _stale = false;
    _projects.clear();
    _categories.clear();
    _levels.clear();
    _savedIds.clear();
    _appliedIds.clear();
    _categoriesRequested = false;
    _loadedKey = '';
    _query = '';
    _categorySlug = '';
    _tab = 0;
    _verifiedOnly = false;
    _status = FindWorkStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
