import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/app.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/auth/screens/login_screen.dart';
import 'package:working_trust/features/onboarding/screens/onboarding_screen.dart';

const String _photoUrl =
    'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=600&h=300&fit=crop';

final Finder _photo = find.image(const NetworkImage(_photoUrl));

/// Advances past the splash timers and the route transition, asserting no
/// exception at each step. The splash only routes once its 4s timer AND the
/// stored-session read have both landed, and that read resolves on the real
/// event loop, so this stays tolerant about which screen ends up mounted.
Future<void> _settleIntoOnboarding(WidgetTester tester) async {
  await tester.pumpWidget(const App());
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 3));
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull, reason: 'transition frame $i');
  }
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.takeException(), isNull, reason: 'after marquee start');
}

/// Mounts the onboarding flow directly, so the screen tests do not depend on
/// how quickly the splash's session read happens to resolve. The pager keeps
/// its real routes, so "Get Started" and "Skip" still land on login.
Future<void> _mountOnboarding(WidgetTester tester) async {
  // Clear the tree first: re-pumping the same widget type would reuse the
  // pager's State and carry its current page into the next mount.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {RouteNames.login: (context) => const LoginScreen()},
      home: const OnboardingScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byType(OnboardingScreen), findsOneWidget);
  expect(tester.takeException(), isNull, reason: 'after marquee start');
}

/// The twelve tiles the services page shows before "All services" is tapped.
const List<String> _featuredLabels = [
  'UI/UX Design',
  'AI Development',
  'Web Development',
  'Data Analysis',
  'Backend Development',
  'App Development',
  'Machine Learning',
  'WordPress',
  'Video Editor',
  'SEO',
  'Graphics Design',
  'Shopify',
];

/// The remaining fifteen, only built once the catalogue is expanded.
const List<String> _restLabels = [
  '3D Modeling',
  'Affiliate Marketing',
  'Accounting',
  'Amazon / Daraz',
  'YouTube',
  'Framer',
  'API Integration',
  'Cybersecurity',
  'App Testing',
  'Chatbots & Automation',
  'Content Writing',
  'Google Ads',
  'Motion Graphics',
  'No-Code Development',
  'AI Agents',
];

const List<String> _serviceLabels = [..._featuredLabels, ..._restLabels];

/// Labels that also live in the logo marquee, so they can never be used to
/// prove a service tile is absent.
const List<String> _marqueeLogos = [
  'Google',
  'Webflow',
  'YouTube',
  'Pinterest',
  'Facebook',
];

/// Swipes the pager forward the given number of pages.
Future<void> _swipeForward(WidgetTester tester, int pages) async {
  final screenWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (int i = 0; i < pages; i++) {
    // A plain drag, unlike a fling, advances exactly one page: the release
    // velocity of a fling can carry the pager past the next snap point.
    await tester.drag(find.byType(PageView), Offset(-screenWidth * 0.8, 0));
    for (int frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull, reason: 'after swipe ${i + 1}');
  }
}

/// Steps the pager forward with the footer's own Next button, which is the
/// only width-independent way to land on an exact page.
Future<void> _advance(WidgetTester tester, int pages) async {
  for (int i = 0; i < pages; i++) {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    for (int frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull, reason: 'after Next ${i + 1}');
  }
}

