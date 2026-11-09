import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../../settings/models/account_settings.dart';
import '../models/profile_entries.dart';

/// The profile the backend reads and writes for the signed-in account.
///
/// `GET /api/profile` answers the whole profile in one response — the columns
/// the identity editor owns plus every row of the five section tables — which is
/// what lets a reinstalled device put a saved profile back on screen.
///
/// `PATCH /api/profile` is a replace rather than a merge — every field the
/// body leaves out is stored as null — so the request always carries the whole
/// set the app owns for this profile.
class ProfileService {
  final ApiClient _apiClient = ApiClient();

  /// The saved profile of the account the session cookie belongs to.
  ///
  /// The answer is `{user: {name, title, bio, skills, hourlyRate, avatarUrl,
  /// videoIntroUrl, githubUrl, websiteUrl, youtubeUrl}}` plus `languages`, `education`, `certifications`,
  /// `employment` and `portfolio`, each row in the same shape its own POST and
  /// PATCH routes return, so one read fills every section at once. Nothing
  /// scopes it but the cookie: the route has no `userId` parameter and an
  /// account with nothing saved answers with empty lists rather than an error.
  Future<ProfileSnapshot> fetchProfile() async {
    final response = await _apiClient.get(ApiEndpoints.profile);
    final data = response is Map<String, dynamic> ? response : null;
    final user = data?['user'];
    if (data == null || user is! Map<String, dynamic>) {
      throw NetworkException('The server did not return the saved profile.');
    }
    return (
      title: _asText(user['title']),
      hourlyRate: _rateText(user['hourlyRate']),
      bio: _asText(user['bio']),
      skills: _commaList(_asText(user['skills'])),
      avatarUrl: _asText(user['avatarUrl']),
      videoIntro: _asText(user['videoIntroUrl']),
      githubUrl: _asText(user['githubUrl']),
      websiteUrl: _asText(user['websiteUrl']),
      youtubeUrl: _asText(user['youtubeUrl']),
      languages: [
        for (final row in _idRows(data['languages']))
          if (_asText(row['name']).isNotEmpty)
            (
              id: _asText(row['id']),
              name: _asText(row['name']),
              level: _asText(row['proficiency']),
            ),
      ],
      education: [
        for (final row in _idRows(data['education']))
          if (_asText(row['school']).isNotEmpty)
            (
              id: _asText(row['id']),
              institution: _asText(row['school']),
              degree: _asText(row['degree']),
            ),
      ],
      certifications: [
        for (final row in _idRows(data['certifications']))
          if (_asText(row['title']).isNotEmpty)
            (
              id: _asText(row['id']),
              title: _asText(row['title']),
              provider: _asText(row['provider']),
              // A date column reads back as an ISO timestamp; the card wants the
              // label the form itself writes, which `isoDateFromText` turns back
              // into a date on the next save.
              issued: _dateText(row['issuedAt']),
              credentialId: _asText(row['certificateId']),
              description: _asText(row['description']),
            ),
      ],
      employment: [
        for (final row in _idRows(data['employment']))
          if (_asText(row['title']).isNotEmpty) _employment(row),
      ],
      portfolio: [
        for (final row in _idRows(data['portfolio']))
          if (_asText(row['title']).isNotEmpty)
            (
              id: _asText(row['id']),
              title: _asText(row['title']),
              image: _asText(row['imageUrl']),
              kind: _asText(row['mediaType']),
              link: _asText(row['linkUrl']),
              status: _asText(row['status']),
              role: _asText(row['role']),
              skills: _jsonList(row['skills']),
              description: _asText(row['description']),
            ),
      ],
    );
  }

