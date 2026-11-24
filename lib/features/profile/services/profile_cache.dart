import '../../../core/storage/user_data_store.dart';
import '../models/profile_entries.dart';

/// The profile document one account keeps on this device.
///
/// It is a copy of what the server last said — every row carries the id its
/// route gave it — so a sign-in can show the profile before `GET /api/profile`
/// answers, and an account with no connection still sees its own data. The
/// server's read replaces it on every successful fetch.
class ProfileCache {
  ProfileCache._();

  static final ProfileCache instance = ProfileCache._();

  static const String _collection = 'profile';

  /// The document for [userId], or null the first time an account is opened on
  /// this device.
  Future<ProfileSnapshot?> restore(String userId) async {
    final document = await UserDataStore.instance.read(_collection, userId);
    return document == null ? null : _decode(document);
  }

  Future<void> save(String userId, ProfileSnapshot snapshot) =>
      UserDataStore.instance.write(_collection, userId, _encode(snapshot));

  /// Used when the account's own data should not outlive it.
  Future<void> forget(String userId) =>
      UserDataStore.instance.forget(_collection, userId);

  Map<String, dynamic> _encode(ProfileSnapshot snapshot) => {
    'title': snapshot.title,
    'hourlyRate': snapshot.hourlyRate,
    'bio': snapshot.bio,
    'skills': snapshot.skills,
    'avatarUrl': snapshot.avatarUrl,
    'videoIntro': snapshot.videoIntro,
    'githubUrl': snapshot.githubUrl,
    'websiteUrl': snapshot.websiteUrl,
    'youtubeUrl': snapshot.youtubeUrl,
    'languages': [
      for (final row in snapshot.languages)
        {'id': row.id, 'name': row.name, 'level': row.level},
    ],
    'education': [
      for (final row in snapshot.education)
        {'id': row.id, 'institution': row.institution, 'degree': row.degree},
    ],
    'certifications': [
      for (final row in snapshot.certifications)
        {
          'id': row.id,
          'title': row.title,
          'provider': row.provider,
          'issued': row.issued,
          'credentialId': row.credentialId,
          'certificateUrl': row.certificateUrl,
          'description': row.description,
        },
    ],
    'employment': [
      for (final row in snapshot.employment)
        {
          'id': row.id,
          'role': row.role,
          'company': row.company,
          'period': row.period,
          'startDate': row.startDate,
          'endDate': row.endDate,
          'description': row.description,
        },
    ],
    'portfolio': [
      for (final row in snapshot.portfolio)
        {
          'id': row.id,
          'title': row.title,
          'image': row.image,
          'kind': row.kind,
          'link': row.link,
          'status': row.status,
          'role': row.role,
          'skills': row.skills,
          'description': row.description,
        },
    ],
  };

  ProfileSnapshot _decode(Map<String, dynamic> document) => (
    title: _text(document['title']),
    hourlyRate: _text(document['hourlyRate']),
    bio: _text(document['bio']),
    skills: _list(document['skills']),
    avatarUrl: _text(document['avatarUrl']),
    videoIntro: _text(document['videoIntro']),
    githubUrl: _text(document['githubUrl']),
    websiteUrl: _text(document['websiteUrl']),
    youtubeUrl: _text(document['youtubeUrl']),
    languages: [
      for (final row in _rows(document['languages']))
        if (_text(row['name']).isNotEmpty)
          (
            id: _text(row['id']),
            name: _text(row['name']),
            level: _text(row['level']),
          ),
    ],
    education: [
      for (final row in _rows(document['education']))
        if (_text(row['institution']).isNotEmpty)
          (
            id: _text(row['id']),
            institution: _text(row['institution']),
            degree: _text(row['degree']),
          ),
    ],
    certifications: [
      for (final row in _rows(document['certifications']))
        if (_text(row['title']).isNotEmpty)
          (
            id: _text(row['id']),
            title: _text(row['title']),
            provider: _text(row['provider']),
            issued: _text(row['issued']),
            credentialId: _text(row['credentialId']),
            certificateUrl: _text(row['certificateUrl']),
            description: _text(row['description']),
          ),
    ],
    employment: [
      for (final row in _rows(document['employment']))
        if (_text(row['role']).isNotEmpty)
          (
            id: _text(row['id']),
            role: _text(row['role']),
            company: _text(row['company']),
            period: _text(row['period']),
            startDate: _text(row['startDate']),
            endDate: _text(row['endDate']),
            description: _text(row['description']),
          ),
    ],
    portfolio: [
      for (final row in _rows(document['portfolio']))
        if (_text(row['title']).isNotEmpty)
          (
            id: _text(row['id']),
            title: _text(row['title']),
            image: _text(row['image']),
            kind: _text(row['kind']),
            link: _text(row['link']),
            status: _text(row['status']),
            role: _text(row['role']),
            skills: _list(row['skills']),
            description: _text(row['description']),
          ),
    ],
  );

  /// A row is only restorable if the backend gave it an id; without one it
  /// could never be edited or removed again.
  List<Map<String, dynamic>> _rows(Object? value) => [
    if (value is List)
      for (final row in value)
        if (row is Map<String, dynamic> && _text(row['id']).isNotEmpty) row,
  ];

  List<String> _list(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is String) item,
  ];

  String _text(Object? value) => value is String ? value : '';
}
