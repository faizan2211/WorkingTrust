import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/config/app_config.dart';

/// The user closed Google's account chooser without picking an account. The
/// screen stays exactly where it was — this is not a failure to report.
class GoogleSignInCanceled implements Exception {
  const GoogleSignInCanceled();
}

/// This device has no native Google sign-in, i.e. a desktop run or a platform
/// the plugin does not implement.
class GoogleSignInUnsupported implements Exception {
  const GoogleSignInUnsupported();
}

typedef GoogleIdTokenSupplier = Future<String> Function();

/// Gets an ID token for Google's account the user picks on the device.
///
/// The token is addressed to [AppConfig.googleServerClientId], which is the
/// same Google client the backend already verifies against, so
/// `POST /api/auth/mobile-google` can turn it into a WorkingTrust session. This
/// class never contacts the WorkingTrust server, never sees a password, and
/// keeps no token — it hands the ID token to the caller once and forgets it.
///
/// Google's SDK is asked for an ID token only, not an access token, because the
/// backend needs to know *who* signed in and nothing else.
class GoogleSignInService {
  /// `initialize` may run exactly once per process, and its future must be
  /// awaited before any other call, so every instance shares one attempt.
  static Future<void>? _initialised;

  Future<String> requestIdToken() async {
    final signIn = GoogleSignIn.instance;

    _initialised ??= signIn.initialize(
      serverClientId: AppConfig.googleServerClientId,
    );
    await _initialised;

    if (!signIn.supportsAuthenticate()) {
      throw const GoogleSignInUnsupported();
    }

    final GoogleSignInAccount account;
    try {
      account = await signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCanceled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInUnsupported();
    }
    return idToken;
  }
}