  /// Replaces the identity fields the app owns.
  ///
  /// Every argument is written as given, so a caller that changes one field has
  /// to send the others as they stand — which is what [fetchProfile] makes
  /// possible. `avatarUrl` never travels here; the route deletes the asset it
  /// replaces.
  ///
  /// [context] carries the columns no read reports — the phone, the location,
  /// the visibility, project preference, earning privacy, experience level and
  /// categories. The linked URLs are supplied separately from profile state.
  /// Each part is only sent when this device holds it, so a save of a field the
  /// account set elsewhere is re-sent rather than blanked, while a column this
  /// device has never seen is left for the route to keep.
  Future<({String name, String avatarUrl})> save({
    required String name,
    String title = '',
    String bio = '',
    double? hourlyRate,
    List<String> skills = const [],
    ProfileContext? context,
    String? githubUrl,
    String? websiteUrl,
    String? youtubeUrl,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'title': title,
      'bio': bio,
      'skills': skills.join(', '),
      // The route turns a null rate into an unset column, so a rate the user
      // did not give is sent rather than left out.
      'hourlyRate': hourlyRate,
    };
    final settings = context?.settings;
    if (settings != null) {
      body['workGoal'] = settings.workGoal;
      body['experienceLevel'] = settings.experienceLevel;
      body['profileVisibility'] = settings.visibility;
      body['earningPrivacy'] = settings.earningPrivacy;
      body['interestSlugs'] = settings.interestSlugs;
    }
    if (githubUrl != null) body['githubUrl'] = githubUrl;
    if (websiteUrl != null) body['websiteUrl'] = websiteUrl;
    if (youtubeUrl != null) body['youtubeUrl'] = youtubeUrl;
    final location = context?.location;
    if (location != null) {
      body['timezone'] = location.timezone;
      body['country'] = location.country;
      body['stateProvince'] = location.stateProvince;
      body['city'] = location.city;
    }
    if (context?.phone != null) body['phone'] = context!.phone;
    final response = await _apiClient.patch(ApiEndpoints.profile, body: body);
    // `PATCH` is the only route that hands back the stored avatar URL: the
    // NextAuth session never carries one for a credentials sign-in.
    final user = response is Map ? response['user'] : null;
    final saved = user is Map<String, dynamic>
        ? user
        : const <String, dynamic>{};
    return (
      name: saved['name'] is String ? saved['name'] as String : name,
      avatarUrl: saved['avatarUrl'] is String
          ? saved['avatarUrl'] as String
          : '',
    );
  }