void main() {
  testWidgets('splash -> onboarding transition captures exceptions', (
    tester,
  ) async {
    await _settleIntoOnboarding(tester);

    // Run the marquee animation for a while to catch rebuild/layout issues.
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'marquee frame $i');
    }
  });

  testWidgets('typing intro plays first, then the photo appears', (
    tester,
  ) async {
    await _mountOnboarding(tester);
    expect(find.text('CLIENT IS TYPING...'), findsOneWidget);
    expect(_photo, findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull, reason: 'after typing intro');
    expect(find.text('CLIENT IS TYPING...'), findsNothing);
    expect(_photo, findsOneWidget);
  });

  testWidgets('marquee is full-bleed and labels every logo', (tester) async {
    await _mountOnboarding(tester);

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final rect = tester.getRect(find.byType(MarqueeBanner));
    expect(rect.left, 0);
    expect(rect.width, screenWidth);
    final next = tester.getRect(find.widgetWithText(ElevatedButton, 'Next'));
    expect(next.top - rect.bottom, inInclusiveRange(8, 24));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(rect.top, greaterThan(screenHeight * 0.7));

    for (final label in [
      'Google',
      'Webflow',
      'YouTube',
      'Pinterest',
      'Facebook',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('hero footer stays reachable on small and wide screens', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final width in [320.0, 700.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      await _mountOnboarding(tester);
      final banner = tester.getRect(find.byType(MarqueeBanner));
      final next = find.widgetWithText(ElevatedButton, 'Next');
      expect(tester.getRect(next).bottom, lessThanOrEqualTo(640));
      expect(banner.bottom, lessThan(tester.getRect(next).top));
      await _advance(tester, 1);
      expect(find.byType(MarqueeBanner), findsNothing);
      await tester.drag(find.byType(PageView), Offset(width * 0.8, 0));
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MarqueeBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('services page shows twelve crafts, then the whole catalogue', (
    tester,
  ) async {
    // 320dp is the narrowest phone. The tall surface keeps every tile inside
    // the grid's cache extent so all of them get built.
    tester.view.physicalSize = const Size(320 * 3, 2000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _mountOnboarding(tester);
    await _swipeForward(tester, 1);

    for (final label in _featuredLabels) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    for (final label in _restLabels.where((l) => !_marqueeLogos.contains(l))) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('Pick your craft.'), findsOneWidget);
    expect(find.text('12 shown'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'layout at 320dp');

    await tester.tap(find.text('All services · 15 more'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    for (final label in _serviceLabels) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('27 shown'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'expanded at 320dp');
  });

  testWidgets('filtering and selecting services feeds the count bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _mountOnboarding(tester);
    await _swipeForward(tester, 1);

    await tester.enterText(find.byType(TextField), 'design');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 shown'), findsOneWidget);
    expect(find.text('UI/UX Design'), findsWidgets);
    expect(find.text('Graphics Design'), findsOneWidget);
    expect(find.text('SEO'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('SEO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 selected · carried into Find Work'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1 selected · carried into Find Work'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('safety page animates the escrow timeline', (tester) async {
    await _mountOnboarding(tester);
    await _advance(tester, 2);

    for (final stage in ['Brief', 'Match', 'Escrow', 'Deliver', 'Paid']) {
      expect(find.text(stage), findsOneWidget, reason: stage);
    }
    for (final title in [
      'Clear Projects',
      'Local Payments',
      'Guided Support',
      'Fair Selection',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    await tester.pump(const Duration(milliseconds: 1800));
    expect(tester.takeException(), isNull, reason: 'after timeline run');
  });

  testWidgets('onboarding paging and navigation to login', (tester) async {
    await _mountOnboarding(tester);

    // Page 1 -> 2 with the footer button, then the last step by swipe.
    await _advance(tester, 1);
    await _swipeForward(tester, 1);

    // Last page: button reads "Get Started" and navigates to login.
    final getStarted = find.widgetWithText(ElevatedButton, 'Get Started');
    expect(getStarted, findsOneWidget);
    await tester.tap(getStarted);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'after Get Started');
    expect(find.text('Welcome Back To\nWorkingTrust.'), findsOneWidget);
  });

  testWidgets('onboarding skip navigates to login', (tester) async {
    await _mountOnboarding(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'after Skip');
    expect(find.text('Welcome Back To\nWorkingTrust.'), findsOneWidget);
  });

  testWidgets('services and safety pages survive the 320/700/1200 sweep', (
    tester,
  ) async {
    for (final width in [320, 700, 1200]) {
      tester.view.physicalSize = Size(width * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _mountOnboarding(tester);
      await _advance(tester, 1);

      await tester.tap(find.text('All services · 15 more'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('27 shown'), findsOneWidget, reason: '${width}dp grid');
      expect(tester.takeException(), isNull, reason: 'services at ${width}dp');

      await _advance(tester, 1);
      expect(find.text('Paid'), findsOneWidget, reason: '${width}dp timeline');
      expect(tester.takeException(), isNull, reason: 'safety at ${width}dp');
    }
  });
}
