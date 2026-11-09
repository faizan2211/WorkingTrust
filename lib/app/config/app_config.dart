class AppConfig {
  AppConfig._();

  static const String appName = 'WorkingTrust';
  static const bool enableLogging = true;

  /// Origin of the deployed Next.js 15 backend. One origin, HTTPS, reachable
  /// from any network — a device needs no flag, no IP of the developer's PC,
  /// and no `adb reverse`. The verification link the backend emails also opens
  /// on the phone, because it is built from this same origin.
  ///
  /// A locally running backend is only for when the deployed one is not enough,
  /// and it replaces this value rather than joining it. Because `--dart-define`
  /// is compiled in, the app must be stopped and re-run for a new URL to take
  /// effect, and the stored session cookie belongs to the origin that issued it
  /// — switching origins therefore looks like a sign-out.
  ///   flutter run --dart-define=BACKEND_URL=http://YOUR-PC-IP:3000
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://mongoose-colonial-deceit.ngrok-free.dev ',
  );

  /// The **Web** OAuth client of the same Google Cloud project the backend
  /// already uses. Google puts this value in the ID token as its audience, and
  /// `POST /api/auth/mobile-google` only accepts a token addressed to it, so the
  /// token a different app produced cannot be replayed here.
  ///
  /// A client ID is a public identifier, not a secret — it appears in every
  /// Google sign-in URL. The client *secret* stays on the server and is never
  /// part of a mobile build. The project's separate Android client (package name
  /// plus SHA-1) is registered in Google Cloud only; `google_sign_in` does not
  /// take it on Android.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '790811213882-besmb2crgvhfhvc34d2nrjbnt3l87tts.apps.googleusercontent.com',
  );
}
