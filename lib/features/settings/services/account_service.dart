import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/account_settings.dart';

/// The account settings routes, in one place: what each of them answers, and
/// only what each of them answers.
///
/// `GET /api/account/security` reports the three two-step switches with the
/// phone, email and linked providers around them; `PATCH` writes the switches
/// and answers with just those. The authenticator and the SMS have their own
/// setup routes, where a code the server confirms — not a local tap — is what
/// turns the switch on. Notification preferences are the six keys the route
/// keeps as one JSON column; they are not the notification list. Contact is
/// PATCH-only and needs a `section`, so a device can only report what it saved
/// itself. Billing holds one saved payment method with a card reduced to its
/// last four digits, withdrawals a list of up to five accounts, and the two are
/// separate columns on the server.
class AccountService {
  final ApiClient _apiClient = ApiClient();

  Future<SecuritySettings> security() async =>
      _security(await _apiClient.get(ApiEndpoints.accountSecurity));

  /// Writes the three switches. The route answers with them plus whether an
  /// authenticator secret exists, so the rest of the state is left untouched.
  Future<({bool mobileApp, bool sms, bool authenticator, bool configured})>
  saveSecurity({
    required bool mobileApp,
    required bool sms,
    required bool authenticator,
  }) async {
    final response = await _apiClient.patch(
      ApiEndpoints.accountSecurity,
      body: <String, dynamic>{
        'twoStepMobileApp': mobileApp,
        'twoStepSms': sms,
        'twoStepAuthenticator': authenticator,
      },
    );
    final data = _map(response);
    return (
      mobileApp: _flag(data['twoStepMobileApp']),
      sms: _flag(data['twoStepSms']),
      authenticator: _flag(data['twoStepAuthenticator']),
      configured: _flag(data['authenticatorConfigured']),
    );
  }

  Future<NotificationPreferences> preferences() async => _preferences(
    (await _apiClient.get(ApiEndpoints.accountNotifications))['prefs'],
  );

