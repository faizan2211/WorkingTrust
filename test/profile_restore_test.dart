import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/core/network/network_exceptions.dart';
import 'package:working_trust/core/network/session_store.dart';
import 'package:working_trust/core/storage/user_data_store.dart';
import 'package:working_trust/features/auth/controller/auth_controller.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/services/profile_service.dart';

import 'fake_backend.dart';

/// Restoring a complete profile through the one read the backend offers,
/// `GET /api/profile`.
///
/// These cover the cases a reinstalled phone actually hits: an account whose
/// data exists only in the database, an account that shares the device with
/// another, and a read that never arrives.
final FakeBackend _backend = FakeBackend();
final ProfileController _profile = ProfileController.instance;

/// The request counts this file reasons about: one read of the whole profile,
/// and nothing else.
int get _profileReads => _backend.requests
    .where((r) => r.method == 'GET' && r.url.path == '/api/profile')
    .length;

/// Puts a saved profile in the fake tables, in the columns the backend uses,
/// as if it had been written from the website rather than from this device.
void _seedSavedProfile() {
  _backend
    ..profileOwner = 'u1'
    ..storedTitle = 'Product designer'
    ..storedHourlyRate = 45
    ..storedBio = 'I design marketplaces end to end.'
    ..storedSkills = 'Figma, Design System'
    ..storedAvatarUrl = 'https://cdn.example/saved.jpg'
    ..storedVideoIntro = 'https://youtu.be/saved';
  _backend.seedSection('languages', [
    {'id': 'l1', 'name': 'German', 'proficiency': 'Elementary'},
  ]);
  _backend.seedSection('education', [
    {'id': 'd1', 'school': 'Virtual University', 'degree': 'BS'},
  ]);
  _backend.seedSection('certifications', [
    {
      'id': 'c1',
      'title': 'Cloud Architecture',
      'provider': 'Amazon',
      'issuedAt': '2024-08-01T00:00:00.000Z',
      'certificateId': 'AWS-99',
      'description': '',
    },
  ]);
  _backend.seedSection('employment', [
    {
      'id': 'e1',
      'title': 'Senior Engineer',
      'company': 'MilestoneZero',
      'startDate': '2024-08-01T00:00:00.000Z',
      'endDate': null,
      'description': 'Leads the design system.',
    },
  ]);
  _backend.seedSection('portfolio', [
    {
      'id': 'p1',
      'title': 'Frenco – Landing Page',
      'imageUrl': 'https://cdn.example/one.jpg',
      'mediaType': 'image',
      'linkUrl': 'https://frenco.example',
      'status': 'PUBLISHED',
      'role': 'Lead designer',
      'skills': ['Figma', 'UI/UX Design'],
      'description': '',
    },
  ]);
}

Future<void> _signIn({String as = 'u1'}) async {
  _backend.sessionId = as;
  _backend.issueSessionCookie();
  await _profile.load();
}

/// The sign-out the profile menu performs.
Future<void> _signOut() async {
  await AuthController().logout();
  _profile.clear();
}

/// Wipes everything an uninstall would take: the account's document and the
/// cookie it signed in with.
Future<void> _uninstall() async {
  UserDataStore.instance.useInMemoryStorage();
  await SessionStore.instance.clear();
}

