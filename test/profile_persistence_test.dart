import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/core/network/session_store.dart';
import 'package:working_trust/core/storage/user_data_store.dart';
import 'package:working_trust/features/auth/controller/auth_controller.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';

import 'fake_backend.dart';

/// What happens to a saved profile when the app is closed, signed out of, or
/// handed to another account — and what a device that holds nothing at all can
/// put back from the server.
///
/// The identity comes from the session, the rest of the profile from
/// `GET /api/profile`, and the account's own document on this device is the
/// copy shown before that read answers.
final FakeBackend _backend = FakeBackend();
final ProfileController _profile = ProfileController.instance;

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

Uint8List get _photo => Uint8List.fromList(List<int>.filled(64, 7));

Future<void> _saveEverything() async {
  expect(
    await _profile.saveIdentity(
      title: 'Full-stack developer',
      hourlyRate: '25',
      bio: 'I build Flutter apps for marketplaces.',
    ),
    isTrue,
  );
  await _profile.saveSkills(['Flutter', 'Dart']);
  expect(
    await _profile.saveLanguage((id: '', name: 'German', level: 'Elementary')),
    isTrue,
  );
  expect(
    await _profile.saveEducation((id: '', institution: 'VU', degree: 'BS')),
    isTrue,
  );
  expect(
    await _profile.saveCertification((
      id: '',
      title: 'AWS',
      provider: 'Amazon',
      issued: 'Aug 2024',
      credentialId: 'c-1',
      description: '',
    )),
    isTrue,
  );
  expect(
    await _profile.saveEmployment((
      id: '',
      role: 'Engineer',
      company: 'Trust',
      period: 'Aug 2024 – Present',
      startDate: '2024-08-01',
      endDate: '',
      description: '',
    )),
    isTrue,
  );
  expect(await _profile.saveVideoIntro('https://youtu.be/demo'), isTrue);
}

