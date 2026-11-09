import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/core/utils/link_opener.dart';
import 'package:working_trust/core/utils/validators.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/models/video_intro.dart';
import 'package:working_trust/features/profile/widgets/profile_details_section.dart';

import 'fake_backend.dart';

const _introPath = '/api/profile/video-intro';

final FakeBackend _backend = FakeBackend();

/// Every address the app tried to hand to the device, in order.
final List<Uri> _launched = [];

late Future<bool> Function(Uri) _realLaunch;

Future<void> _pumpSection(WidgetTester tester, {double width = 400}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ProfileDetailsSection(columns: 1)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => _realLaunch = LinkOpener.launch);
  setUp(() async {
    await _backend.install();
    _backend.issueSessionCookie();
    ProfileController.instance.clear();
    await ProfileController.instance.load();
    _launched.clear();
    LinkOpener.launch = (uri) async {
      _launched.add(uri);
      return true;
    };
  });
  tearDown(() => LinkOpener.launch = _realLaunch);

  group('link rules', () {
    test('the same addresses the route accepts are accepted here', () {
      expect(Validators.isWebAddress('https://youtu.be/abc123'), isTrue);
      expect(Validators.isWebAddress('http://10.0.0.4:8080/intro.mp4'), isTrue);
      expect(Validators.isWebAddress('https://vimeo.com/76979871'), isTrue);
    });

    test('a link with no scheme or host is refused before the round trip', () {
      for (final link in [
        'youtu.be/abc123',
        'ftp://videos/intro.mp4',
        'https://',
        'just some words',
      ]) {
        expect(Validators.isWebAddress(link), isFalse, reason: link);
        expect(
          Validators.videoLink(link),
          'Enter a valid video link.',
          reason: link,
        );
      }
      expect(Validators.videoLink(' https://youtu.be/abc123 '), isNull);
      expect(Validators.videoLink(''), isNull);
    });
  });

  group('poster', () {
    test('a YouTube address gives the still the web card uses', () {
      expect(
        videoPosterUrl('https://youtu.be/dQw4w9WgXcQ'),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
      for (final link in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://m.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1',
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/live/dQw4w9WgXcQ',
      ]) {
        expect(
          videoPosterUrl(link),
          'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
          reason: link,
        );
      }
    });

    test('a Vimeo id gives its still', () {
      expect(
        videoPosterUrl('https://vimeo.com/76979871'),
        'https://vumbnail.com/76979871.jpg',
      );
      expect(
        videoPosterUrl('https://player.vimeo.com/video/76979871'),
        'https://vumbnail.com/76979871.jpg',
      );
    });

    test('a direct file link has no poster, which is not an error', () {
      expect(videoPosterUrl('https://cdn.example.com/intro.mp4'), isNull);
      expect(videoPosterUrl('https://example.com/watch'), isNull);
      expect(videoPosterUrl('not a link'), isNull);
      expect(videoPosterUrl(''), isNull);
    });
  });

  group('opening', () {
    test(
      'the stored address is handed over exactly, never rewritten',
      () async {
        for (final link in [
          'https://youtu.be/dQw4w9WgXcQ',
          'https://vimeo.com/76979871',
          'https://cdn.example.com/intro.mp4',
        ]) {
          _launched.clear();
          expect(await LinkOpener.open('  $link  '), isNull, reason: link);
          expect(_launched.single.toString(), link, reason: link);
        }
      },
    );

    test('a link that is not an address never reaches the device', () async {
      expect(await LinkOpener.open('youtu.be/dQw4w9WgXcQ'), isNotNull);
      expect(_launched, isEmpty);
    });

    test('a device with no app for the link says so', () async {
      LinkOpener.launch = (uri) async => false;
      expect(
        await LinkOpener.open('https://cdn.example.com/intro.mp4'),
        'No app on this device can open that link.',
      );
    });

    test('a launcher that throws is reported, not rethrown', () async {
      LinkOpener.launch = (uri) async => throw StateError('no channel');
      expect(
        await LinkOpener.open('https://youtu.be/dQw4w9WgXcQ'),
        'The link could not be opened.',
      );
    });
  });

  group('stored link', () {
    const link = 'https://youtu.be/dQw4w9WgXcQ';

    test('a link the route refuses leaves the one already stored', () async {
      expect(
        await ProfileController.instance.saveVideoIntro(
          'https://vimeo.com/76979871',
        ),
        isTrue,
      );
      expect(
        await ProfileController.instance.saveVideoIntro('youtu.be/dQw4w9WgXcQ'),
        isFalse,
      );
      expect(
        ProfileController.instance.errorMessage,
        'Enter a valid video link.',
      );
      expect(
        ProfileController.instance.videoIntro,
        'https://vimeo.com/76979871',
      );
      expect(_backend.storedVideoIntro, 'https://vimeo.com/76979871');
    });

    test('a remove the server refuses keeps the link', () async {
      expect(await ProfileController.instance.saveVideoIntro(link), isTrue);
      _backend.sessionRevoked = true;
      expect(await ProfileController.instance.removeVideoIntro(), isFalse);
      expect(ProfileController.instance.videoIntro, link);
    });
  });

  group('card', () {
    Future<void> tapPoster(WidgetTester tester, String link) async {
      await tester.tap(find.byTooltip('Video intro • $link'));
      await tester.pump();
    }

    testWidgets('a YouTube card hands over the YouTube address, not a still', (
      tester,
    ) async {
      const link = 'https://youtu.be/dQw4w9WgXcQ';
      await ProfileController.instance.saveVideoIntro(link);
      await _pumpSection(tester);
      await tapPoster(tester, link);
      expect(_launched.single.toString(), link);
    });

    testWidgets('a Vimeo card opens the Vimeo address', (tester) async {
      const link = 'https://vimeo.com/76979871';
      await ProfileController.instance.saveVideoIntro(link);
      await _pumpSection(tester);
      await tapPoster(tester, link);
      expect(_launched.single.toString(), link);
    });

    testWidgets('a direct video file opens the file itself', (tester) async {
      const link = 'https://cdn.example.com/intro.mp4';
      await ProfileController.instance.saveVideoIntro(link);
      await _pumpSection(tester);
      await tapPoster(tester, link);
      expect(_launched.single.toString(), link);
    });

    testWidgets('a device that cannot open it says so on the card', (
      tester,
    ) async {
      const link = 'https://cdn.example.com/intro.mp4';
      await ProfileController.instance.saveVideoIntro(link);
      LinkOpener.launch = (uri) async => false;
      await _pumpSection(tester);
      await tapPoster(tester, link);
      expect(
        find.text('No app on this device can open that link.'),
        findsOneWidget,
      );
    });

    testWidgets('the form refuses a non-address without asking the server', (
      tester,
    ) async {
      await _pumpSection(tester);
      await tester.tap(find.text('Add video intro'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Paste a video link');

      await tester.enterText(field, 'youtu.be/dQw4w9WgXcQ');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter a valid video link.'), findsOneWidget);
      expect(_backend.countOf(_introPath), 0);

      await tester.enterText(field, ' https://youtu.be/dQw4w9WgXcQ ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        _backend.bodyFor(_introPath)['url'],
        'https://youtu.be/dQw4w9WgXcQ',
      );
      expect(
        ProfileController.instance.videoIntro,
        'https://youtu.be/dQw4w9WgXcQ',
      );
    });
  });
}
