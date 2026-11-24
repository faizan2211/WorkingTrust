import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/app.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/core/network/session_store.dart';
import 'package:working_trust/features/auth/screens/email_verification_screen.dart';
import 'package:working_trust/features/auth/screens/forgot_password_screen.dart';
import 'package:working_trust/features/auth/screens/login_screen.dart';
import 'package:working_trust/features/auth/screens/reset_password_screen.dart';
import 'package:working_trust/features/auth/screens/signup_screen.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/onboarding/screens/onboarding_screen.dart';

import 'fake_backend.dart';

const String _email = FakeBackend.validEmail;
const String _password = FakeBackend.validPassword;

const List<String> _registeredRoutes = [
  RouteNames.splash,
  RouteNames.onboarding,
  RouteNames.login,
  RouteNames.signup,
  RouteNames.forgotPassword,
  RouteNames.emailVerification,
  RouteNames.resetPassword,
  RouteNames.home,
  RouteNames.projectDetail,
  RouteNames.submitProposal,
  RouteNames.profile,
  RouteNames.editProfile,
  RouteNames.addPortfolio,
  RouteNames.overview,
  RouteNames.stats,
  RouteNames.wallet,
  RouteNames.transactions,
  RouteNames.proposals,
  RouteNames.yourReports,
  RouteNames.settings,
  RouteNames.membershipPlan,
  RouteNames.notifications,
  RouteNames.projectChat,
];