  /// Stores the avatar and returns the URL the backend kept. `avatarUrl` is
  /// never sent through [save]: changing it there makes the route delete the
  /// asset it replaces.
  Future<String> uploadAvatar(
    Uint8List bytes, {
    String filename = 'avatar.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    final response = await _apiClient.postFile(
      ApiEndpoints.profileAvatar,
      field: 'file',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
    if (!response.isSuccess) {
      throw NetworkException(response.message, statusCode: response.statusCode);
    }
    final url = response.json?['url'];
    return url is String ? url : '';
  }

  Future<void> removeAvatar() => _apiClient.delete(ApiEndpoints.profileAvatar);

  // Section rows ----------------------------------------------------------------

  /// Creates [row] or replaces it, decided by whether it already carries the id
  /// the backend handed back. Returns the row with that id, so the caller can
  /// address it again later.
  Future<Language> saveLanguage(Language row) async {
    final body = <String, dynamic>{'name': row.name, 'proficiency': row.level};
    return (
      id: row.id.isEmpty
          ? await _post(ApiEndpoints.profileLanguages, body)
          : await _patch(ApiEndpoints.profileLanguages, row.id, body),
      name: row.name,
      level: row.level,
    );
  }

  Future<void> removeLanguage(Language row) =>
      _delete(ApiEndpoints.profileLanguages, row.id);

  Future<Education> saveEducation(Education row) async {
    final body = <String, dynamic>{
      'school': row.institution,
      'degree': row.degree,
    };
    return (
      id: row.id.isEmpty
          ? await _post(ApiEndpoints.profileEducation, body)
          : await _patch(ApiEndpoints.profileEducation, row.id, body),
      institution: row.institution,
      degree: row.degree,
    );
  }

  Future<void> removeEducation(Education row) =>
      _delete(ApiEndpoints.profileEducation, row.id);

  Future<Certification> saveCertification(Certification row) async {
    final body = <String, dynamic>{
      'title': row.title,
      'provider': row.provider,
      // Only a date the route can read is sent; a free-text "Summer '24" would
      // be stored as an invalid date.
      'issuedAt': isoDateFromText(row.issued) ?? '',
      'certificateId': row.credentialId,
      'description': row.description,
    };
    return (
      id: row.id.isEmpty
          ? await _post(ApiEndpoints.profileCertifications, body)
          : await _patch(ApiEndpoints.profileCertifications, row.id, body),
      title: row.title,
      provider: row.provider,
      issued: row.issued,
      credentialId: row.credentialId,
      description: row.description,
    );
  }

  Future<void> removeCertification(Certification row) =>
      _delete(ApiEndpoints.profileCertifications, row.id);

  Future<Employment> saveEmployment(Employment row) async {
    final body = <String, dynamic>{
      'title': row.role,
      'company': row.company,
      'startDate': row.startDate,
      'endDate': row.endDate,
      'description': row.description,
    };
    return (
      id: row.id.isEmpty
          ? await _post(ApiEndpoints.profileEmployment, body)
          : await _patch(ApiEndpoints.profileEmployment, row.id, body),
      role: row.role,
      company: row.company,
      period: row.period,
      startDate: row.startDate,
      endDate: row.endDate,
      description: row.description,
    );
  }

  Future<void> removeEmployment(Employment row) =>
      _delete(ApiEndpoints.profileEmployment, row.id);

  /// Stores the picked file first, then creates the project that points at it,
  /// so a project never exists with a media URL the route rejected.
  Future<PortfolioItem> addPortfolio(PortfolioDraft draft) async {
    var url = '';
    var kind = draft.kind;
    final bytes = draft.bytes;
    if (bytes != null) {
      final media = await _apiClient.postFile(
        ApiEndpoints.profilePortfolioMedia,
        field: 'file',
        bytes: bytes,
        filename: draft.filename,
        mimeType: draft.mimeType,
      );
      if (!media.isSuccess) {
        throw NetworkException(media.message, statusCode: media.statusCode);
      }
      url = media.json?['url'] is String ? media.json!['url'] as String : '';
      // The route names the type it stored, which wins over the block's own.
      final stored = media.json?['mediaType'];
      kind = stored is String && stored.isNotEmpty ? stored : draft.kind;
    }
    final id = await _post(ApiEndpoints.profilePortfolio, <String, dynamic>{
      'title': draft.title,
      'role': draft.role,
      'skills': draft.skills,
      'description': draft.description,
      'imageUrl': url,
      'mediaType': kind,
      'linkUrl': draft.link,
      'status': draft.status,
    });
    return (
      id: id,
      title: draft.title,
      image: url,
      kind: kind,
      link: draft.link,
      status: draft.status,
      role: draft.role,
      skills: List<String>.unmodifiable(draft.skills),
      description: draft.description,
    );
  }

  Future<void> removePortfolio(PortfolioItem item) =>
      _delete(ApiEndpoints.profilePortfolio, item.id);

  /// Keeps the intro video link, answering with the URL the account now holds.
  Future<String> saveVideoIntro(String url) async {
    final response = await _apiClient.post(
      ApiEndpoints.profileVideoIntro,
      body: <String, dynamic>{'url': url},
    );
    final stored = response is Map ? response['url'] : null;
    return stored is String && stored.isNotEmpty ? stored : url;
  }

  Future<void> removeVideoIntro() =>
      _apiClient.delete(ApiEndpoints.profileVideoIntro);

  /// `POST` returns `201 {item}` and `PATCH` returns `{item}`; the id in that
  /// row is the only way this device can address the record again.
  Future<String> _post(String collection, Map<String, dynamic> body) async {
    final response = await _apiClient.post(collection, body: body);
    return _idOf(response);
  }

  Future<String> _patch(
    String collection,
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.patch(
      ApiEndpoints.profileEntry(collection, id),
      body: body,
    );
    return _idOf(response);
  }

  Future<void> _delete(String collection, String id) =>
      _apiClient.delete(ApiEndpoints.profileEntry(collection, id));

  String _idOf(Object? response) {
    final item = response is Map ? response['item'] : null;
    final id = item is Map ? item['id'] : null;
    if (id is! String || id.isEmpty) {
      throw NetworkException('The server did not return the saved record.');
    }
    return id;
  }

  Employment _employment(Map<String, dynamic> row) {
    final start = _asDate(row['startDate']);
    final end = _asDate(row['endDate']);
    return (
      id: _asText(row['id']),
      role: _asText(row['title']),
      company: _asText(row['company']),
      period: start == null ? '' : periodLabel(start, end),
      // Back to the plain date the app sends, so editing a restored row writes
      // the same shape its first save did.
      startDate: start == null ? '' : isoDate(start),
      endDate: end == null ? '' : isoDate(end),
      description: _asText(row['description']),
    );
  }

  /// A row is only useful if the backend gave it an id: without one it could
  /// never be edited or removed again from this device.
  List<Map<String, dynamic>> _idRows(Object? value) => [
    if (value is List)
      for (final row in value)
        if (row is Map<String, dynamic> && _asText(row['id']).isNotEmpty) row,
  ];

  /// A text column, or empty when the row carries none.
  String _asText(Object? value) => value is String ? value.trim() : '';

  /// `hourlyRate` is a number column while the app's field is free text, so the
  /// stored amount goes back to the form the user typed it in.
  String _rateText(Object? value) {
    if (value is! num) return _asText(value);
    return value == value.roundToDouble() ? '${value.round()}' : '$value';
  }

  /// The profile's `skills` column: one comma-separated line, which is how
  /// [save] writes the list.
  List<String> _commaList(String text) => [
    for (final part in text.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  /// `PortfolioItem.skills` is a JSON array string, not that plain text.
  List<String> _jsonList(Object? value) {
    final text = _asText(value);
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return [
          for (final item in decoded)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ];
      }
    } on FormatException {
      // A row the web saved as free text still has to list something.
    }
    return _commaList(text);
  }

  /// A `DateTime` column arrives as an ISO timestamp written in UTC, which is
  /// the day the user picked.
  DateTime? _asDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  String _dateText(Object? value) {
    final day = _asDate(value);
    return day == null ? '' : dateLabel(day);
  }
}
