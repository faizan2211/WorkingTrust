import 'package:flutter/foundation.dart';

import '../../../core/network/network_exceptions.dart';
import '../../../core/network/session_store.dart';
import '../../profile/controller/profile_controller.dart';
import '../models/account_settings.dart';
import '../repositories/account_repository.dart';
import '../services/account_cache.dart';

/// The account settings the `/api/account/…` routes own.
///
/// The security switches and the notification preferences are read from the
/// server every time the screen opens, so a change made on the web shows here.
/// The contact form and the location dropdowns have no GET: the only thing this
/// device can show for them is the name and email the session and the security
/// route report, plus the location it saved itself.
///
/// The saved payment method and the withdrawal accounts read their own routes,
/// and only when a tab asks. An authenticator or an SMS switch is never moved
/// here: it changes when the server accepts a code, after which the security
/// route is read again rather than assumed.
class AccountController extends ChangeNotifier {
  AccountController._();

  static final AccountController instance = AccountController._();

  static const String sessionExpired =
      'Your session has expired. Please log in again.';

  final AccountRepository _repository = AccountRepository();
  final AccountCache _cache = AccountCache.instance;

  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;
  bool _methodsLoaded = false;
  String _errorMessage = '';

  SecuritySettings? _security;
  NotificationPreferences _preferences = defaultPreferences;
  ProfileLocation _location = emptyLocation;
  List<SavedBillingMethod> _billing = const [];
  List<SavedWithdrawalMethod> _withdrawals = const [];
  TotpSetup? _totpSetup;
  SmsSetup? _smsSetup;

  bool get isLoading => _loading;
  bool get isSaving => _saving;

  /// Whether the two GETs have answered for this account.
  bool get hasLoaded => _loaded;

  /// Whether the billing and withdrawal GETs have answered.
  bool get hasLoadedMethods => _methodsLoaded;
  String get errorMessage => _errorMessage;

  SecuritySettings? get security => _security;
  NotificationPreferences get preferences => _preferences;
  ProfileLocation get location => _location;
  List<SavedBillingMethod> get billing => _billing;

  /// The route keeps one payment method, so the list it answers with holds at
  /// most this one row.
  SavedBillingMethod? get billingMethod =>
      _billing.isEmpty ? null : _billing.first;
  List<SavedWithdrawalMethod> get withdrawals => _withdrawals;

  /// The authenticator secret the server is holding as pending, kept in memory
  /// only while the setup is open and never written to device storage.
  TotpSetup? get totpSetup => _totpSetup;

  /// Which way the SMS setup code went, as the route said.
  SmsSetup? get smsSetup => _smsSetup;

  /// The email the security route reports for the account, which is the stored
  /// one rather than the sign-in snapshot the session carries.
  String get email => _security?.email ?? ProfileController.instance.email;
  String get phone => _security?.phone ?? '';
  bool get googleLinked => _security?.googleLinked ?? false;
  bool get appleLinked => _security?.appleLinked ?? false;