/// Enters the flow at [screen]; the tall surface keeps every signup field on
/// screen so taps never land off-view.
Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(360 * 3, 2000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: screen,
      // "/" belongs to the splash in the real app; it is `home` here.
      routes: Map.of(AppRoutes.routes)..remove(Navigator.defaultRouteName),
    ),
  );
  // Lets the signup screen's category request land.
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 2000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const App());
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Runs a button through its request and the route transition that follows.
Future<void> _tapButton(WidgetTester tester, String label) async {
  await _tap(tester, find.widgetWithText(ElevatedButton, label));
  await _settle(tester);
  expect(tester.takeException(), isNull, reason: label);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

/// [index] is which dropdown on the form: 0 country, 1 experience level. The
/// entry must be near the top of its menu, since the list is lazy.
Future<void> _choose(WidgetTester tester, int index, String label) async {
  final field = find.byType(DropdownButtonFormField<String>).at(index);
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.tap(field, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text(label), findsWidgets, reason: label);
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens the fields dropdown, ticks [name], then dismisses the sheet.
Future<void> _pickField(WidgetTester tester, String name) async {
  await _tap(tester, find.byTooltip('Choose fields'));
  await _settle(tester);
  await _tap(tester, find.text(name));
  await tester.pump();
  await _tap(tester, find.text('Done'));
  await _settle(tester);
}

Future<void> _fillSignupForm(WidgetTester tester, {String? email}) async {
  final fields = find.byType(TextField);
  await _type(tester, fields.at(0), 'Test User');
  await _type(tester, fields.at(1), email ?? 'newcomer@gmail.com');
  await _type(tester, fields.at(2), _password);
  await _choose(tester, 0, 'Afghanistan');
  await _type(tester, fields.at(3), 'Karachi');
  await _type(tester, fields.at(4), '75250');
  await _type(tester, fields.at(5), '3001234567');
  await _choose(tester, 1, 'Intermediate');
}

Future<void> _signIn(WidgetTester tester, String email, String password) async {
  final fields = find.byType(TextField);
  await _type(tester, fields.first, email);
  await _type(tester, fields.last, password);
  await _tapButton(tester, 'Sign in → continue payment');
}

void main() {
  final backend = FakeBackend();

  setUp(() => backend.install());

  tearDown(() async {
    await SessionStore.instance.clear();
  });

  test('every route referenced by the auth screens is registered', () {
    for (final route in _registeredRoutes) {
      expect(AppRoutes.routes.containsKey(route), isTrue, reason: route);
    }
    expect(AppRoutes.routes.length, _registeredRoutes.length);
  });

  testWidgets('the app widget hands its route map to MaterialApp', (
    tester,
  ) async {
    await _pumpApp(tester);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.initialRoute, RouteNames.splash);
    for (final route in _registeredRoutes) {
      expect(app.routes!.containsKey(route), isTrue, reason: route);
    }

    // Drain the splash timers so the test does not end with one pending.
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
  });

  testWidgets('signup posts exactly the fields /api/auth/register expects', (
    tester,
  ) async {
    await _pumpScreen(tester, const SignupScreen());
    await _fillSignupForm(tester);
    await _pickField(tester, 'Web Development');
    expect(tester.takeException(), isNull);

    await _tap(tester, find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();
    // The label swaps to a spinner and the button is disabled while the request
    // is in flight, so the same tap cannot register the account twice.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _settle(tester);
    expect(tester.takeException(), isNull);

    expect(backend.countOf('/api/auth/register'), 1);
    final body = backend.bodyFor('/api/auth/register');
    expect(body['name'], 'Test User');
    expect(body['email'], 'newcomer@gmail.com');
    expect(body['password'], _password);
    expect(body['experienceLevel'], 'INTERMEDIATE');
    expect(body['interestSlugs'], ['web-development']);
    expect(body['phone'], '+933001234567');
    expect(body['city'], 'Karachi');
    expect(body['country'], 'Afghanistan');
    expect(body['postalCode'], '75250');

    // Registration creates the account but never signs the device in.
    expect(backend.paths, isNot(contains('/api/auth/session')));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('Account created.'), findsOneWidget);
  });

  testWidgets('the fields dropdown lists the backend categories', (
    tester,
  ) async {
    await _pumpScreen(tester, const SignupScreen());
    await _tap(tester, find.byTooltip('Choose fields'));
    await _settle(tester);

    for (final category in FakeBackend.categories) {
      expect(find.text(category['name']!), findsOneWidget);
    }
  });

  testWidgets('a rejected registration shows the backend reason and stays', (
    tester,
  ) async {
    await _pumpScreen(tester, const SignupScreen());
    await _fillSignupForm(tester, email: FakeBackend.takenEmail);
    await _pickField(tester, 'Writing');

    await _tapButton(tester, 'Continue');

    expect(
      find.text('Email already registered. Please log in.'),
      findsOneWidget,
    );
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('signup blocks submission while required fields are empty', (
    tester,
  ) async {
    await _pumpScreen(tester, const SignupScreen());

    await _tapButton(tester, 'Continue');

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(backend.countOf('/api/auth/register'), 0);
  });

  testWidgets('an unselected field stops signup before any request', (
    tester,
  ) async {
    await _pumpScreen(tester, const SignupScreen());
    await _fillSignupForm(tester);

    await _tapButton(tester, 'Continue');

    expect(find.text('Pick at least one field to work in.'), findsOneWidget);
    expect(backend.countOf('/api/auth/register'), 0);
    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('login runs csrf, credentials callback and session in order', (
    tester,
  ) async {
    await _pumpScreen(tester, const LoginScreen());
    await _signIn(tester, _email, _password);

    // The shell mounts after the session lands, so only the handshake itself
    // is pinned here.
    expect(backend.paths.take(3).toList(), const [
      '/api/auth/csrf',
      '/api/auth/callback/credentials',
      '/api/auth/session',
    ]);

    final callback = backend.bodyFor('/api/auth/callback/credentials');
    expect(callback['csrfToken'], FakeBackend.csrfToken);
    expect(callback['email'], _email);
    expect(callback['password'], _password);
    expect(callback['json'], 'true');

    // The session is only proven once the cookie the callback set comes back.
    final sessionRequest = backend.requests.last;
    expect(
      sessionRequest.headers['cookie'],
      contains('next-auth.session-token=${FakeBackend.sessionCookieValue}'),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a rejected password keeps the user on login', (tester) async {
    await _pumpScreen(tester, const LoginScreen());
    await _signIn(tester, _email, 'wrongpassword');

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('an unverified account is told to check its email', (
    tester,
  ) async {
    await _pumpScreen(tester, const LoginScreen());
    await _signIn(tester, FakeBackend.unverifiedEmail, _password);

    expect(
      find.text('Please verify your email before logging in.'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsNothing);
    // A rejected callback is not followed by a session read.
    expect(backend.countOf('/api/auth/session'), 0);
  });

  testWidgets('a password shorter than the backend minimum is not sent', (
    tester,
  ) async {
    await _pumpScreen(tester, const LoginScreen());
    final fields = find.byType(TextField);
    await _type(tester, fields.first, _email);
    await _type(tester, fields.last, '12345');
    await _tap(
      tester,
      find.widgetWithText(ElevatedButton, 'Sign in → continue payment'),
    );

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  testWidgets('reopening with a saved session cookie lands on Home', (
    tester,
  ) async {
    backend.issueSessionCookie();
    await _pumpApp(tester);

    await tester.pump(const Duration(seconds: 4));
    await _settle(tester);

    expect(backend.paths, contains('/api/auth/session'));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('reopening without cookies shows the unauthenticated flow', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.pump(const Duration(seconds: 4));
    await _settle(tester);

    // No cookie means there is no session to ask about.
    expect(backend.paths, isNot(contains('/api/auth/session')));
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('an expired session falls back to the unauthenticated flow', (
    tester,
  ) async {
    // A cookie the backend no longer recognises must not open Home.
    SessionStore.instance.absorb([
      'next-auth.session-token=stale-jwt; Path=/; HttpOnly',
    ]);
    await _pumpApp(tester);

    await tester.pump(const Duration(seconds: 4));
    await _settle(tester);

    expect(backend.paths, contains('/api/auth/session'));
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
  });

  testWidgets('forgot password walks the recovery flow back to login', (
    tester,
  ) async {
    await _pumpScreen(tester, const LoginScreen());

    await _tap(tester, find.text('Forget Password?'));
    await _settle(tester);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);

    await _type(tester, find.byType(TextField), _email);
    await _tapButton(tester, 'Send OTP');

    // The OTP was emailed, so the very next screen is the six-digit entry —
    // there is no "check your inbox for a link" step on this backend.
    expect(
      find.text(
        'If an account exists with this email, a 6-digit verification code has been sent.',
      ),
      findsOneWidget,
    );
    expect(find.byType(EmailVerificationScreen), findsOneWidget);
    expect(
      find.textContaining('som'),
      findsWidgets,
      reason: 'email carried over',
    );
    expect(backend.bodyFor('/api/auth/forgot-password')['email'], _email);

    // A wrong code is refused by the backend and stays put.
    await _type(tester, find.byType(TextField), '999999');
    await _tapButton(tester, 'Verify & Continue');
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(
      find.text('This OTP is incorrect. Please try again.'),
      findsOneWidget,
    );

    await _type(tester, find.byType(TextField), FakeBackend.validOtp);
    await _tapButton(tester, 'Verify & Continue');
    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    final verified = backend.bodyFor('/api/auth/verify-otp');
    expect(verified['email'], _email);
    expect(verified['otp'], FakeBackend.validOtp);

    // Mismatched passwords must not navigate away.
    await _type(tester, find.byType(TextField).first, 'brandnew1');
    await _type(tester, find.byType(TextField).last, 'different1');
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Reset Password'));
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await _type(tester, find.byType(TextField).last, 'brandnew1');
    await _tapButton(tester, 'Reset Password');

    expect(
      backend.bodyFor('/api/auth/reset-password')['token'],
      FakeBackend.resetToken,
    );
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Password reset successfully. Please log in.'),
      findsOneWidget,
    );
  });

  testWidgets('the Google button cannot sign in a device with no Google SDK', (
    tester,
  ) async {
    await _pumpScreen(tester, const LoginScreen());

    await _tap(
      tester,
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    await _settle(tester);

    // A test device has no Google app to ask, so the sign-in must fail on the
    // spot: no request leaves the device, and no cookie is claimed.
    expect(backend.requests, isEmpty);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('signup keeps its Google button beside the form', (tester) async {
    await _pumpScreen(tester, const SignupScreen());

    await _tap(
      tester,
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
    );
    await _settle(tester);

    expect(backend.countOf('/api/auth/register'), 0);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
