import 'package:flutter/foundation.dart';

import '../../../core/network/session_store.dart';
import '../../../core/utils/validators.dart';
import '../../settings/models/account_settings.dart';
import '../../settings/services/account_cache.dart';
import '../../auth/models/user_model.dart';
import '../../auth/repositories/auth_repository.dart';
import '../models/profile_entries.dart';
import '../repositories/profile_repository.dart';
import '../services/profile_cache.dart';

/// Where the profile stands between the device and the backend.
enum ProfileStatus {
  /// No session cookie, or the session the cookie described has ended.
  signedOut,

  /// The session request is in flight.
  loading,

  /// The session answered with a user, so [ProfileController.name] and
  /// friends are real.
  ready,

  /// The request failed: the retry control is shown instead of the data.
  failed,
}

/// The single in-memory profile every screen reads from.
///
/// Identity — name, email and role — comes from the signed-in session, and
/// everything else the backend holds comes from `GET /api/profile`: title,
/// rate, overview, skills, linked URLs, the stored photo, the intro link and all
/// five section tables. The server is the source of truth; the screens show the
/// account's cached document the moment the session lands and the read replaces
/// it as soon as it answers.
///
/// Writes stay through their own routes — `PATCH /api/profile` for the identity
/// and `/api/profile/{section}` for a row — and each answer is applied to the
/// state so a save is reflected without another read. A read that fails for any
/// reason leaves whatever is already on screen alone.
class ProfileController extends ChangeNotifier {
  ProfileController._();

  static final ProfileController instance = ProfileController._();

  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final ProfileCache _cache = ProfileCache.instance;

  /// Profile context columns kept per user because they have no read route.
  final AccountCache _accountCache = AccountCache.instance;

  ProfileStatus _status = ProfileStatus.signedOut;
  String _errorMessage = '';
  bool _saving = false;

  /// The profile read in flight, and the account it was read for, so two screens
  /// opened together — or two taps — cost one request instead of several.
  Future<void>? _syncTask;
  String _syncAccount = '';

  /// The account the last session read described, which is the id every cached
  /// document is filed under.
  String userId = '';
  String name = '';
  String email = '';
  String role = '';
  String title = '';
  String location = '';
  String hourlyRate = '';
  String bio = '';

  /// The avatar the backend stores for this account, if the session carries
  /// one. A photo picked on this device temporarily wins over it.
  String? avatarUrl;
  Uint8List? avatarBytes;

  /// Sections of the profile, filled by `GET /api/profile` and kept in step with
  /// the answers of their own write routes. Every row carries the id the server
  /// gave it, which is what lets it be edited or removed later.
  final List<PortfolioItem> portfolio = [];
  final List<String> skills = [];
  final List<Language> languages = [];
  final List<Education> education = [];
  final List<Certification> certifications = [];
  final List<Employment> employment = [];
  final List<WorkHistoryJob> workHistory = [];

  /// The intro link `POST /api/profile/video-intro` stored. The route takes a
  /// URL, never a file, so this is the whole of what the app can show.
  String videoIntro = '';

  /// The profile columns `GET /api/profile` does not report. These are the values this account last
  /// saved — visibility, project preference, earning privacy, experience level
  /// and category slugs.
  ProfileSettings settings = defaultProfileSettings;
  String githubUrl = '';
  String websiteUrl = '';
  String youtubeUrl = '';

  ProfileStatus get status => _status;
  String get errorMessage => _errorMessage;

