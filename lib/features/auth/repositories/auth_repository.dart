import '../models/experience_level.dart';
import '../models/user_model.dart';
import '../models/work_category.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  Future<UserModel> login({required String email, required String password}) {
    return _authService.login(email: email, password: password);
  }

  /// Trades a Google ID token for the session cookie the app then keeps using.
  Future<UserModel> signInWithGoogle(String idToken) =>
      _authService.signInWithGoogleIdToken(idToken);

  Future<UserModel> signup({
    required String name,
    required String email,
    required String password,
    required List<String> interestSlugs,
    required ExperienceLevel experienceLevel,
    String? phone,
    String? city,
    String? country,
    String? postalCode,
  }) {
    return _authService.register(
      name: name,
      email: email,
      password: password,
      interestSlugs: interestSlugs,
      experienceLevel: experienceLevel,
      phone: phone,
      city: city,
      country: country,
      postalCode: postalCode,
    );
  }

  /// The session the stored cookies currently describe, if any.
  Future<UserModel?> currentSession() => _authService.readSession();

  Future<String> forgotPassword({required String email}) =>
      _authService.forgotPassword(email);

  Future<String> verifyOtp({required String email, required String otp}) =>
      _authService.verifyOtp(email: email, otp: otp);

  Future<String> resetPassword({
    required String token,
    required String password,
  }) => _authService.resetPassword(token: token, password: password);

  Future<String> resendVerification({required String email}) =>
      _authService.resendVerification(email);

  Future<List<WorkCategory>> categories() => _authService.fetchCategories();

  Future<void> logout() => _authService.logout();
}
