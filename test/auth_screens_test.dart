import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/core/constants/countries.dart';
import 'package:working_trust/features/auth/screens/email_verification_screen.dart';
import 'package:working_trust/features/auth/screens/forgot_password_screen.dart';
import 'package:working_trust/features/auth/screens/login_screen.dart';
import 'package:working_trust/features/auth/screens/reset_password_screen.dart';
import 'package:working_trust/features/auth/screens/signup_screen.dart';

import 'fake_backend.dart';

Future<void> _pumpAtWidth(
  WidgetTester tester,
  Widget screen, {
  double width = 320,
  double height = 900,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // The app's "/" route is the splash; `home` replaces it here.
  await tester.pumpWidget(
    MaterialApp(
      home: screen,
      routes: Map.of(AppRoutes.routes)..remove(Navigator.defaultRouteName),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  // The signup screen asks the backend for categories as it opens.
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
}

Future<void> _pumpNarrow(WidgetTester tester, Widget screen) async {
  await _pumpAtWidth(tester, screen);
}

void main() {
  final backend = FakeBackend();

  setUp(() => backend.install());

  test('country list is complete and has unique names', () {
    expect(kCountries.length, greaterThan(200));
    expect(kCountries.map((c) => c.name).toSet().length, kCountries.length);
    expect(
      kCountries.any((c) => c.name == 'Pakistan' && c.dial == '+92'),
      isTrue,
    );
    expect(
      kCountries.any((c) => c.name == 'Zimbabwe' && c.dial == '+263'),
      isTrue,
    );
    expect(
      kCountries.any((c) => c.name == 'United States' && c.dial == '+1'),
      isTrue,
    );
  });

  testWidgets('login renders on a 320dp wide screen without clipping', (
    tester,
  ) async {
    await _pumpNarrow(tester, const LoginScreen());

    final button = find.widgetWithText(
      ElevatedButton,
      'Sign in → continue payment',
    );
    expect(button, findsOneWidget);

    // The label must stay inside the button, so it scales down instead of
    // being cut off.
    final buttonRect = tester.getRect(button);
    final labelRect = tester.getRect(find.byType(FittedBox));
    expect(labelRect.left, greaterThanOrEqualTo(buttonRect.left));
    expect(labelRect.right, lessThanOrEqualTo(buttonRect.right));
  });

  testWidgets('signup country dropdown opens with the full list', (
    tester,
  ) async {
    await _pumpNarrow(tester, const SignupScreen());

    final countryField = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(countryField);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(countryField);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    // Menu opens on the first entry of the full list.
    expect(find.text('Afghanistan'), findsWidgets);

    // Picking a country also switches the phone dial code.
    await tester.tap(find.text('Afghanistan').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('+93'), findsOneWidget);
  });

  testWidgets('signup keeps its shape from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _pumpAtWidth(
        tester,
        const SignupScreen(),
        width: width,
        height: width <= 360 ? 900 : 1400,
      );

      // The fields dropdown opens on the backend categories, so they only
      // exist once it answers and the menu is expanded.
      final trigger = find.byTooltip('Choose fields');
      await tester.ensureVisible(trigger);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Graphic Design'), findsOneWidget, reason: '${width}dp');
      expect(tester.takeException(), isNull, reason: '${width}dp');
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 400));
    }
  });

  testWidgets('forgot password asks only for an email, then sends an OTP', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      const ForgotPasswordScreen(),
      width: 360,
      height: 740,
    );

    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // This backend resets with an emailed code, never a link, so no wording or
    // extra step about a link may survive here.
    expect(find.textContaining('link'), findsNothing);
    expect(find.text('Check Your Email'), findsNothing);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(backend.countOf('/api/auth/forgot-password'), 0);

    await tester.enterText(find.byType(TextField), 'someone@gmail.com');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      backend.bodyFor('/api/auth/forgot-password')['email'],
      'someone@gmail.com',
    );
    expect(find.byType(EmailVerificationScreen), findsOneWidget);
  });

  testWidgets('email verification drives the six boxes and opens reset', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      const EmailVerificationScreen(email: 'someone@gmail.com'),
      width: 360,
      height: 740,
    );

    expect(
      find.text(
        'Enter 6-Digit OTP sent to som****ne@gmail.com',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Resend in 00:30'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('Enter the 6-digit code we sent you'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(find.text('Enter the 6-digit code we sent you'), findsNothing);
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget, reason: 'box $digit');
    }

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(backend.countOf('/api/auth/verify-otp'), 1);
    expect(find.text('Create New Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('reset password validates before returning to login', (
    tester,
  ) async {
    await _pumpAtWidth(
      tester,
      const ResetPasswordScreen(resetToken: FakeBackend.resetToken),
      height: 740,
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'newpass123');
    await tester.enterText(find.byType(TextField).last, 'mismatch123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'newpass123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome Back To\nWorkingTrust.'), findsOneWidget);
  });
}
