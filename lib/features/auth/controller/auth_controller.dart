import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../notifications/services/fcm_push_service.dart';
import '../models/experience_level.dart';
import '../models/user_model.dart';
import '../models/work_category.dart';
import '../repositories/auth_repository.dart';
import '../services/google_sign_in_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthController extends ChangeNotifier {
  /// Built with the device's own Google SDK. Tests pass a supplier that answers
  /// without one, because a widget test has no platform channel to call.
  AuthController({GoogleIdTokenSupplier? googleIdToken})
    : _googleIdToken = googleIdToken ?? _googleSignInService.requestIdToken;

  /// Reported when Google's SDK has no way to run here, i.e. a desktop build or
  /// an unsupported platform. On a phone the button works.
  static const String googleSignInUnavailable =
      'Google sign-in is not available on this device. Please use your email and password.';

  static final GoogleSignInService _googleSignInService = GoogleSignInService();

  final GoogleIdTokenSupplier _googleIdToken;
  final AuthRepository _authRepository = AuthRepository();

  AuthStatus _status = AuthStatus.idle;
  String _errorMessage = '';
  UserModel? _user;
  List<WorkCategory> _categories = const [];
  String _categoriesError = '';
  bool _categoriesLoading = false;

  AuthStatus get status => _status;
  String get errorMessage => _errorMessage;
  UserModel? get user => _user;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _user != null;

  List<WorkCategory> get categories => _categories;
  String get categoriesError => _categoriesError;
  bool get categoriesLoading => _categoriesLoading;

  /// Registers an account. A successful call does NOT sign the user in: the
  /// backend verifies the email before it will issue a session.
  Future<bool> signup({
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
    if (isLoading) return false;
    _start();
    try {
      _user = await _authRepository.signup(
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
      // The account exists but has no session, so nothing here may be treated
      // as signed in.
      _user = null;
      _finish(AuthStatus.success);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    if (isLoading) return false;
    _start();
    try {
      _user = await _authRepository.login(email: email, password: password);
      unawaited(FcmPushService.instance.setAuthenticated(true));
      _finish(AuthStatus.success);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  /// Signs the device in with the Google account it picks, and leaves it signed
  /// in: the backend answers the token with the NextAuth session cookie, which
  /// the existing jar stores and replays, so every later request is already
  /// authenticated. Returns false when the user cancels (silently, since
  /// nothing went wrong) or when Google or the backend refuses.
  Future<bool> signInWithGoogle() async {
    if (isLoading) return false;
    _start();
    try {
      _user = await _authRepository.signInWithGoogle(await _googleIdToken());
      unawaited(FcmPushService.instance.setAuthenticated(true));
      _finish(AuthStatus.success);
      return true;
    } on GoogleSignInCanceled {
      _user = null;
      _status = AuthStatus.idle;
      _errorMessage = '';
      notifyListeners();
      return false;
    } on GoogleSignInUnsupported {
      _user = null;
      _failState(googleSignInUnavailable);
      return false;
    } catch (e) {
      _user = null;
      _fail(e);
      return false;
    }
  }

  /// Loads the session the saved cookies still describe, on app reopen.
  /// Returns null when the device is signed out or the session expired.
  Future<UserModel?> restoreSession() async {
    try {
      final user = await _authRepository.currentSession();
      _user = user;
      unawaited(FcmPushService.instance.setAuthenticated(user != null));
      _finish(user == null ? AuthStatus.idle : AuthStatus.success);
      return user;
    } catch (e) {
      _user = null;
      unawaited(FcmPushService.instance.setAuthenticated(false));
      _finish(AuthStatus.idle);
      return null;
    }
  }

  Future<List<WorkCategory>> loadCategories() async {
    if (_categoriesLoading) return _categories;
    if (_categories.isNotEmpty) return _categories;
    _categoriesLoading = true;
    _categoriesError = '';
    notifyListeners();
    try {
      _categories = await _authRepository.categories();
      if (_categories.isEmpty) {
        _categoriesError = 'No work fields are available yet.';
      }
    } catch (e) {
      _categoriesError = _messageFrom(e);
    }
    _categoriesLoading = false;
    notifyListeners();
    return _categories;
  }

  /// Asks the backend to email a 6-digit code. The returned string is the
  /// backend's own confirmation wording.
  Future<String?> forgotPassword({required String email}) async {
    if (isLoading) return null;
    _start();
    try {
      final message = await _authRepository.forgotPassword(email: email);
      _finish(AuthStatus.success);
      return message;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  /// Exchanges the emailed code for a short-lived reset token.
  Future<String?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    if (isLoading) return null;
    _start();
    try {
      final token = await _authRepository.verifyOtp(email: email, otp: otp);
      _finish(AuthStatus.success);
      return token;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
  }) async {
    if (isLoading) return false;
    _start();
    try {
      await _authRepository.resetPassword(token: token, password: password);
      _finish(AuthStatus.success);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> resendVerification({required String email}) async {
    if (isLoading) return false;
    _start();
    try {
      await _authRepository.resendVerification(email: email);
      _finish(AuthStatus.success);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<void> logout() async {
    await FcmPushService.instance.signOut();
    _user = null;
    _status = AuthStatus.idle;
    _errorMessage = '';
    notifyListeners();
    await _authRepository.logout();
  }

  void _start() {
    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();
  }

  void _finish(AuthStatus value) {
    _status = value;
    notifyListeners();
  }

  void _fail(Object e) {
    _failState(_messageFrom(e));
  }

  void _failState(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  String _messageFrom(Object e) => e.toString();
}