  /// Reads both settings documents. A signed-out device asks for nothing, since
  /// every one of these routes answers 401 without the cookie.
  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    if (!SessionStore.instance.hasSessionCookie) return;
    _loading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final security = await _repository.security();
      final preferences = await _repository.preferences();
      _security = security;
      _preferences = preferences;
      _loaded = true;
      final userId = ProfileController.instance.userId;
      if (userId.isNotEmpty) {
        _location = await _cache.restore(userId) ?? emptyLocation;
        // `PATCH /api/profile` nulls a phone the body does not carry, so the
        // number this read reported is filed for the next profile write.
        await _cache.savePhone(userId, security.phone);
      }
    } on NetworkException catch (e) {
      _fail(
        e.statusCode == 401 ? sessionExpired : e.message,
        expired: e.statusCode == 401,
      );
    } catch (e) {
      _fail('$e', expired: false);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Reads the two saved-method lists. They belong to their own tabs, so a
  /// device that never opens them asks for neither.
  Future<void> loadMethods({bool force = false}) async {
    if (_loading || (_methodsLoaded && !force)) return;
    if (!SessionStore.instance.hasSessionCookie) return;
    _loading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final billing = await _repository.billing();
      final withdrawals = await _repository.withdrawals();
      _billing = billing;
      _withdrawals = withdrawals;
      _methodsLoaded = true;
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
    } catch (e) {
      _fail('$e', expired: false);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Writes the three switches and keeps the flags the PATCH does not report.
  Future<bool> saveSecurity({
    required bool mobileApp,
    required bool sms,
    required bool authenticator,
  }) async {
    if (!_openWrite()) return false;
    try {
      final answer = await _repository.saveSecurity(
        mobileApp: mobileApp,
        sms: sms,
        authenticator: authenticator,
      );
      final current = _security;
      if (current != null) {
        _security = (
          mobileApp: answer.mobileApp,
          sms: answer.sms,
          authenticator: answer.authenticator,
          authenticatorConfigured: answer.configured,
          googleLinked: current.googleLinked,
          appleLinked: current.appleLinked,
          phone: current.phone,
          email: current.email,
        );
      }
      return true;
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
      return false;
    } catch (e) {
      _fail('$e', expired: false);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> savePreferences(NotificationPreferences prefs) async {
    if (!_openWrite()) return false;
    try {
      _preferences = await _repository.savePreferences(prefs);
      return true;
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
      return false;
    } catch (e) {
      _fail('$e', expired: false);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Name and email for the account section. A changed email has to be verified
  /// again, and the route says so in its own sentence.
  Future<ContactResult?> saveAccount({
    required String name,
    required String email,
  }) async {
    if (!_openWrite()) return null;
    try {
      final result = await _repository.saveAccount(name: name, email: email);
      // The route answers with the row it wrote, so the profile shows it.
      ProfileController.instance.update(name: result.name, email: result.email);
      if (_security != null) {
        _security = (
          mobileApp: _security!.mobileApp,
          sms: _security!.sms,
          authenticator: _security!.authenticator,
          authenticatorConfigured: _security!.authenticatorConfigured,
          googleLinked: _security!.googleLinked,
          appleLinked: _security!.appleLinked,
          phone: _security!.phone,
          email: result.email,
        );
      }
      return result;
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
      return null;
    } catch (e) {
      _fail('$e', expired: false);
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Writes the four location columns and keeps them for the next sign-in,
  /// since no endpoint can read them back. Returns the route's own sentence.
  Future<String?> saveLocation(ProfileLocation location) async {
    if (!_openWrite()) return null;
    try {
      final saved = await _repository.saveLocation(location);
      _location = saved.location;
      final userId = ProfileController.instance.userId;
      if (userId.isNotEmpty) await _cache.save(userId, _location);
      return saved.message.isEmpty ? 'Location details saved.' : saved.message;
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
      return null;
    } catch (e) {
      _fail('$e', expired: false);
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// The route checks the current password itself and the session cookie still
  /// holds afterwards, so a sign-out stays the user's own action.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (!_openWrite()) return false;
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _errorMessage = '';
      return true;
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
      return false;
    } catch (e) {
      _fail('$e', expired: false);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Asks the server for the authenticator secret it then holds as pending.
  /// Nothing here turns the switch on: only [confirmTotp], after the route has
  /// accepted a code read from the app, can do that.
  Future<TotpSetup?> startTotp() => _write(() async {
    final setup = await _repository.startTotp();
    _totpSetup = setup;
    return setup;
  });

  Future<bool> confirmTotp(String code) => _run(() async {
    await _repository.confirmTotp(code);
    _totpSetup = null;
    // The route, not this device, decides where the switch stands now.
    await load(force: true);
  });

  Future<bool> removeTotp() => _run(() async {
    await _repository.removeTotp();
    _totpSetup = null;
    await load(force: true);
  });

  /// A setup nobody confirmed is dropped rather than left in memory.
  void discardTotp() {
    _totpSetup = null;
  }

  /// Starts the SMS code. The route answers which way it went — the phone, or
  /// the account's email when its provider is unusable — and refuses outright if
  /// the profile carries no phone number.
  Future<SmsSetup?> startSms() => _write(() async {
    final setup = await _repository.startSms();
    _smsSetup = setup;
    return setup;
  });

  Future<bool> confirmSms(String code) => _run(() async {
    await _repository.confirmSms(code);
    _smsSetup = null;
    await load(force: true);
  });

  Future<bool> removeSms() => _run(() async {
    await _repository.removeSms();
    _smsSetup = null;
    await load(force: true);
  });

  void discardSms() {
    _smsSetup = null;
  }

  /// Disconnects a provider the security route reported as linked. Linking one
  /// stays a browser sign-in this app cannot perform.
  Future<bool> unlinkProvider(String provider) => _run(() async {
    await _repository.unlinkProvider(provider);
    await load(force: true);
  });

  /// Replaces the one saved payment method. The card number and the security
  /// code go out for the route's own checks and are kept nowhere here — what
  /// comes back is the last four digits and the expiry the server persisted.
  Future<bool> saveCard({
    required String cardNumber,
    required String firstName,
    required String lastName,
    required String expMonth,
    required String expYear,
    required String securityCode,
  }) => _run(() async {
    _billing = await _repository.saveCard(
      cardNumber: cardNumber,
      firstName: firstName,
      lastName: lastName,
      expMonth: expMonth,
      expYear: expYear,
      securityCode: securityCode,
    );
  });

  Future<bool> saveWallet({
    required String method,
    required String accountName,
    required String walletAccount,
  }) => _run(() async {
    _billing = await _repository.saveWallet(
      method: method,
      accountName: accountName,
      walletAccount: walletAccount,
    );
  });

  Future<bool> removeBilling() => _run(() async {
    _billing = await _repository.removeBilling();
  });

  /// Adds one withdrawal account, up to the five the route allows. This list is
  /// the route's own; it does not touch the billing method, and saving an
  /// account here does not make a withdrawal payable.
  Future<bool> saveWithdrawal({
    required String method,
    required String accountDetails,
    String label = '',
  }) => _run(() async {
    _withdrawals = await _repository.saveWithdrawal(
      method: method,
      accountDetails: accountDetails,
      label: label,
    );
  });

  Future<bool> removeWithdrawal(String id) => _run(() async {
    _withdrawals = await _repository.removeWithdrawal(id);
  });

  /// Runs one write behind the shared guard: nothing while a read or another
  /// write is in flight, the server's own wording on a failure, and the saving
  /// flag cleared either way.
  Future<T?> _write<T>(Future<T> Function() operation) async {
    if (!_openWrite()) return null;
    try {
      return await operation();
    } on NetworkException catch (e) {
      _fail(e.message, expired: e.statusCode == 401);
      return null;
    } catch (e) {
      _fail('$e', expired: false);
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// A write whose only answer is whether the route accepted it.
  Future<bool> _run(Future<void> Function() operation) async =>
      (await _write(() async {
        await operation();
        return true;
      })) ??
      false;

  /// Drops everything read for the previous account.
  void clear() {
    _loading = false;
    _saving = false;
    _loaded = false;
    _methodsLoaded = false;
    _errorMessage = '';
    _security = null;
    _preferences = defaultPreferences;
    _location = emptyLocation;
    _billing = const [];
    _withdrawals = const [];
    _totpSetup = null;
    _smsSetup = null;
    notifyListeners();
  }

  bool _openWrite() {
    if (_loading || _saving) return false;
    if (!SessionStore.instance.hasSessionCookie) {
      _errorMessage = sessionExpired;
      notifyListeners();
      return false;
    }
    _errorMessage = '';
    _saving = true;
    notifyListeners();
    return true;
  }

  void _fail(String message, {required bool expired}) {
    _errorMessage = message;
    if (expired) {
      _loaded = false;
      _methodsLoaded = false;
      _security = null;
      _preferences = defaultPreferences;
      _location = emptyLocation;
      _billing = const [];
      _withdrawals = const [];
      // A pending setup belongs to a session this device no longer has.
      _totpSetup = null;
      _smsSetup = null;
    }
  }
}
