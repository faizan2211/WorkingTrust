import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/models/profile_entries.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

/// A project draft with the smallest file the media route accepts.
PortfolioDraft _draft({
  String status = 'PUBLISHED',
  String title = 'Orbita Design System',
  String mimeType = 'image/png',
  String kind = 'image',
  String filename = 'orbita.png',
  Uint8List? bytes,
}) => (
  title: title,
  role: 'Lead Designer',
  skills: const ['Figma', 'Design System'],
  description: 'A design system for a SaaS product.',
  link: 'https://orbita.app',
  status: status,
  kind: kind,
  bytes: bytes ?? Uint8List.fromList(utf8.encode('png-bytes')),
  filename: filename,
  mimeType: mimeType,
);

void main() {
  late ProfileController profile;

  setUp(() async {
    await _backend.install();
    _backend.issueSessionCookie();
    profile = ProfileController.instance..clear();
    await profile.load();
    expect(profile.isSignedIn, isTrue);
  });

  group('section writes', () {
    test('a new language is created and keeps the id the route returned', () async {
      final language = (id: '', name: 'German', level: 'B2');
      expect(await profile.saveLanguage(language), isTrue);
      expect(_backend.bodyFor('/api/profile/languages'), {
        'name': 'German',
        'proficiency': 'B2',
      });
      expect(profile.languages.single.id, 'r1');

      // An id is what tells the service to replace the row, not create another.
      expect(
        await profile.saveLanguage((
          id: 'r1',
          name: 'German',
          level: 'C1',
        ), index: 0),
        isTrue,
      );
      expect(profile.languages, hasLength(1));
      expect(profile.languages.single.level, 'C1');
      expect(_backend.paths, contains('/api/profile/languages/r1'));
      expect(_backend.countOf('/api/profile/languages'), 1);
    });

    test('education and employment rows use the backend field names', () async {
      expect(
        await profile.saveEducation((
          id: '',
          institution: 'Virtual University',
          degree: 'BS Software',
        )),
        isTrue,
      );
      expect(_backend.bodyFor('/api/profile/education'), {
        'school': 'Virtual University',
        'degree': 'BS Software',
      });

      final start = DateTime(2024, 8, 1);
      expect(
        await profile.saveEmployment((
          id: '',
          role: 'Product Designer',
          company: 'Frenco LTD',
          period: periodLabel(start, null),
          startDate: isoDate(start),
          endDate: '',
          description: 'Designs storefronts.',
        )),
        isTrue,
      );
      expect(_backend.bodyFor('/api/profile/employment'), {
        'title': 'Product Designer',
        'company': 'Frenco LTD',
        'startDate': '2024-08-01',
        'endDate': '',
        'description': 'Designs storefronts.',
      });
    });

    test(
      'a row the server does not know stays listed with the route message',
      () async {
        expect(
          await profile.saveCertification((
            id: '',
            title: 'Cloud Practitioner',
            provider: 'Amazon',
            issued: 'March 2026',
            credentialId: 'AWS-1',
            description: '',
          )),
          isTrue,
        );
        final saved = profile.certifications.single;
        // Pretend the row belongs to another device: the id is well-formed but
        // this account has no such record, which the route reads as missing.
        _backend.sectionRows['certifications']!.clear();

        expect(await profile.removeCertification(0), isFalse);
        expect(profile.errorMessage, 'Not found');
        expect(profile.certifications.single.id, saved.id);
      },
    );

    test('a signed-out device is refused before anything is listed', () async {
      profile.clear();
      expect(
        await profile.saveLanguage((id: '', name: 'Urdu', level: 'Native')),
        isFalse,
      );
      expect(profile.errorMessage, 'Sign in again to save this language.');
      expect(profile.languages, isEmpty);
      expect(_backend.countOf('/api/profile/languages'), 0);
    });

    test(
      'a session that ended server-side keeps the row off the profile',
      () async {
        _backend.sessionRevoked = true;
        expect(
          await profile.saveLanguage((id: '', name: 'Urdu', level: 'Native')),
          isFalse,
        );
        expect(profile.errorMessage, 'Unauthorized');
        expect(profile.languages, isEmpty);
        expect(_backend.countOf('/api/profile/languages'), 1);
      },
    );
  });

  group('portfolio', () {
    test(
      'the cover is uploaded first and the project points at its URL',
      () async {
        expect(await profile.publishPortfolio(_draft()), isTrue);
        final paths = _backend.paths;
        expect(
          paths.indexOf('/api/profile/portfolio/media'),
          lessThan(paths.indexOf('/api/profile/portfolio')),
        );
        final item = profile.portfolio.single;
        expect(item.id, isNotEmpty);
        expect(item.image, startsWith('https://cdn.example/'));
        expect(item.kind, 'image');
        expect(item.status, 'PUBLISHED');
        expect(_backend.bodyFor('/api/profile/portfolio'), {
          'title': 'Orbita Design System',
          'role': 'Lead Designer',
          'skills': ['Figma', 'Design System'],
          'description': 'A design system for a SaaS product.',
          'imageUrl': item.image,
          'mediaType': 'image',
          'linkUrl': 'https://orbita.app',
          'status': 'PUBLISHED',
        });
      },
    );

    test('a draft is stored with the DRAFT status', () async {
      expect(await profile.publishPortfolio(_draft(status: 'DRAFT')), isTrue);
      expect(profile.portfolio.single.status, 'DRAFT');
    });

    test('PDF and Word documents upload as portfolio media', () async {
      for (final (name, mimeType) in [
        ('case-study.pdf', 'application/pdf'),
        (
          'case-study.docx',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ]) {
        expect(
          await profile.publishPortfolio(
            _draft(
              title: 'Case Study ${name.split('.').last}',
              mimeType: mimeType,
              kind: 'file',
              filename: name,
            ),
          ),
          isTrue,
        );
      }

      expect(profile.portfolio, hasLength(2));
      expect(profile.portfolio.map((item) => item.kind), ['file', 'file']);
      expect(
        _backend.paths.where((path) => path == '/api/profile/portfolio/media'),
        hasLength(2),
      );
    });

    test(
      'a project is removed only after the backend confirms deletion',
      () async {
        expect(await profile.publishPortfolio(_draft()), isTrue);
        final id = profile.portfolio.single.id;

        expect(await profile.removePortfolio(0), isTrue);
        expect(profile.portfolio, isEmpty);
        expect(_backend.paths, contains('/api/profile/portfolio/$id'));
        expect(_backend.sectionRows['portfolio'], isEmpty);

        await profile.load(force: true);
        expect(profile.portfolio, isEmpty);
      },
    );

    test('a rejected portfolio deletion leaves the project visible', () async {
      expect(await profile.publishPortfolio(_draft()), isTrue);
      _backend.sectionRows['portfolio']!.clear();

      expect(await profile.removePortfolio(0), isFalse);
      expect(profile.errorMessage, 'Not found');
      expect(profile.portfolio, hasLength(1));
    });

    test('a file the media route refuses never becomes a project', () async {
      expect(
        await profile.publishPortfolio(_draft(mimeType: 'application/x-sh')),
        isFalse,
      );
      expect(profile.errorMessage, 'This media format is not supported.');
      expect(_backend.countOf('/api/profile/portfolio'), 0);
      expect(profile.portfolio, isEmpty);
    });

    group('linked accounts', () {
      test('links are saved and restored from the profile endpoint', () async {
        expect(
          await profile.saveLinkedAccounts(
            githubUrl: 'https://github.com/arslan',
            websiteUrl: 'https://example.com',
            youtubeUrl: 'https://youtube.com/@arslan',
          ),
          isTrue,
        );
        final body = _backend.bodyFor('/api/profile');
        expect(body, containsPair('githubUrl', 'https://github.com/arslan'));
        expect(body, containsPair('websiteUrl', 'https://example.com'));
        expect(body, containsPair('youtubeUrl', 'https://youtube.com/@arslan'));

        profile.clear();
        await profile.load();
        expect(profile.githubUrl, 'https://github.com/arslan');
        expect(profile.websiteUrl, 'https://example.com');
        expect(profile.youtubeUrl, 'https://youtube.com/@arslan');
      });

      test(
        'cached links remain visible when the profile cannot be read',
        () async {
          expect(
            await profile.saveLinkedAccounts(
              githubUrl: 'https://github.com/arslan',
              websiteUrl: '',
              youtubeUrl: '',
            ),
            isTrue,
          );
          profile.clear();
          _backend.profileReadBroken = true;

          await profile.load();

          expect(profile.githubUrl, 'https://github.com/arslan');
        },
      );

      test(
        'an invalid web address is rejected before the profile write',
        () async {
          expect(
            await profile.saveLinkedAccounts(
              githubUrl: 'github.com/arslan',
              websiteUrl: '',
              youtubeUrl: '',
            ),
            isFalse,
          );
          expect(profile.errorMessage, 'Enter a valid GitHub URL.');
          expect(_backend.countOf('/api/profile'), 1);
        },
      );
    });

    test('a title the route rejects is reported, not stored', () async {
      expect(await profile.publishPortfolio(_draft(title: 'O')), isFalse);
      expect(profile.errorMessage, 'Invalid portfolio data');
      expect(profile.portfolio, isEmpty);
    });
  });

  group('video intro', () {
    test('the link the route stored is the one the profile keeps', () async {
      expect(await profile.saveVideoIntro(' https://youtu.be/intro '), isTrue);
      expect(profile.videoIntro, 'https://youtu.be/intro');
      expect(_backend.storedVideoIntro, 'https://youtu.be/intro');

      expect(await profile.removeVideoIntro(), isTrue);
      expect(profile.videoIntro, isEmpty);
      expect(_backend.storedVideoIntro, isNull);
    });

    test('a link that is not an address is refused', () async {
      expect(await profile.saveVideoIntro('youtu.be/intro'), isFalse);
      expect(profile.errorMessage, 'Enter a valid video link.');
      expect(profile.videoIntro, isEmpty);
    });
  });

  group('date reading', () {
    test('picked dates become the ISO pair the route stores', () {
      expect(isoDate(DateTime(2024, 8, 1)), '2024-08-01');
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
      expect(dateLabel(DateTime(2026, 8, 10)), 'Aug 10, 2026');
      expect(
        periodLabel(DateTime(2024, 8, 1), DateTime(2026, 7, 1)),
        'Aug 1, 2024 – Jul 1, 2026',
      );
      // A blank end is a job still running, which is the route's own meaning of
      // an empty endDate.
      expect(periodLabel(DateTime(2024, 8, 1), null), 'Aug 1, 2024 – Present');
      expect(dateFromIso('2024-08-01'), DateTime(2024, 8, 1));
      expect(dateFromIso(''), isNull);
      expect(isoDateFromText('Summer twentytwentyfive'), isNull);
    });
  });
}
