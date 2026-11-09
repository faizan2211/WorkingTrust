import '../models/account_settings.dart';
import '../services/account_service.dart';

class AccountRepository {
  final AccountService _accountService = AccountService();

  Future<SecuritySettings> security() => _accountService.security();

  Future<({bool mobileApp, bool sms, bool authenticator, bool configured})>
  saveSecurity({
    required bool mobileApp,
    required bool sms,
    required bool authenticator,
  }) => _accountService.saveSecurity(
    mobileApp: mobileApp,
    sms: sms,
    authenticator: authenticator,
  );

  Future<NotificationPreferences> preferences() =>
      _accountService.preferences();

  Future<NotificationPreferences> savePreferences(
    NotificationPreferences prefs,
  ) => _accountService.savePreferences(prefs);

  Future<ContactResult> saveAccount({
    required String name,
    required String email,
  }) => _accountService.saveAccount(name: name, email: email);

  Future<({ProfileLocation location, String message})> saveLocation(
    ProfileLocation location,
  ) => _accountService.saveLocation(location);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) => _accountService.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
    confirmPassword: confirmPassword,
  );

  Future<TotpSetup> startTotp() => _accountService.startTotp();

  Future<void> confirmTotp(String code) => _accountService.confirmTotp(code);

  Future<void> removeTotp() => _accountService.removeTotp();

  Future<SmsSetup> startSms() => _accountService.startSms();

  Future<void> confirmSms(String code) => _accountService.confirmSms(code);

  Future<void> removeSms() => _accountService.removeSms();

  Future<void> unlinkProvider(String provider) =>
      _accountService.unlinkProvider(provider);

  Future<List<SavedBillingMethod>> billing() => _accountService.billing();

  Future<List<SavedBillingMethod>> saveCard({
    required String cardNumber,
    required String firstName,
    required String lastName,
    required String expMonth,
    required String expYear,
    required String securityCode,
  }) => _accountService.saveCard(
    cardNumber: cardNumber,
    firstName: firstName,
    lastName: lastName,
    expMonth: expMonth,
    expYear: expYear,
    securityCode: securityCode,
  );

  Future<List<SavedBillingMethod>> saveWallet({
    required String method,
    required String accountName,
    required String walletAccount,
  }) => _accountService.saveWallet(
    method: method,
    accountName: accountName,
    walletAccount: walletAccount,
  );

  Future<List<SavedBillingMethod>> removeBilling() =>
      _accountService.removeBilling();

  Future<List<SavedWithdrawalMethod>> withdrawals() =>
      _accountService.withdrawals();

  Future<List<SavedWithdrawalMethod>> saveWithdrawal({
    required String method,
    required String accountDetails,
    String label = '',
  }) => _accountService.saveWithdrawal(
    method: method,
    accountDetails: accountDetails,
    label: label,
  );

  Future<List<SavedWithdrawalMethod>> removeWithdrawal(String id) =>
      _accountService.removeWithdrawal(id);
}