  /// The route validates all six keys together and answers with the stored set,
  /// which is what the caller keeps.
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences prefs,
  ) async {
    final response = await _apiClient.patch(
      ApiEndpoints.accountNotifications,
      body: <String, dynamic>{
        'desktopShow': prefs.desktopShow,
        'desktopCounter': prefs.desktopCounter,
        'mobileShow': prefs.mobileShow,
        'mobileCounter': prefs.mobileCounter,
        'emailShow': prefs.emailShow,
        'emailFrequency': prefs.emailFrequency,
      },
    );
    return _preferences(_map(response)['prefs']);
  }

  /// `section: "account"` — the route's own sentence warns when the new email
  /// has to be verified before the next sign-in.
  Future<ContactResult> saveAccount({
    required String name,
    required String email,
  }) async {
    final response = await _apiClient.patch(
      ApiEndpoints.accountContact,
      body: <String, dynamic>{
        'section': 'account',
        'name': name,
        'email': email,
      },
    );
    final data = _map(response);
    final user = _map(data['user']);
    return (
      message: _text(data['message']),
      name: _text(user['name'], name),
      email: _text(user['email'], email),
    );
  }

  Future<({ProfileLocation location, String message})> saveLocation(
    ProfileLocation location,
  ) async {
    final response = await _apiClient.patch(
      ApiEndpoints.accountContact,
      body: <String, dynamic>{
        'section': 'location',
        'timezone': location.timezone,
        'country': location.country,
        'stateProvince': location.stateProvince,
        'city': location.city,
      },
    );
    final data = _map(response);
    final user = _map(data['user']);
    return (
      location: (
        timezone: _text(user['timezone'], location.timezone),
        country: _text(user['country'], location.country),
        stateProvince: _text(user['stateProvince'], location.stateProvince),
        city: _text(user['city'], location.city),
      ),
      message: _text(data['message']),
    );
  }

  /// The route compares the current password itself, so a failure here is the
  /// server's answer rather than a local guess. Nothing about the passwords is
  /// kept or logged.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) => _apiClient.post(
    ApiEndpoints.accountPassword,
    body: <String, dynamic>{
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    },
  );

  /// Two-step verification for the authenticator app. `POST` asks the server for
  /// a secret it holds as pending, `PUT` proves the user can read codes from it,
  /// and `DELETE` takes both away again. Showing a secret enables nothing.
  Future<TotpSetup> startTotp() async {
    final data = _map(await _apiClient.post(ApiEndpoints.accountSecurityTotp));
    return (
      secret: _text(data['secret']),
      otpauthUrl: _text(data['otpauthUrl']),
    );
  }

  /// The route compares the code against its own pending secret, so this is the
  /// only call that can turn the authenticator switch on.
  Future<void> confirmTotp(String code) => _apiClient.put(
    ApiEndpoints.accountSecurityTotp,
    body: <String, dynamic>{'code': code},
  );

  Future<void> removeTotp() =>
      _apiClient.delete(ApiEndpoints.accountSecurityTotp);

  /// Starting SMS setup. The route answers which way the code went, because it
  /// falls back to the account's email when its SMS provider is unusable — and
  /// refuses outright when the profile has no phone number.
  Future<SmsSetup> startSms() async {
    final data = _map(await _apiClient.post(ApiEndpoints.accountSecuritySms));
    return (channel: _text(data['channel']), message: _text(data['message']));
  }

  Future<void> confirmSms(String code) => _apiClient.put(
    ApiEndpoints.accountSecuritySms,
    body: <String, dynamic>{'code': code},
  );

  Future<void> removeSms() =>
      _apiClient.delete(ApiEndpoints.accountSecuritySms);

  /// Disconnecting a provider is the only thing this route offers; linking one
  /// stays a browser sign-in. The provider goes in the JSON body, which is where
  /// the route reads it.
  Future<void> unlinkProvider(String provider) => _apiClient.delete(
    ApiEndpoints.accountSecurityOauth,
    body: <String, dynamic>{'provider': provider},
  );

  Future<List<SavedBillingMethod>> billing() async {
    final data = _map(await _apiClient.get(ApiEndpoints.accountBilling));
    return _rows(data['methods'], _billing);
  }

  /// The card form. `securityCode` is the CVV: the route demands a well-formed
  /// one and then persists nothing from it, so it goes out with the rest and is
  /// dropped when the answer arrives. The number itself reaches the server only
  /// to be reduced to its last four digits.
  Future<List<SavedBillingMethod>> saveCard({
    required String cardNumber,
    required String firstName,
    required String lastName,
    required String expMonth,
    required String expYear,
    required String securityCode,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.accountBilling,
      body: <String, dynamic>{
        'method': 'CARD',
        'cardNumber': cardNumber,
        'firstName': firstName,
        'lastName': lastName,
        'expMonth': expMonth,
        'expYear': expYear,
        'securityCode': securityCode,
      },
    );
    return _rows(_map(response)['methods'], _billing);
  }

  /// One of the two wallets, which the route keeps in place of a card.
  Future<List<SavedBillingMethod>> saveWallet({
    required String method,
    required String accountName,
    required String walletAccount,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.accountBilling,
      body: <String, dynamic>{
        'method': method,
        'accountName': accountName,
        'walletAccount': walletAccount,
      },
    );
    return _rows(_map(response)['methods'], _billing);
  }

  Future<List<SavedBillingMethod>> removeBilling() async {
    final data = _map(await _apiClient.delete(ApiEndpoints.accountBilling));
    return _rows(data['methods'], _billing);
  }

  Future<List<SavedWithdrawalMethod>> withdrawals() async {
    final data = _map(await _apiClient.get(ApiEndpoints.accountWithdrawals));
    return _rows(data['methods'], _withdrawal);
  }

  /// Appends to the account's own list; the route answers with the whole of it,
  /// including the id the removal call needs. Leaving [label] empty lets the
  /// server use the method's name.
  Future<List<SavedWithdrawalMethod>> saveWithdrawal({
    required String method,
    required String accountDetails,
    String label = '',
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.accountWithdrawals,
      body: <String, dynamic>{
        'method': method,
        'accountDetails': accountDetails,
        if (label.trim().isNotEmpty) 'label': label.trim(),
      },
    );
    return _rows(_map(response)['methods'], _withdrawal);
  }

  Future<List<SavedWithdrawalMethod>> removeWithdrawal(String id) async {
    final response = await _apiClient.delete(
      ApiEndpoints.accountWithdrawals,
      body: <String, dynamic>{'id': id},
    );
    return _rows(_map(response)['methods'], _withdrawal);
  }

  SecuritySettings _security(Object? response) {
    final data = _map(response);
    return (
      mobileApp: _flag(data['twoStepMobileApp']),
      sms: _flag(data['twoStepSms']),
      authenticator: _flag(data['twoStepAuthenticator']),
      authenticatorConfigured: _flag(data['authenticatorConfigured']),
      googleLinked: _flag(data['googleLinked']),
      appleLinked: _flag(data['appleLinked']),
      phone: _text(data['phone']),
      email: _text(data['email']),
    );
  }

  /// Mirrors the route's own reader: a value it does not recognise falls back
  /// to the default rather than being sent back as a preference.
  NotificationPreferences _preferences(Object? raw) {
    final data = _map(raw);
    return (
      desktopShow: _one(data['desktopShow'], activityLevels, 'ALL'),
      desktopCounter: _one(data['desktopCounter'], counterLevels, 'ALL'),
      mobileShow: _one(data['mobileShow'], activityLevels, 'ALL'),
      mobileCounter: _one(data['mobileCounter'], counterLevels, 'ALL'),
      emailShow: _one(data['emailShow'], activityLevels, 'ALL'),
      emailFrequency: _one(
        data['emailFrequency'],
        emailFrequencies,
        'IMMEDIATE',
      ),
    );
  }

  String _one(Object? value, Map<String, String> allowed, String fallback) =>
      value is String && allowed.containsKey(value) ? value : fallback;

  Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  bool _flag(Object? value) => value == true;

  String _text(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  /// The rows of a `methods` array. The server's own reader drops anything that
  /// is not shaped like a method, so what reaches here is a map or nothing.
  List<T> _rows<T>(Object? raw, T Function(Map<String, dynamic> data) parse) =>
      [
        if (raw is List)
          for (final row in raw)
            if (row is Map<String, dynamic>) parse(row),
      ];

  SavedBillingMethod _billing(Map<String, dynamic> data) => (
    id: _text(data['id']),
    method: _text(data['method']),
    label: _text(data['label']),
    accountDetails: _text(data['accountDetails']),
    createdAt: _text(data['createdAt']),
    firstName: _text(data['firstName']),
    lastName: _text(data['lastName']),
    cardLast4: _text(data['cardLast4']),
    expMonth: _text(data['expMonth']),
    expYear: _text(data['expYear']),
    walletAccount: _text(data['walletAccount']),
    accountName: _text(data['accountName']),
  );

  SavedWithdrawalMethod _withdrawal(Map<String, dynamic> data) => (
    id: _text(data['id']),
    method: _text(data['method']),
    label: _text(data['label']),
    accountDetails: _text(data['accountDetails']),
    createdAt: _text(data['createdAt']),
  );
}
