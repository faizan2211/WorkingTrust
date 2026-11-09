import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/core/network/session_store.dart';
import 'package:working_trust/features/auth/controller/auth_controller.dart';
import 'package:working_trust/features/auth/models/experience_level.dart';
import 'package:working_trust/features/auth/services/google_sign_in_service.dart';

import 'fake_backend.dart';

/// Google's own consent sheet answers through the injected supplier: a test has
/// no platform channel to call, so the SDK would hang. Everything after the ID
/// token — the POST, the session cookie, the jar and the read-back — is the
/// app's real code against [FakeBackend].
void main() {
  final backend = FakeBackend();

  setUp(() => backend.install());

  tearDown(() async {
    await SessionStore.instance.clear();
  });

  AuthController controllerWithToken(Future<String> Function() token) =>
      AuthController(googleIdToken: token);

  test('an ID token becomes the session cookie and a read-back session', () async {
    final controller = controllerWithToken(
      () async => FakeBackend.validGoogleIdToken,
    );

    expect(await controller.signInWithGoogle(), isTrue);

    expect(controller.status, AuthStatus.success);
    expect(controller.errorMessage, isEmpty);
    expect(controller.user?.email, FakeBackend.validEmail);
    expect(controller.isAuthenticated, isTrue);

    // The token is the only thing the device sends; the backend decides who the
    // user is, and the app believes the session it reads back.
    expect(backend.paths, ['/api/auth/mobile-google', '/api/auth/session']);
    expect(
      backend.bodyFor('/api/auth/mobile-google')['idToken'],
      FakeBackend.validGoogleIdToken,
    );
    expect(SessionStore.instance.hasSessionCookie, isTrue);
  });

  test('a refused token sets no cookie and reads no session', () async {
    backend.googleIdRejected = true;
    final controller = controllerWithToken(
      () async => FakeBackend.validGoogleIdToken,
    );

    expect(await controller.signInWithGoogle(), isFalse);

    expect(controller.errorMessage, 'Google did not accept that sign-in.');
    expect(controller.user, isNull);
    expect(backend.paths, ['/api/auth/mobile-google']);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
  });

  test('a suspended account is refused without a session', () async {
    backend.googleAccountSuspended = true;
    final controller = controllerWithToken(
      () async => FakeBackend.validGoogleIdToken,
    );

    expect(await controller.signInWithGoogle(), isFalse);

    expect(
      controller.errorMessage,
      'Your account cannot sign in. Contact support.',
    );
    expect(SessionStore.instance.hasSessionCookie, isFalse);
  });

  test('a session the backend has already dropped is not a sign-in', () async {
    // The cookie arrives, then the session read says it means nothing.
    backend.sessionRevoked = true;
    final controller = controllerWithToken(
      () async => FakeBackend.validGoogleIdToken,
    );

    expect(await controller.signInWithGoogle(), isFalse);

    expect(
      controller.errorMessage,
      'Google sign-in did not complete. Please try again.',
    );
    expect(controller.user, isNull);
    expect(backend.paths, ['/api/auth/mobile-google', '/api/auth/session']);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
  });

  test('a cancelled sheet reports nothing and asks nothing', () async {
    final controller = controllerWithToken(
      () async => throw const GoogleSignInCanceled(),
    );

    expect(await controller.signInWithGoogle(), isFalse);

    expect(controller.status, AuthStatus.idle);
    expect(controller.errorMessage, isEmpty);
    expect(backend.requests, isEmpty);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
  });

  test('a device with no Google SDK falls back to the password form', () async {
    final controller = controllerWithToken(
      () async => throw const GoogleSignInUnsupported(),
    );

    expect(await controller.signInWithGoogle(), isFalse);

    expect(controller.errorMessage, AuthController.googleSignInUnavailable);
    expect(backend.requests, isEmpty);
  });

  test('the email and password flow still runs unchanged', () async {
    final controller = AuthController();

    expect(
      await controller.login(
        email: FakeBackend.validEmail,
        password: FakeBackend.validPassword,
      ),
      isTrue,
    );

    // Same three hops as before the Google route existed, and no call to it.
    expect(backend.paths, [
      '/api/auth/csrf',
      '/api/auth/callback/credentials',
      '/api/auth/session',
    ]);
    expect(
      backend.bodyFor('/api/auth/callback/credentials')['email'],
      FakeBackend.validEmail,
    );
    expect(backend.countOf('/api/auth/mobile-google'), 0);
    expect(controller.user?.email, FakeBackend.validEmail);
  });

  test('registration still signs nobody in', () async {
    final controller = AuthController();

    expect(
      await controller.signup(
        name: 'Test User',
        email: 'newcomer@gmail.com',
        password: FakeBackend.validPassword,
        interestSlugs: const ['graphic-design'],
        experienceLevel: ExperienceLevel.beginner,
      ),
      isTrue,
    );

    expect(controller.user, isNull);
    expect(backend.countOf('/api/auth/register'), 1);
    expect(backend.countOf('/api/auth/mobile-google'), 0);
    expect(SessionStore.instance.hasSessionCookie, isFalse);
  });
}
