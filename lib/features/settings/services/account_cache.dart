import '../../../core/storage/user_data_store.dart';
import '../models/account_settings.dart';

/// The profile context fields kept per user for writes that need them.
///
/// `PATCH /api/account/contact` answers with the row it wrote and
/// `PATCH /api/profile` answers with only the name and photo, so the timezone,
/// country, state, city, visibility, project preference, earning privacy,
/// experience level and categories are not reported by any read route. These
/// documents let Settings show its own last save and let profile writes carry
/// values the route would otherwise clear. Linked URLs remain here for older
/// cached settings, but `GET /api/profile` is now their source of truth.
///
/// A phone number belongs here because the security route reports it: caching
/// that answer keeps a later profile write from blanking the column, which would
/// otherwise silence SMS verification without saying so.
class AccountCache {
  AccountCache._();

  static final AccountCache instance = AccountCache._();

  static const String _collection = 'account';
  static const String _contextCollection = 'profile-context';

  /// The keys of the column set, so one save can add them to a document
  /// that already holds the phone.
  static const List<String> _settingKeys = [
    'visibility',
    'workGoal',
    'earningPrivacy',
    'experienceLevel',
    'interestSlugs',
    'githubUrl',
    'websiteUrl',
    'youtubeUrl',
  ];

  Future<ProfileLocation?> restore(String userId) async {
    final document = await UserDataStore.instance.read(_collection, userId);
    if (document == null) return null;
    return (
      timezone: _text(document['timezone']),
      country: _text(document['country']),
      stateProvince: _text(document['stateProvince']),
      city: _text(document['city']),
    );
  }

  Future<void> save(String userId, ProfileLocation location) =>
      UserDataStore.instance.write(_collection, userId, <String, dynamic>{
        'timezone': location.timezone,
        'country': location.country,
        'stateProvince': location.stateProvince,
        'city': location.city,
      });

  /// Everything this device holds for profile context. A part that was never
  /// saved comes back null rather than as blanks, which tells a write to leave
  /// those keys alone.
  Future<ProfileContext> restoreContext(String userId) async {
    final location = await restore(userId);
    final document = await UserDataStore.instance.read(
      _contextCollection,
      userId,
    );
    return (
      phone: document?['phone'] is String ? document!['phone'] as String : null,
      location: location,
      settings: _settings(document),
    );
  }

  Future<void> saveSettings(String userId, ProfileSettings settings) async {
    final document =
        await UserDataStore.instance.read(_contextCollection, userId) ??
        <String, dynamic>{};
    document['visibility'] = settings.visibility;
    document['workGoal'] = settings.workGoal;
    document['earningPrivacy'] = settings.earningPrivacy;
    document['experienceLevel'] = settings.experienceLevel;
    document['interestSlugs'] = settings.interestSlugs;
    document['githubUrl'] = settings.githubUrl;
    document['websiteUrl'] = settings.websiteUrl;
    document['youtubeUrl'] = settings.youtubeUrl;
    await UserDataStore.instance.write(_contextCollection, userId, document);
  }

  Future<void> savePhone(String userId, String phone) async {
    final document =
        await UserDataStore.instance.read(_contextCollection, userId) ??
        <String, dynamic>{};
    document['phone'] = phone;
    await UserDataStore.instance.write(_contextCollection, userId, document);
  }

  /// The saved settings only when every one of the keys is there: a document
  /// holding just a phone reports nothing about the account's visibility.
  ProfileSettings? _settings(Map<String, dynamic>? document) {
    if (document == null) return null;
    for (final key in _settingKeys) {
      if (!document.containsKey(key)) return null;
    }
    return (
      visibility: _word(
        document['visibility'],
        profileVisibilityLevels.keys,
        defaultProfileSettings.visibility,
      ),
      workGoal: _word(
        document['workGoal'],
        workGoalOptions,
        defaultProfileSettings.workGoal,
      ),
      earningPrivacy: _word(
        document['earningPrivacy'],
        earningPrivacyLevels.keys,
        defaultProfileSettings.earningPrivacy,
      ),
      experienceLevel: _word(document['experienceLevel'], const [
        'BEGINNER',
        'INTERMEDIATE',
        'PRO',
      ], defaultProfileSettings.experienceLevel),
      interestSlugs: [
        if (document['interestSlugs'] is List)
          for (final slug in document['interestSlugs'] as List)
            if (slug is String && slug.isNotEmpty) slug,
      ],
      githubUrl: _text(document['githubUrl']),
      websiteUrl: _text(document['websiteUrl']),
      youtubeUrl: _text(document['youtubeUrl']),
    );
  }

  String _text(Object? value) => value is String ? value : '';

  /// A stored token the app still offers, or the fallback. A value only a newer
  /// backend writes is not worth showing as an unlabelled dropdown entry.
  String _word(Object? value, Iterable<String> accepted, String fallback) {
    final text = _text(value);
    return accepted.contains(text) ? text : fallback;
  }
}