  /// Only what the session request itself said. A write that was refused
  /// belongs next to the control that triggered it, not under the identity
  /// block, where it would sit beside a retry that cannot fix it.
  String get sessionError =>
      _status == ProfileStatus.failed ? _errorMessage : '';
  bool get isLoading => _status == ProfileStatus.loading;
  bool get isSaving => _saving;
  bool get isSignedIn => _status == ProfileStatus.ready;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Reads the session the stored cookies describe, once per sign-in. The
  /// request goes through the same auth layer the splash uses, so the cookie
  /// jar and the `[API]` log stay in one place.
  Future<void> load({bool force = false}) async {
    if (_status == ProfileStatus.loading) return;
    if (_status == ProfileStatus.ready && !force) {
      // The identity is already on screen from this session; only the server's
      // copy of the rest can still be newer.
      await _sync();
      return;
    }
    // The splash's session check is what pulls a saved cookie into the jar, so
    // by the time a profile opens there is either a cookie to ask with or a
    // device that has never signed in.
    if (!SessionStore.instance.hasSessionCookie) {
      _wipe();
      _status = ProfileStatus.signedOut;
      notifyListeners();
      return;
    }
    _status = ProfileStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final user = await _authRepository.currentSession();
      if (user == null) {
        // The existing session-expiration path: no session means no profile,
        // and nothing the previous one described is left on screen.
        _wipe();
        _status = ProfileStatus.signedOut;
      } else {
        // Rows this device was holding for a different account come off before
        // the new session is shown; an unnamed state has nothing to take back.
        if (userId.isNotEmpty && userId != user.id) _wipe();
        final reported = _apply(user);
        _status = ProfileStatus.ready;
        await _restore();
        // A photo the session reported is the only copy any read endpoint has
        // ever given this device, so it is filed under the account at once:
        // the next sign-in's session may report none.
        if (reported) await _persist();
        await _sync();
      }
    } catch (e) {
      _errorMessage = _messageFrom(e);
      _status = ProfileStatus.failed;
    }
    notifyListeners();
  }

  /// Writes the identity block to `PATCH /api/profile`.
  ///
  /// The route replaces the whole profile and insists on a valid `name`, so
  /// the signed-in name and the skill list travel with every save — and so does
  /// [_profileContext], which carries the columns no read reports: leaving them
  /// out of a body would clear them on the server.
  Future<bool> saveIdentity({
    String? name,
    required String title,
    required String hourlyRate,
    required String bio,
  }) async {
    if (_saving) return false;
    if (_status != ProfileStatus.ready) {
      _errorMessage = 'Sign in again to save these changes.';
      notifyListeners();
      return false;
    }
    final submitted = (name ?? this.name).trim();
    if (submitted.length < 2) {
      // The route validates `name` first and answers 400 for the whole body.
      _errorMessage = 'Enter a name with at least 2 characters.';
      notifyListeners();
      return false;
    }
    _saving = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final saved = await _profileRepository.save(
        name: submitted,
        title: title,
        bio: bio,
        hourlyRate: _parseRate(hourlyRate),
        skills: skills,
        context: await _profileContext(),
      );
      // The route's own `{user: …}` answer is the confirmation, so the state
      // follows it rather than the request.
      this.name = saved.name;
      this.title = title;
      this.hourlyRate = hourlyRate;
      this.bio = bio;
      if (saved.avatarUrl.isNotEmpty) avatarUrl = saved.avatarUrl;
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Writes the Settings profile block to the same `PATCH /api/profile` route.
  ///
  /// The route replaces the profile, so the identity fields on screen travel
  /// with the settings rather than being left out of the body. Nothing is
  /// applied before the route answers: a save the server refused — for a name it
  /// cannot accept or a value over its limit — keeps the previous settings on
  /// screen and reports its answer.
  Future<bool> saveSettings(ProfileSettings draft) async {
    if (_saving) return false;
    if (_status != ProfileStatus.ready) {
      _errorMessage = 'Sign in again to save these changes.';
      notifyListeners();
      return false;
    }
    final error = _settingsError(draft);
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return false;
    }
    _saving = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final context = await _profileContext();
      await _profileRepository.save(
        name: name,
        title: title,
        bio: bio,
        hourlyRate: _parseRate(hourlyRate),
        skills: skills,
        context: (
          phone: context.phone,
          location: context.location,
          settings: draft,
        ),
      );
      settings = draft;
      if (userId.isNotEmpty) await _accountCache.saveSettings(userId, draft);
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Saves the links shown in Profile → About through the existing profile
  /// route, keeping them available after a reinstall or on another device.
  Future<bool> saveLinkedAccounts({
    required String githubUrl,
    required String websiteUrl,
    required String youtubeUrl,
  }) async {
    if (_saving) return false;
    if (_status != ProfileStatus.ready) {
      _errorMessage = 'Sign in again to save these links.';
      notifyListeners();
      return false;
    }
    final links = <String, String>{
      'GitHub': githubUrl.trim(),
      'Website': websiteUrl.trim(),
      'YouTube': youtubeUrl.trim(),
    };
    for (final entry in links.entries) {
      if (entry.value.length > 300) {
        _errorMessage =
            '${entry.key} link cannot be longer than 300 characters.';
        notifyListeners();
        return false;
      }
      if (entry.value.isNotEmpty && !Validators.isWebAddress(entry.value)) {
        _errorMessage = 'Enter a valid ${entry.key} URL.';
        notifyListeners();
        return false;
      }
    }

    _saving = true;
    _errorMessage = '';
    notifyListeners();
    try {
      await _profileRepository.save(
        name: name,
        title: title,
        bio: bio,
        hourlyRate: _parseRate(hourlyRate),
        skills: skills,
        context: await _profileContext(),
        githubUrl: links['GitHub'],
        websiteUrl: links['Website'],
        youtubeUrl: links['YouTube'],
      );
      this.githubUrl = links['GitHub']!;
      this.websiteUrl = links['Website']!;
      this.youtubeUrl = links['YouTube']!;
      settings = _settingsWithCurrentLinks();
      if (userId.isNotEmpty) await _accountCache.saveSettings(userId, settings);
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Keeps the edited skill list and asks the backend to store it. `skills` is
  /// a plain text column on the profile, so the list travels through the same
  /// replace-request as the identity. Nothing is requested while signed out.
  Future<void> saveSkills(List<String> replacement) async {
    skills
      ..clear()
      ..addAll(replacement);
    notifyListeners();
    if (_status != ProfileStatus.ready) return;
    await saveIdentity(title: title, hourlyRate: hourlyRate, bio: bio);
  }

  /// Uploads to the avatar route, then shows the stored photo everywhere.
  Future<bool> uploadAvatar(
    Uint8List bytes, {
    String filename = 'avatar.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    if (_status != ProfileStatus.ready) {
      _errorMessage = 'Sign in again to upload a photo.';
      notifyListeners();
      return false;
    }
    try {
      final url = await _profileRepository.uploadAvatar(
        bytes,
        filename: filename,
        mimeType: mimeType,
      );
      avatarBytes = bytes;
      avatarUrl = url.isEmpty ? null : url;
      _errorMessage = '';
      // The uploaded URL is the only copy this device can read back after a
      // sign-in, so it is stored with the account it belongs to.
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> removeAvatar() async {
    if (_status != ProfileStatus.ready) {
      _errorMessage = 'Sign in again to remove the photo.';
      notifyListeners();
      return false;
    }
    try {
      await _profileRepository.removeAvatar();
      avatarUrl = null;
      avatarBytes = null;
      _errorMessage = '';
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  // Section rows -------------------------------------------------------------

  Future<bool> saveLanguage(Language row, {int index = -1}) => _writeRow(
    languages,
    index,
    row,
    _profileRepository.saveLanguage,
    'save this language',
  );

  Future<bool> removeLanguage(int index) =>
      _removeRow(languages, index, _profileRepository.removeLanguage);

  Future<bool> saveEducation(Education row, {int index = -1}) => _writeRow(
    education,
    index,
    row,
    _profileRepository.saveEducation,
    'save this education',
  );

  Future<bool> removeEducation(int index) =>
      _removeRow(education, index, _profileRepository.removeEducation);

  Future<bool> saveCertification(Certification row, {int index = -1}) =>
      _writeRow(
        certifications,
        index,
        row,
        _profileRepository.saveCertification,
        'save this certification',
      );

  Future<bool> removeCertification(int index) =>
      _removeRow(certifications, index, _profileRepository.removeCertification);

  Future<bool> saveEmployment(Employment row, {int index = -1}) => _writeRow(
    employment,
    index,
    row,
    _profileRepository.saveEmployment,
    'save this job',
  );

  Future<bool> removeEmployment(int index) =>
      _removeRow(employment, index, _profileRepository.removeEmployment);

  /// Uploads the project's file to the media route, then creates the row that
  /// points at it. A new project joins the grid at the front, where the screen
  /// shows it.
  Future<bool> publishPortfolio(PortfolioDraft draft) async {
    if (!_openWrite('publish this project')) return false;
    try {
      portfolio.insert(0, await _profileRepository.addPortfolio(draft));
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> removePortfolio(int index) async {
    if (index < 0 || index >= portfolio.length) return false;
    if (!_openWrite('remove this project')) return false;
    try {
      await _profileRepository.removePortfolio(portfolio[index]);
      portfolio.removeAt(index);
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> saveVideoIntro(String url) async {
    final link = url.trim();
    if (!_openWrite('save the video intro')) return false;
    try {
      videoIntro = await _profileRepository.saveVideoIntro(link);
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> removeVideoIntro() async {
    if (!_openWrite('remove the video intro')) return false;
    try {
      await _profileRepository.removeVideoIntro();
      videoIntro = '';
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Sends [row] to its section route and only lists the answer. A row the
  /// server refused — for a date it cannot read, or a field over its limit —
  /// stays off the list, so the app never shows a record that was not stored.
  /// [index] is -1 for a new row, which is appended.
  Future<bool> _writeRow<E>(
    List<E> rows,
    int index,
    E row,
    Future<E> Function(E) request,
    String action,
  ) async {
    if (!_openWrite(action)) return false;
    try {
      final saved = await request(row);
      if (index < 0) {
        rows.add(saved);
      } else {
        rows[index] = saved;
      }
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _removeRow<E>(
    List<E> rows,
    int index,
    Future<void> Function(E) request,
  ) async {
    if (index < 0 || index >= rows.length) return false;
    if (!_openWrite('remove this entry')) return false;
    try {
      await request(rows[index]);
      rows.removeAt(index);
      await _persist();
      return true;
    } catch (e) {
      _errorMessage = _messageFrom(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// A section write needs the session the identity writes use: the routes
  /// answer 401 without the cookie, and a nameless row cannot be addressed
  /// again afterwards.
  bool _openWrite(String action) {
    if (_status == ProfileStatus.ready) {
      _errorMessage = '';
      return true;
    }
    _errorMessage = 'Sign in again to $action.';
    notifyListeners();
    return false;
  }

  void update({
    String? name,
    String? email,
    String? title,
    String? location,
    String? hourlyRate,
    String? bio,
  }) {
    if (name != null) this.name = name;
    if (email != null) this.email = email;
    if (title != null) this.title = title;
    if (location != null) this.location = location;
    if (hourlyRate != null) this.hourlyRate = hourlyRate;
    if (bio != null) this.bio = bio;
    notifyListeners();
  }

  /// Passing null restores the session's photo.
  void setAvatar(Uint8List? bytes) {
    avatarBytes = bytes;
    notifyListeners();
  }

  /// Drops everything belonging to this account so the next person to sign in
  /// cannot see it.
  ///
  /// The saved document stays on the device: it is filed under this account's
  /// id, so another account can never read it, and it is what a sign-in shows
  /// before the server's copy arrives — or when there is no network to fetch it
  /// from.
  void clear() {
    _wipe();
    _saving = false;
    _status = ProfileStatus.signedOut;
    notifyListeners();
  }

  /// Takes the account's data out of memory. The id goes with it, so nothing
  /// can be written to the next account's document by accident.
  void _wipe() {
    userId = '';
    name = '';
    email = '';
    role = '';
    title = '';
    location = '';
    hourlyRate = '';
    bio = '';
    avatarUrl = null;
    avatarBytes = null;
    _errorMessage = '';
    portfolio.clear();
    skills.clear();
    languages.clear();
    education.clear();
    certifications.clear();
    employment.clear();
    workHistory.clear();
    videoIntro = '';
    githubUrl = '';
    websiteUrl = '';
    youtubeUrl = '';
    settings = defaultProfileSettings;
  }

  /// Applies the session's identity, answering whether it reported a photo.
  ///
  /// Returns false for an absent or empty `image`: the NextAuth JWT is built at
  /// sign-in and carries no avatar for a credentials login, so an empty field
  /// says nothing about the stored photo — only a URL the server actually sent
  /// may replace it.
  bool _apply(UserModel user) {
    userId = user.id;
    name = user.name;
    email = user.email;
    role = user.role ?? '';
    final photo = user.avatar;
    if (photo == null || photo.isEmpty) return false;
    avatarUrl = photo;
    return true;
  }

  /// Replaces what is on screen with the account's saved profile.
  ///
  /// Nothing but the session cookie scopes the read, so it answers for whoever
  /// is signed in right now, and an answer that arrives after the account moved
  /// on is dropped instead of applied. Any failure — no network, a refused or
  /// expired session, a body that is not a profile — leaves the cached profile
  /// standing: the request has already logged what went wrong.
  Future<void> _sync() async {
    if (userId.isEmpty || _status != ProfileStatus.ready) return;
    final account = userId;
    final pending = _syncTask;
    if (pending != null && _syncAccount == account) return pending;
    final task = _readProfile(account);
    _syncTask = task;
    _syncAccount = account;
    try {
      await task;
    } finally {
      if (identical(_syncTask, task)) {
        _syncTask = null;
        _syncAccount = '';
      }
    }
  }

  Future<void> _readProfile(String account) async {
    final ProfileSnapshot saved;
    try {
      saved = await _profileRepository.fetchProfile();
    } catch (_) {
      return;
    }
    if (userId != account || _status != ProfileStatus.ready) return;
    _applyServerProfile(saved);
    await _persist();
    notifyListeners();
  }

  /// Makes the server's answer the state, field for field.
  ///
  /// The photo is the one field an absent answer does not clear: a Google
  /// sign-in reports its own picture through the session, and an account that
  /// never uploaded one stores no `avatarUrl` at all.
  void _applyServerProfile(ProfileSnapshot saved) {
    title = saved.title;
    hourlyRate = saved.hourlyRate;
    bio = saved.bio;
    skills
      ..clear()
      ..addAll(saved.skills);
    languages
      ..clear()
      ..addAll(saved.languages);
    education
      ..clear()
      ..addAll(saved.education);
    certifications
      ..clear()
      ..addAll(saved.certifications);
    employment
      ..clear()
      ..addAll(saved.employment);
    portfolio
      ..clear()
      ..addAll(saved.portfolio);
    videoIntro = saved.videoIntro;
    githubUrl = saved.githubUrl;
    websiteUrl = saved.websiteUrl;
    youtubeUrl = saved.youtubeUrl;
    settings = _settingsWithCurrentLinks();
    if (saved.avatarUrl.isNotEmpty) avatarUrl = saved.avatarUrl;
  }

  /// Puts back what this device saved for the account the session described, so
  /// a profile is on screen before the read of the server's copy finishes. The
  /// session keeps its authority over name, email and role, and [_sync] replaces
  /// everything else the moment it answers.
  Future<void> _restore() async {
    if (userId.isEmpty) return;
    // The settings columns come from their own document, which an account can
    // have written from Settings without touching the profile sections below.
    settings =
        (await _accountCache.restoreContext(userId)).settings ??
        defaultProfileSettings;
    githubUrl = settings.githubUrl;
    websiteUrl = settings.websiteUrl;
    youtubeUrl = settings.youtubeUrl;
    final saved = await _cache.restore(userId);
    // A sign-in that landed on another account must not have the previous
    // one's document applied to it.
    if (saved == null || _status != ProfileStatus.ready || userId.isEmpty) {
      return;
    }
    title = saved.title;
    hourlyRate = saved.hourlyRate;
    bio = saved.bio;
    skills
      ..clear()
      ..addAll(saved.skills);
    languages
      ..clear()
      ..addAll(saved.languages);
    education
      ..clear()
      ..addAll(saved.education);
    certifications
      ..clear()
      ..addAll(saved.certifications);
    employment
      ..clear()
      ..addAll(saved.employment);
    portfolio
      ..clear()
      ..addAll(saved.portfolio);
    videoIntro = saved.videoIntro;
    githubUrl = saved.githubUrl;
    websiteUrl = saved.websiteUrl;
    youtubeUrl = saved.youtubeUrl;
    settings = _settingsWithCurrentLinks();
    if ((avatarUrl == null || avatarUrl!.isEmpty) &&
        saved.avatarUrl.isNotEmpty) {
      avatarUrl = saved.avatarUrl;
    }
    notifyListeners();
  }

  /// Keeps the account's document in step with the state the server confirmed.
  Future<void> _persist() async {
    if (userId.isEmpty) return;
    await _cache.save(userId, (
      title: title,
      hourlyRate: hourlyRate,
      bio: bio,
      skills: List<String>.of(skills),
      avatarUrl: avatarUrl ?? '',
      videoIntro: videoIntro,
      languages: List<Language>.of(languages),
      education: List<Education>.of(education),
      certifications: List<Certification>.of(certifications),
      employment: List<Employment>.of(employment),
      portfolio: List<PortfolioItem>.of(portfolio),
      githubUrl: githubUrl,
      websiteUrl: websiteUrl,
      youtubeUrl: youtubeUrl,
    ));
  }

  /// The columns no read reports, for the account on screen and as fresh as the
  /// keystore has them, so context saved a moment ago travels with the next
  /// write rather than an older copy of it. A part this device never held stays
  /// null, which keeps its columns out of the request rather than sending blanks
  /// over values the account set somewhere else.
  Future<ProfileContext> _profileContext() {
    if (userId.isEmpty) {
      return Future.value((phone: null, location: null, settings: null));
    }
    return _accountCache.restoreContext(userId);
  }

  ProfileSettings _settingsWithCurrentLinks() => (
    visibility: settings.visibility,
    workGoal: settings.workGoal,
    earningPrivacy: settings.earningPrivacy,
    experienceLevel: settings.experienceLevel,
    interestSlugs: settings.interestSlugs,
    githubUrl: githubUrl,
    websiteUrl: websiteUrl,
    youtubeUrl: youtubeUrl,
  );

  /// What the route would refuse, said before the request goes out.
  ///
  /// `PATCH /api/profile` answers a rejected body with one generic
  /// "Invalid profile data", so a field over its limit is worth naming here —
  /// and the category rules are the ones the web's own form applies.
  String? _settingsError(ProfileSettings draft) {
    if (name.trim().length < 2) {
      return 'Enter a name with at least 2 characters.';
    }
    if (draft.interestSlugs.isEmpty) {
      return 'Select at least one category.';
    }
    if (draft.interestSlugs.length > categorySelectionLimit) {
      return 'You can pick up to $categorySelectionLimit categories.';
    }
    for (final link in [draft.githubUrl, draft.websiteUrl, draft.youtubeUrl]) {
      if (link.length > 300) {
        return 'A link cannot be longer than 300 characters.';
      }
    }
    return null;
  }

  /// The route stores the rate as a number while this field is free text, so
  /// the first amount in the typed value is what gets sent.
  double? _parseRate(String text) =>
      double.tryParse(RegExp(r'\d+(\.\d+)?').firstMatch(text)?.group(0) ?? '');

  String _messageFrom(Object e) => '$e'.replaceFirst('Exception: ', '');
}