void main() {
  setUp(() async {
    await _backend.install();
    _profile.clear();
  });

  group('restore after a sign-out', () {
    test(
      'the fields no endpoint can read come back for the same account',
      () async {
        await _signIn();
        await _saveEverything();
        await _signOut();
        expect(_profile.title, isEmpty);

        await _signIn();
        expect(_profile.userId, 'u1');
        expect(_profile.title, 'Full-stack developer');
        expect(_profile.hourlyRate, '25');
        expect(_profile.bio, 'I build Flutter apps for marketplaces.');
        expect(_profile.skills, ['Flutter', 'Dart']);
        expect(_profile.videoIntro, 'https://youtu.be/demo');
        expect(_profile.languages.single.name, 'German');
        expect(_profile.education.single.institution, 'VU');
        expect(_profile.certifications.single.title, 'AWS');
        expect(_profile.employment.single.company, 'Trust');
      },
    );

    test('a restored row can still be edited and removed', () async {
      await _signIn();
      await _profile.saveLanguage((
        id: '',
        name: 'German',
        level: 'Elementary',
      ));
      await _signOut();
      await _signIn();

      expect(_profile.languages.single.id, 'r1');
      expect(
        await _profile.saveLanguage((
          id: 'r1',
          name: 'German',
          level: 'Fluent',
        ), index: 0),
        isTrue,
      );
      expect(
        _backend.sectionRows['languages']!.single['proficiency'],
        'Fluent',
      );

      expect(await _profile.removeLanguage(0), isTrue);
      expect(_profile.languages, isEmpty);
      expect(_backend.sectionRows['languages'], isEmpty);

      // The removal is remembered too, so the row cannot reappear on a re-open.
      await _signOut();
      await _signIn();
      expect(_profile.languages, isEmpty);
    });

    test('identity comes from the session, not from the remembered document', () async {
      await _signIn();
      await _profile.saveIdentity(
        name: 'Replaced Name',
        title: 'Title',
        hourlyRate: '10',
        bio: '',
      );
      await _signOut();
      await _signIn();

      // The fake re-issues the session name from the database row, which is the
      // route's own write, and the document never holds a name at all.
      expect(_profile.name, 'Replaced Name');
      expect(_profile.title, 'Title');
    });

    test(
      'the photo survives a sign-in whose session reports no image',
      () async {
        await _signIn();
        expect(await _profile.uploadAvatar(_photo), isTrue);
        final url = _profile.avatarUrl;
        expect(url, 'https://cdn.example/avatar.jpg');
        await _signOut();

        await _signIn();
        // The session answered with `image: null`, and that did not clear it.
        expect(_backend.countOf('/api/auth/session'), greaterThan(0));
        expect(_profile.avatarUrl, url);
      },
    );

    test(
      'the photo the account stored wins over one the session reports',
      () async {
        await _signIn();
        await _profile.uploadAvatar(_photo);
        await _signOut();

        _backend.sessionImage = 'https://cdn.example/from-web.jpg';
        await _signIn();
        // The read answers with the account's `avatarUrl` column, which is the
        // photo the profile actually holds; a session image only stands in for
        // an account that never stored one.
        expect(_profile.avatarUrl, 'https://cdn.example/avatar.jpg');
      },
    );

    test('a session photo stands in when the account stored none', () async {
      await _signIn();
      _backend.sessionImage = 'https://cdn.example/from-web.jpg';
      await _profile.load(force: true);
      expect(_profile.avatarUrl, 'https://cdn.example/from-web.jpg');
    });

    test('a photo removed from the app stays removed', () async {
      await _signIn();
      await _profile.uploadAvatar(_photo);
      expect(await _profile.removeAvatar(), isTrue);
      expect(_profile.avatarUrl, isNull);
      await _signOut();

      await _signIn();
      expect(_profile.avatarUrl, isNull);
    });

    test('an empty session image never overwrites a saved URL', () async {
      await _signIn();
      await _profile.uploadAvatar(_photo);
      final url = _profile.avatarUrl;
      // A forced re-read of the same session must keep the URL.
      await _profile.load(force: true);
      expect(_profile.avatarUrl, url);
    });

    test('a photo the session reports is filed under the account', () async {
      await _signIn();
      _backend.sessionImage = 'https://cdn.example/from-web.jpg';
      await _profile.load(force: true);
      expect(_profile.avatarUrl, 'https://cdn.example/from-web.jpg');
      await _profile.saveIdentity(title: 'Title', hourlyRate: '10', bio: '');

      // A later sign-in whose session reports no image at all.
      _backend.sessionImage = null;
      await _signOut();
      await _signIn();
      expect(_profile.avatarUrl, 'https://cdn.example/from-web.jpg');
    });
  });

  group('what a reinstalled device restores', () {
    test('the whole profile comes back from the server', () async {
      await _signIn();
      await _saveEverything();
      await _profile.uploadAvatar(_photo);
      await _signOut();

      // What an uninstall leaves the account with on this device: no document
      // and no cookie, only an account that signs in again.
      UserDataStore.instance.useInMemoryStorage();
      await SessionStore.instance.clear();
      await _signIn();

      expect(_profile.userId, 'u1');
      expect(_profile.name, isNotEmpty);
      expect(_profile.email, isNotEmpty);
      expect(_profile.title, 'Full-stack developer');
      expect(_profile.hourlyRate, '25');
      expect(_profile.bio, 'I build Flutter apps for marketplaces.');
      expect(_profile.skills, ['Flutter', 'Dart']);
      expect(_profile.videoIntro, 'https://youtu.be/demo');
      expect(_profile.avatarUrl, 'https://cdn.example/avatar.jpg');
      expect(_profile.languages.single.name, 'German');
      expect(_profile.education.single.institution, 'VU');
      expect(_profile.certifications.single.title, 'AWS');
      expect(_profile.employment.single.company, 'Trust');
    });

    test('a restored row keeps the id that lets it be edited again', () async {
      await _signIn();
      await _profile.saveLanguage((
        id: '',
        name: 'German',
        level: 'Elementary',
      ));
      UserDataStore.instance.useInMemoryStorage();
      await SessionStore.instance.clear();
      await _signIn();

      expect(_profile.languages.single.id, 'r1');
      expect(
        await _profile.saveLanguage((
          id: 'r1',
          name: 'German',
          level: 'Fluent',
        ), index: 0),
        isTrue,
      );
      expect(
        _backend.sectionRows['languages']!.single['proficiency'],
        'Fluent',
      );
    });
  });

  group('one document per account', () {
    test('another account on the same device is shown nothing', () async {
      await _signIn();
      await _saveEverything();
      await _profile.uploadAvatar(_photo);
      await _signOut();

      await _signIn(as: 'u2');
      expect(_profile.userId, 'u2');
      expect(_profile.title, isEmpty);
      expect(_profile.bio, isEmpty);
      expect(_profile.skills, isEmpty);
      expect(_profile.languages, isEmpty);
      expect(_profile.portfolio, isEmpty);
      expect(_profile.videoIntro, isEmpty);
      expect(_profile.avatarUrl, isNull);
    });

    test('the first account gets its own document back', () async {
      await _signIn();
      await _saveEverything();
      await _signOut();

      await _signIn(as: 'u2');
      expect(_profile.languages, isEmpty);
      await _signOut();

      await _signIn();
      expect(_profile.languages.single.name, 'German');
    });
  });

  group('only what the server accepted is remembered', () {
    test('a link the route refuses is not stored', () async {
      await _signIn();
      expect(await _profile.saveVideoIntro('not a link'), isFalse);
      expect(_profile.videoIntro, isEmpty);
      expect(_profile.errorMessage, 'Enter a valid video link.');

      await _signOut();
      await _signIn();
      expect(_profile.videoIntro, isEmpty);
    });

    test(
      'a row the route refuses stays off the list and out of the document',
      () async {
        await _signIn();
        // The portfolio route needs a media URL, which this row does not have.
        expect(
          await _profile.publishPortfolio((
            title: 'No file',
            role: '',
            skills: const <String>[],
            description: '',
            link: '',
            status: 'PUBLISHED',
            kind: 'image',
            bytes: null,
            filename: '',
            mimeType: '',
          )),
          isFalse,
        );
        expect(_profile.portfolio, isEmpty);

        await _signOut();
        await _signIn();
        expect(_profile.portfolio, isEmpty);
      },
    );

    test(
      'a profile write the route rejects leaves the fields untouched',
      () async {
        await _signIn();
        await _profile.saveIdentity(
          title: 'Kept',
          hourlyRate: '20',
          bio: 'kept',
        );
        final before = _backend.countOf('/api/profile');
        expect(
          await _profile.saveIdentity(
            name:
                'A name that is far too long for the backend to accept because '
                'the profile schema caps it at eighty characters and this one has '
                'gone well past that limit.',
            title: 'Gone',
            hourlyRate: '99',
            bio: 'gone',
          ),
          isFalse,
        );
        expect(_backend.countOf('/api/profile'), before + 1);
        expect(_profile.title, 'Kept');
        expect(_profile.bio, 'kept');

        await _signOut();
        await _signIn();
        expect(_profile.title, 'Kept');
      },
    );

    test(
      'an expired session shows no profile, and the account gets it back',
      () async {
        await _signIn();
        await _saveEverything();

        _backend.sessionRevoked = true;
        await _profile.load(force: true);
        expect(_profile.status, ProfileStatus.signedOut);
        expect(_profile.name, isEmpty);
        expect(_profile.languages, isEmpty);
        expect(_profile.avatarUrl, isNull);

        _backend.sessionRevoked = false;
        // The expired read dropped the cookie it could no longer use, so the
        // account has to sign in again — and gets the same document back.
        _backend.issueSessionCookie();
        await _profile.load();
        expect(_profile.status, ProfileStatus.ready);
        expect(_profile.languages.single.name, 'German');
        expect(_profile.videoIntro, 'https://youtu.be/demo');
      },
    );

    test('a session that cannot be read leaves the document alone', () async {
      await _signIn();
      await _saveEverything();
      _backend.sessionBroken = true;
      await _profile.load(force: true);
      expect(_profile.status, ProfileStatus.failed);

      _backend.sessionBroken = false;
      await _profile.load(force: true);
      expect(_profile.languages.single.name, 'German');
    });
  });

  testWidgets('the profile screen lists restored rows', (tester) async {
    await _signIn();
    await _profile.saveLanguage((id: '', name: 'German', level: 'Elementary'));
    await _profile.saveIdentity(
      title: 'Full-stack developer',
      hourlyRate: '25',
      bio: 'Built from a restored document.',
    );
    await _signOut();
    expect(_profile.languages, isEmpty);

    await _signIn();
    final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
      ..remove(Navigator.defaultRouteName);
    tester.view.physicalSize = const Size(1200 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(routes: table, initialRoute: RouteNames.profile),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('German: Elementary'), findsOneWidget);
    expect(find.text('No languages yet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
