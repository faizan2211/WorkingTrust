import '../../../app/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../models/experience_level.dart';
import '../models/user_model.dart';
import '../models/work_category.dart';

/// Talks to the Next.js 15 backend: NextAuth cookie sessions plus the
/// registration and email-verification routes around it.
///
/// There is no Bearer token anywhere in this app — the backend only accepts
/// NextAuth cookies, and [SessionStore] replays them on every request.
class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// `POST /api/auth/register`. Creates the account but establishes no
  /// session: the backend requires the emailed verification link first.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required List<String> interestSlugs,
    required ExperienceLevel experienceLevel,
    String? phone,
    String? city,
    String? country,
    String? postalCode,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'interestSlugs': interestSlugs,
      'experienceLevel': experienceLevel.value,
    };
    // The schema treats these as optional or empty string; send only what the
    // user actually filled in.
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }
    if (city != null && city.trim().isNotEmpty) body['city'] = city.trim();
    if (country != null && country.trim().isNotEmpty) {
      body['country'] = country.trim();
    }
    if (postalCode != null && postalCode.trim().isNotEmpty) {
      body['postalCode'] = postalCode.trim();
    }

    final response = await _apiClient.post(ApiEndpoints.register, body: body);
    final user = (response as Map<String, dynamic>?)?['user'];
    if (user is! Map<String, dynamic>) {
      throw NetworkException('The server did not return the new account.');
    }
    return UserModel.fromJson(user);
  }

  /// NextAuth credentials sign-in, in the three steps the protocol requires.
  ///
  /// A 200/302 alone never means logged in — the session is always re-read
  /// from the backend before this returns.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final csrfToken = await _csrfToken();

    // NextAuth answers with a 302 whose Location we would otherwise have to
    // follow; json=true turns it into a JSON body carrying that same URL while
    // keeping the Set-Cookie headers, so no redirect is ever followed.
    final response = await _apiClient.send(
      'POST',
      ApiEndpoints.credentialsCallback,
      formEncoded: true,
      body: {
        'csrfToken': csrfToken,
        'email': email,
        'password': password,
        'callbackUrl': '${AppConfig.backendUrl}/dashboard',
        'json': 'true',
      },
    );

    final redirect = response.json?['url'];
    if (redirect is String) {
      final error = Uri.parse(redirect).queryParameters['error'];
      if (error != null) throw NetworkException(_describeFailure(error));
    } else if (response.isSuccess) {
      throw NetworkException(
        'The server did not confirm the sign-in response.',
        statusCode: response.statusCode,
      );
    }

    // Whatever the callback claimed, cookies are only a session if the backend
    // still agrees.
    final session = await readSession();
    if (session == null) {
      throw NetworkException(
        'Sign-in did not complete. Please try again.',
        statusCode: response.statusCode,
      );
    }
    return session;
  }

  /// `POST /api/auth/mobile-google` — trades a Google ID token for a session.
  ///
  /// The route answers with the same NextAuth session cookie the website gets,
  /// which [SessionStore] absorbs on the way back, so the cookie lands in this
  /// app's jar rather than in a browser's. As with the credentials flow, the
  /// response alone proves nothing: the session is read back from the backend
  /// before this returns.
  Future<UserModel> signInWithGoogleIdToken(String idToken) async {
    await _apiClient.post(
      ApiEndpoints.mobileGoogle,
      body: {'idToken': idToken},
    );

    final session = await readSession();
    if (session == null) {
      throw NetworkException(
        'Google sign-in did not complete. Please try again.',
      );
    }
    return session;
  }

  /// `GET /api/auth/session`. Returns null when the cookie is missing,
  /// rejected or past its expiry.
  Future<UserModel?> readSession() async {
    // A NextAuth session only exists as a cookie this device holds, so with no
    // session cookie there is nothing to ask about.
    await SessionStore.instance.load();
    if (!SessionStore.instance.hasSessionCookie) return null;

    final response = await _apiClient.send('GET', ApiEndpoints.session);
    final user = response.json?['user'];
    if (user is! Map<String, dynamic> ||
        (user['email']?.toString() ?? '').isEmpty) {
      // The server no longer recognises us — expired or signed out elsewhere.
      await SessionStore.instance.clear();
      return null;
    }
    return UserModel.fromJson(user);
  }

  Future<String> _csrfToken() async {
    final response = await _apiClient.get(ApiEndpoints.csrf);
    final token = (response as Map<String, dynamic>?)?['csrfToken'];
    if (token is! String || token.isEmpty) {
      throw NetworkException('The server did not return a CSRF token.');
    }
    return token;
  }

  /// NextAuth puts the thrown `authorize()` message into the error query
  /// parameter, so the backend's own wording reaches us verbatim.
  String _describeFailure(String error) {
    if (error == 'CredentialsSignin') {
      return 'Incorrect email or password.';
    }
    if (error == 'AccessDenied') {
      return 'Your account cannot sign in. Contact support.';
    }
    if (error == 'Configuration') {
      return 'Sign-in is not configured correctly on the server.';
    }
    return error;
  }

  /// Drops the session. NextAuth sessions are stateless JWTs held only by this
  /// device, so deleting the cookies is the logout.
  Future<void> logout() async {
    await SessionStore.instance.clear();
  }

  /// `POST /api/auth/verify-email` — the token from the emailed link.
  Future<String> verifyEmailToken(String token) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyEmail,
      body: {'token': token},
    );
    return _message(response, 'Email verified.');
  }

  /// `POST /api/auth/resend-verification`
  Future<String> resendVerification(String email) async {
    final response = await _apiClient.post(
      ApiEndpoints.resendVerification,
      body: {'email': email},
    );
    return _message(response, 'A new verification email is on its way.');
  }

  /// `POST /api/auth/forgot-password` — emails a 6-digit code.
  Future<String> forgotPassword(String email) async {
    final response = await _apiClient.post(
      ApiEndpoints.forgotPassword,
      body: {'email': email},
    );
    return _message(response, 'Check your inbox for a verification code.');
  }

  /// `POST /api/auth/verify-otp` — returns the one-hour reset token.
  Future<String> verifyOtp({required String email, required String otp}) async {
    final response = await _apiClient.post(
      ApiEndpoints.verifyOtp,
      body: {'email': email, 'otp': otp},
    );
    final token = (response as Map<String, dynamic>?)?['resetToken'];
    if (token is! String || token.isEmpty) {
      throw NetworkException('The server did not return a reset token.');
    }
    return token;
  }

  /// `POST /api/auth/reset-password`
  Future<String> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.resetPassword,
      body: {'token': token, 'password': password},
    );
    return _message(response, 'Password updated. You can log in now.');
  }

  /// `GET /api/categories` — public list feeding the registration interests.
  Future<List<WorkCategory>> fetchCategories() async {
    final response = await _apiClient.get(ApiEndpoints.categories);
    final categories = (response as Map<String, dynamic>?)?['categories'];
    if (categories is! List) return const [];
    return [
      for (final item in categories)
        if (item is Map<String, dynamic>) WorkCategory.fromJson(item),
    ];
  }

  String _message(dynamic response, String fallback) {
    if (response is Map<String, dynamic>) {
      final message = response['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return fallback;
  }
}