void main() {
  setUp(() async {
    await _backend.install();
    _profile.clear();
  });

  group('one read for the whole profile', () {
    test('every section is filled from the server', () async {
      _seedSavedProfile();
      await _signIn();

      expect(_profile.status, ProfileStatus.ready);
      expect(_profile.title, 'Product designer');
      // A number column, shown as the text the rate field holds.
      expect(_profile.hourlyRate, '45');
      expect(_profile.bio, 'I design marketplaces end to end.');
      expect(_profile.skills, ['Figma', 'Design System']);
      expect(_profile.avatarUrl, 'https://cdn.example/saved.jpg');
      expect(_profile.videoIntro, 'https://youtu.be/saved');
      expect(_profile.languages.single.name, 'German');
      expect(_profile.languages.single.level, 'Elementary');
      expect(_profile.education.single.institution, 'Virtual University');
      expect(_profile.certifications.single.issued, 'Aug 1, 2024');
      expect(_profile.employment.single.role, 'Senior Engineer');
      expect(_profile.employment.single.startDate, '2024-08-01');
      expect(_profile.employment.single.period, 'Aug 1, 2024 – Present');
      expect(_profile.portfolio.single.skills, ['Figma', 'UI/UX Design']);
      expect(_profile.portfolio.single.image, 'https://cdn.example/one.jpg');
      expect(_profile.portfolio.single.kind, 'image');
    });

    test('rows the device never wrote can be addressed again', () async {
      _seedSavedProfile();
      await _signIn();

      expect(_profile.languages.single.id, 'l1');
      expect(
        await _profile.saveLanguage((
          id: 'l1',
          name: 'German',
          level: 'Fluent',
        ), index: 0),
        isTrue,
      );
      expect(
        _backend.sectionRows['languages']!.single['proficiency'],
        'Fluent',
      );
      expect(await _profile.removeEducation(0), isTrue);
      expect(_profile.education, isEmpty);
    });

    test('the profile arrives in one request, not one per section', () async {
      _seedSavedProfile();
      await _signIn();

      expect(_profileReads, 1);
      expect(
        _backend.paths.where((path) => path.startsWith('/api/profile/')),
        isEmpty,
      );
    });

    test('an account with nothing saved shows an empty profile', () async {
      await _signIn();

      expect(_profile.status, ProfileStatus.ready);
      expect(_profile.title, isEmpty);
      expect(_profile.hourlyRate, isEmpty);
      expect(_profile.skills, isEmpty);
      expect(_profile.languages, isEmpty);
      expect(_profile.portfolio, isEmpty);
    });

    test('two screens opened together cost one read', () async {
      _seedSavedProfile();
      await _signIn();
      final before = _profileReads;

      await Future.wait([_profile.load(), _profile.load()]);

      expect(_profileReads, before + 1);
    });
  });

  group('a device that holds nothing', () {
    test('a reinstall restores the profile from the server', () async {
      _seedSavedProfile();
      await _signIn();
      await _uninstall();
      await _signIn();

      expect(_profile.userId, 'u1');
      expect(_profile.title, 'Product designer');
      expect(_profile.bio, 'I design marketplaces end to end.');
      expect(_profile.avatarUrl, 'https://cdn.example/saved.jpg');
      expect(_profile.videoIntro, 'https://youtu.be/saved');
      expect(_profile.certifications.single.title, 'Cloud Architecture');
      expect(_profile.employment.single.company, 'MilestoneZero');
      expect(_profile.portfolio.single.title, 'Frenco – Landing Page');
    });

    test(
      'another account is never shown what the first account saved',
      () async {
        _seedSavedProfile();
        await _signIn();
        expect(_profile.title, 'Product designer');

        await _signOut();
        await _signIn(as: 'u2');

        expect(_profile.userId, 'u2');
        expect(_profile.title, isEmpty);
        expect(_profile.hourlyRate, isEmpty);
        expect(_profile.bio, isEmpty);
        expect(_profile.skills, isEmpty);
        expect(_profile.avatarUrl, isNull);
        expect(_profile.videoIntro, isEmpty);
        expect(_profile.languages, isEmpty);
        expect(_profile.education, isEmpty);
        expect(_profile.certifications, isEmpty);
        expect(_profile.employment, isEmpty);
        expect(_profile.portfolio, isEmpty);

        // The first account still reads its own profile back.
        await _signOut();
        await _signIn();
        expect(_profile.languages.single.name, 'German');
      },
    );

    test('a read that lands after the account moved on is dropped', () async {
      _seedSavedProfile();
      // The second account has a row of its own in the same table.
      _backend.sectionRows['languages']!.add({
        'id': 'l2',
        'userId': 'u2',
        'name': 'Urdu',
        'proficiency': 'Fluent',
      });
      _backend.issueSessionCookie();
      _backend.slowProfileRead = true;
      final outstanding = _profile.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      _profile.clear();
      _backend.slowProfileRead = false;
      _backend.sessionId = 'u2';
      _backend.issueSessionCookie();
      await _profile.load();
      // u1's answer is still outstanding. Give it something to show, so an
      // answer applied to the account that moved on would put u1's saved
      // profile on u2's screen.
      _backend.profileOwner = 'u2';
      await outstanding;

      expect(_profile.userId, 'u2');
      expect(_profile.title, isEmpty);
      expect(_profile.languages.single.name, 'Urdu');
    });
  });

  group('a read that does not answer', () {
    test('the cached profile stays on screen', () async {
      await _signIn();
      expect(
        await _profile.saveIdentity(
          title: 'Product designer',
          hourlyRate: '45',
          bio: 'I design marketplaces end to end.',
        ),
        isTrue,
      );
      expect(
        await _profile.saveLanguage((
          id: '',
          name: 'German',
          level: 'Elementary',
        )),
        isTrue,
      );
      await _signOut();

      _backend.profileReadBroken = true;
      await _signIn();

      expect(_profile.status, ProfileStatus.ready);
      expect(_profile.title, 'Product designer');
      expect(_profile.hourlyRate, '45');
      expect(_profile.bio, 'I design marketplaces end to end.');
      expect(_profile.languages.single.name, 'German');

      // The read failed, so the account is still signed in and the failure is
      // not shown as an empty profile.
      expect(_profile.errorMessage, isEmpty);

      _backend.profileReadBroken = false;
      await _profile.load(force: true);
      expect(_profile.title, 'Product designer');
      expect(_profile.languages.single.name, 'German');
    });

    test('a refused session is reported, not shown as an empty profile', () async {
      // No cookie at all: the route answers 401, and the app must not read that
      // as "nothing saved".
      await expectLater(
        ProfileService().fetchProfile(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(_profileReads, 1);
    });

    test('a body that is not a profile is refused', () async {
      _backend
        ..issueSessionCookie()
        ..profileReadMalformed = true;

      await expectLater(
        ProfileService().fetchProfile(),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            'The server did not return the saved profile.',
          ),
        ),
      );
    });
  });

  group('a save that changes one field', () {
    test('keeps every other value the server reported', () async {
      _seedSavedProfile();
      await _signIn();

      expect(
        await _profile.saveIdentity(
          title: 'Lead product designer',
          hourlyRate: _profile.hourlyRate,
          bio: _profile.bio,
        ),
        isTrue,
      );
      final body = _backend.bodyFor('/api/profile');
      expect(body['name'], isNotEmpty);
      expect(body['title'], 'Lead product designer');
      expect(body['skills'], 'Figma, Design System');
      expect(body['hourlyRate'], 45);
      expect(body['bio'], 'I design marketplaces end to end.');

      // And the untouched fields are still there after the next read.
      _backend.slowProfileRead = false;
      await _profile.load(force: true);
      expect(_profile.title, 'Lead product designer');
      expect(_profile.skills, ['Figma', 'Design System']);
      expect(_profile.hourlyRate, '45');
      expect(_profile.videoIntro, 'https://youtu.be/saved');
      expect(_profile.avatarUrl, 'https://cdn.example/saved.jpg');
    });

    test('a skill edit carries the identity the server holds', () async {
      _seedSavedProfile();
      await _signIn();

      await _profile.saveSkills(['Figma', 'Motion']);

      final body = _backend.bodyFor('/api/profile');
      expect(body['skills'], 'Figma, Motion');
      expect(body['title'], 'Product designer');
      expect(body['hourlyRate'], 45);
      expect(_profile.title, 'Product designer');
    });
  });
}
