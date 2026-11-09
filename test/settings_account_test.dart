import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/core/storage/user_data_store.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/settings/controller/account_controller.dart';
import 'package:working_trust/features/settings/models/account_settings.dart';

import 'fake_backend.dart';

/// The four `/api/account/…` routes, driven through the controller the Settings
/// tabs use.
final FakeBackend _backend = FakeBackend();
final AccountController _account = AccountController.instance;

const NotificationPreferences _daily = (
  desktopShow: 'IMPORTANT',
  desktopCounter: 'MESSAGES',
  mobileShow: 'ALL',
  mobileCounter: 'NONE',
  emailShow: 'IMPORTANT',
  emailFrequency: 'DAILY',
);

Future<void> _signIn() async {
  _backend.issueSessionCookie();
  await ProfileController.instance.load();
  await _account.load();
}

void main() {
  setUp(() async {
    await _backend.install();
    ProfileController.instance.clear();
    _account.clear();
  });

  group('reading', () {
    test('a signed-out device asks for nothing', () async {
      await _account.load();
      expect(_backend.paths, isEmpty);
      expect(_account.hasLoaded, isFalse);
      expect(_account.security, isNull);
    });

    test('both documents are read once and kept', () async {
      await _signIn();
      expect(_backend.countOf('/api/account/security'), 1);
      expect(_backend.countOf('/api/account/notifications'), 1);

      await _account.load();
      expect(_backend.countOf('/api/account/security'), 1);
      expect(_account.preferences, defaultPreferences);
    });

    test('an unreadable account leaves a retry, not empty switches', () async {
      _backend.issueSessionCookie();
      _backend.sessionRevoked = true;
      await _account.load();

      expect(_account.hasLoaded, isFalse);
      expect(_account.errorMessage, AccountController.sessionExpired);

      _backend.sessionRevoked = false;
      _backend.issueSessionCookie();
      await _account.load();
      expect(_account.hasLoaded, isTrue);
    });
  });

  group('security', () {
    test("a switch is written in the route's own field names", () async {
      await _signIn();
      expect(
        await _account.saveSecurity(
          mobileApp: true,
          sms: false,
          authenticator: false,
        ),
        isTrue,
      );

      expect(_backend.bodyFor('/api/account/security'), {
        'twoStepMobileApp': true,
        'twoStepSms': false,
        'twoStepAuthenticator': false,
      });
      expect(_account.security!.mobileApp, isTrue);
    });

    test('the route refuses SMS and an unconfigured authenticator', () async {
      await _signIn();

      expect(
        await _account.saveSecurity(
          mobileApp: false,
          sms: true,
          authenticator: false,
        ),
        isFalse,
      );
      expect(
        _account.errorMessage,
        'Add a phone number to your profile before enabling SMS verification.',
      );
      expect(_account.security!.sms, isFalse);

      expect(
        await _account.saveSecurity(
          mobileApp: false,
          sms: false,
          authenticator: true,
        ),
        isFalse,
      );
      expect(
        _account.errorMessage,
        'Set up an authenticator app before enabling authenticator codes.',
      );

      // Once the secret exists, and a phone is on the account, both are accepted.
      _backend.security['totpSecret'] = 'secret';
      _backend.security['phone'] = '+92 300 0000000';
      expect(
        await _account.saveSecurity(
          mobileApp: false,
          sms: true,
          authenticator: true,
        ),
        isTrue,
      );
      expect(_account.security!.authenticator, isTrue);

      // The phone is what the security GET reports; a PATCH answer never holds it.
      await _account.load(force: true);
      expect(_account.phone, '+92 300 0000000');
    });

    test("linked providers are the account's, never a tap", () async {
      await _signIn();
      expect(_account.googleLinked, isFalse);

      _backend.security['googleId'] = 'g1';
      await _account.load(force: true);
      expect(_account.googleLinked, isTrue);
      expect(_account.appleLinked, isFalse);
    });
  });

  group('notification preferences', () {
    test('all six tokens go together and the stored set comes back', () async {
      await _signIn();
      expect(await _account.savePreferences(_daily), isTrue);

      expect(_backend.bodyFor('/api/account/notifications'), {
        'desktopShow': 'IMPORTANT',
        'desktopCounter': 'MESSAGES',
        'mobileShow': 'ALL',
        'mobileCounter': 'NONE',
        'emailShow': 'IMPORTANT',
        'emailFrequency': 'DAILY',
      });
      expect(_account.preferences, _daily);
    });

    test(
      'a token the route does not know is refused and left unsaved',
      () async {
        await _signIn();
        expect(
          await _account.savePreferences((
            desktopShow: 'ALL',
            desktopCounter: 'ALWAYS',
            mobileShow: 'ALL',
            mobileCounter: 'ALL',
            emailShow: 'ALL',
            emailFrequency: 'IMMEDIATE',
          )),
          isFalse,
        );
        expect(_account.errorMessage, 'Invalid notification preferences.');
        expect(_account.preferences, defaultPreferences);
        expect(_backend.prefsColumn, isNull);
      },
    );

    test('they are not the notification list', () async {
      await _signIn();
      expect(
        _backend.paths.where((path) => path == '/api/notifications'),
        isEmpty,
      );
    });
  });

  group('contact', () {
    test('an account save follows the row the route wrote', () async {
      await _signIn();
      final result = await _account.saveAccount(
        name: 'Arslan Sabir',
        email: FakeBackend.validEmail,
      );

      expect(result!.message, 'Account details saved.');
      expect(ProfileController.instance.name, 'Arslan Sabir');
      expect(_account.email, FakeBackend.validEmail);
      expect(_backend.bodyFor('/api/account/contact')['section'], 'account');
    });

    test("a new email is reported with the route's warning", () async {
      await _signIn();
      final result = await _account.saveAccount(
        name: 'Arslan Sabir',
        email: 'another@gmail.com',
      );

      expect(
        result!.message,
        'Account updated. Please verify your new email before the next login.',
      );
      expect(_account.email, 'another@gmail.com');
    });

    test('the route rejects a name too short for its schema', () async {
      await _signIn();
      expect(
        await _account.saveAccount(name: 'A', email: FakeBackend.validEmail),
        isNull,
      );
      expect(
        _account.errorMessage,
        'Enter a valid name (2+ characters) and email.',
      );
      expect(ProfileController.instance.name, 'Someone');
    });

    test(
      'a location survives a sign-out because nothing can read it back',
      () async {
        await _signIn();
        final message = await _account.saveLocation((
          timezone: 'UTC+05:00 Islamabad, Karachi',
          country: 'Pakistan',
          stateProvince: 'Punjab',
          city: 'Lahore',
        ));
        expect(message, 'Location details saved.');
        expect(_backend.storedLocation['city'], 'Lahore');

        _account.clear();
        expect(_account.location, emptyLocation);

        await _signIn();
        expect(_account.location.city, 'Lahore');
        expect(_account.location.country, 'Pakistan');
      },
    );

    test("another account is not given this one's location", () async {
      await _signIn();
      await _account.saveLocation((
        timezone: '',
        country: 'Pakistan',
        stateProvince: '',
        city: 'Lahore',
      ));

      _account.clear();
      ProfileController.instance.clear();
      _backend.sessionId = 'u2';
      _backend.issueSessionCookie();
      await ProfileController.instance.load();
      await _account.load();

      expect(_account.location, emptyLocation);
    });
  });

  group('password', () {
    test('a change is only reported once the route accepts it', () async {
      await _signIn();
      expect(
        await _account.changePassword(
          currentPassword: 'wrongpassword',
          newPassword: 'newpassword1',
          confirmPassword: 'newpassword1',
        ),
        isFalse,
      );
      expect(_account.errorMessage, 'Current password is incorrect.');
      expect(_backend.storedPassword, FakeBackend.validPassword);

      expect(
        await _account.changePassword(
          currentPassword: FakeBackend.validPassword,
          newPassword: 'newpassword1',
          confirmPassword: 'newpassword1',
        ),
        isTrue,
      );
      expect(_backend.storedPassword, 'newpassword1');
    });

    test('no password ever reaches a stored document', () async {
      await _signIn();
      expect(
        await _account.changePassword(
          currentPassword: FakeBackend.validPassword,
          newPassword: 'newpassword1',
          confirmPassword: 'newpassword1',
        ),
        isTrue,
      );
      await _account.savePreferences(_daily);
      await _account.saveLocation((
        timezone: '',
        country: 'Pakistan',
        stateProvince: '',
        city: 'Lahore',
      ));
      // A profile write, so the profile document exists to be inspected.
      await ProfileController.instance.saveIdentity(
        title: 'Developer',
        hourlyRate: '25',
        bio: 'I build Flutter apps.',
      );

      // Both documents this device keeps, read back as the raw JSON the keystore
      // holds, say nothing about the password.
      final stored = [
        jsonEncode(await UserDataStore.instance.read('profile', 'u1')),
        jsonEncode(await UserDataStore.instance.read('account', 'u1')),
      ].join();
      expect(stored.toLowerCase(), isNot(contains('password')));
      expect(stored, isNot(contains('newpassword1')));
      expect(stored, contains('Developer'));
      expect(_account.location.city, 'Lahore');
    });
  });

  group('authenticator app', () {
    test('the switch waits for the route to accept a code', () async {
      await _signIn();

      final setup = await _account.startTotp();
      expect(setup!.secret, isNotEmpty);
      expect(setup.otpauthUrl, startsWith('otpauth://totp/'));
      // Filing a secret enables nothing, and reports nothing as configured.
      expect(_account.security!.authenticator, isFalse);
      expect(_account.security!.authenticatorConfigured, isFalse);

      expect(await _account.confirmTotp('000000'), isFalse);
      expect(_account.errorMessage, 'Invalid authenticator code. Try again.');
      expect(_account.security!.authenticator, isFalse);

      expect(await _account.confirmTotp(FakeBackend.validTotpCode), isTrue);
      expect(_account.security!.authenticator, isTrue);
      expect(_account.security!.authenticatorConfigured, isTrue);

      expect(await _account.removeTotp(), isTrue);
      expect(_account.security!.authenticator, isFalse);
      expect(_backend.security['totpSecret'], isNull);
    });

    test('a code cannot be confirmed before a setup was started', () async {
      await _signIn();
      expect(await _account.confirmTotp(FakeBackend.validTotpCode), isFalse);
      expect(_account.errorMessage, 'Start authenticator setup first.');
    });

    test('the key and its link are never written to device storage', () async {
      await _signIn();
      await _account.startTotp();
      await _account.confirmTotp(FakeBackend.validTotpCode);
      await _account.savePreferences(_daily);
      final stored = jsonEncode(
        await UserDataStore.instance.read('account', 'u1'),
      );
      expect(stored, isNot(contains('JBSWY3DPEHPK3PXP')));
      expect(stored, isNot(contains('otpauth')));
    });
  });

  group('SMS verification', () {
    test('an account with no phone is refused before a code is sent', () async {
      await _signIn();
      expect(await _account.startSms(), isNull);
      expect(
        _account.errorMessage,
        'Add a phone number to your profile before enabling SMS verification.',
      );
      expect(_backend.smsSetupCode, isNull);
    });

    test(
      'the route says which way the code went and the switch follows it',
      () async {
        await _signIn();
        _backend.security['phone'] = '+92 300 0000000';
        await _account.load(force: true);

        final sms = await _account.startSms();
        expect(sms!.channel, 'sms');
        expect(sms.message, 'A verification code was sent to your phone.');

        // An unconfigured Twilio is not a dead end: the same setup arrives by
        // email, and the app says so in the route's words.
        _backend.smsDeliveryFails = true;
        final email = await _account.startSms();
        expect(email!.channel, 'email');
        expect(
          email.message,
          'SMS provider unavailable. A setup code was sent to your email instead.',
        );

        expect(await _account.confirmSms('111111'), isFalse);
        expect(_account.errorMessage, 'Invalid or expired verification code.');
        expect(_account.security!.sms, isFalse);

        expect(await _account.confirmSms(_backend.smsSetupCode!), isTrue);
        expect(_account.security!.sms, isTrue);

        expect(await _account.removeSms(), isTrue);
        expect(_account.security!.sms, isFalse);
      },
    );
  });

  group('linked providers', () {
    test(
      'only the oauth route disconnects one, and only by its name',
      () async {
        await _signIn();
        _backend.security['googleId'] = 'google-1';
        await _account.load(force: true);
        expect(_account.googleLinked, isTrue);

        expect(await _account.unlinkProvider('facebook'), isFalse);
        expect(_account.errorMessage, 'Invalid provider.');
        expect(_backend.security['googleId'], 'google-1');

        expect(await _account.unlinkProvider('google'), isTrue);
        expect(_backend.bodyFor('/api/account/security/oauth'), {
          'provider': 'google',
        });
        expect(_backend.security['googleId'], isNull);
        // The password the account also has is left where it was.
        expect(_backend.storedPassword, FakeBackend.validPassword);
        expect(_account.googleLinked, isFalse);
      },
    );
  });

  group('billing methods', () {
    test('a card survives only as its last four and an expiry', () async {
      await _signIn();
      expect(
        await _account.saveCard(
          cardNumber: '4321876512349995',
          firstName: 'Arslan',
          lastName: 'Sabir',
          expMonth: '11',
          expYear: '2030',
          securityCode: '123',
        ),
        isTrue,
      );

      expect(_backend.billingMethods.single['cardLast4'], '9995');
      expect(
        _account.billingMethod!.accountDetails,
        'Arslan Sabir ···· 9995 · Exp 11/2030',
      );
      // Neither the number the form was typed with nor the CVV is kept.
      final stored = jsonEncode(_backend.billingMethods.single);
      expect(stored, isNot(contains('4321876512349995')));
      expect(stored, isNot(contains('87651234')));
      expect(stored, isNot(contains('securityCode')));
    });

    test('the second save replaces the method the route holds', () async {
      await _signIn();
      expect(
        await _account.saveWallet(
          method: 'JAZZCASH',
          accountName: 'Arslan Sabir',
          walletAccount: '03001234567',
        ),
        isTrue,
      );
      expect(
        await _account.saveWallet(
          method: 'EASYPAISA',
          accountName: 'Arslan Sabir',
          walletAccount: '03451234567',
        ),
        isTrue,
      );

      expect(_account.billing.length, 1);
      expect(_account.billingMethod!.method, 'EASYPAISA');
      expect(_backend.billingMethods.single['label'], 'EasyPaisa');
    });

    test(
      'a method the route will not take comes back in its own words',
      () async {
        await _signIn();
        expect(
          await _account.saveCard(
            cardNumber: '42424242',
            firstName: 'Arslan',
            lastName: 'Sabir',
            expMonth: '1',
            expYear: '2030',
            securityCode: '123',
          ),
          isFalse,
        );
        expect(_account.errorMessage, 'Enter a valid card number.');

        expect(
          await _account.saveWallet(
            method: 'PAYPAL',
            accountName: 'Arslan Sabir',
            walletAccount: '03001234567',
          ),
          isFalse,
        );
        expect(_account.errorMessage, 'Choose a valid method.');

        expect(
          await _account.saveWallet(
            method: 'JAZZCASH',
            accountName: 'Arslan Sabir',
            walletAccount: '030',
          ),
          isFalse,
        );
        expect(
          _account.errorMessage,
          'Enter a valid JazzCash account number (5–80 characters).',
        );
        expect(_account.billing, isEmpty);
      },
    );

    test('removing it empties the list the route answers with', () async {
      await _signIn();
      await _account.saveWallet(
        method: 'JAZZCASH',
        accountName: 'Arslan Sabir',
        walletAccount: '03001234567',
      );
      expect(await _account.removeBilling(), isTrue);
      expect(_account.billing, isEmpty);
      expect(_backend.billingMethods, isEmpty);
    });
  });

  group('withdrawal accounts', () {
    test('the route labels an account that was given none', () async {
      await _signIn();
      expect(
        await _account.saveWithdrawal(
          method: 'BANK_TRANSFER',
          accountDetails: 'PK36BAIK0001234567',
        ),
        isTrue,
      );

      expect(_account.withdrawals.single.label, 'Bank transfer');
      expect(_backend.withdrawalMethods.single['method'], 'BANK_TRANSFER');
    });

    test('five accounts is the most the route keeps', () async {
      await _signIn();
      for (int index = 0; index < 5; index++) {
        expect(
          await _account.saveWithdrawal(
            method: 'JAZZCASH',
            accountDetails: '0300123456$index',
          ),
          isTrue,
        );
      }
      expect(
        await _account.saveWithdrawal(
          method: 'EASYPAISA',
          accountDetails: '03459999999',
        ),
        isFalse,
      );
      expect(_account.errorMessage, 'You can save up to 5 withdrawal methods.');
      expect(_account.withdrawals.length, 5);
    });

    test('details too short for the schema are refused', () async {
      await _signIn();
      expect(
        await _account.saveWithdrawal(
          method: 'JAZZCASH',
          accountDetails: '0300',
        ),
        isFalse,
      );
      expect(
        _account.errorMessage,
        'Enter valid account details (5–300 characters).',
      );
      expect(_backend.withdrawalMethods, isEmpty);
    });

    test('removal names the row by the id the route gave it', () async {
      await _signIn();
      await _account.saveWithdrawal(
        method: 'JAZZCASH',
        accountDetails: '03001234567',
      );
      await _account.saveWithdrawal(
        method: 'EASYPAISA',
        accountDetails: '03451234567',
      );
      final first = _account.withdrawals.first.id;

      expect(await _account.removeWithdrawal(''), isFalse);
      expect(_account.errorMessage, 'Missing method id.');

      expect(await _account.removeWithdrawal(first), isTrue);
      expect(_account.withdrawals.single.method, 'EASYPAISA');
      expect(_backend.withdrawalMethods.length, 1);
    });

    test('a withdrawal account is not a billing method and the other way '
        'round', () async {
      await _signIn();
      await _account.saveWithdrawal(
        method: 'JAZZCASH',
        accountDetails: '03001234567',
      );
      expect(_account.billing, isEmpty);
      expect(_backend.billingMethods, isEmpty);

      await _account.saveWallet(
        method: 'EASYPAISA',
        accountName: 'Arslan Sabir',
        walletAccount: '03451234567',
      );
      expect(_account.withdrawals.length, 1);
      expect(_backend.withdrawalMethods.length, 1);
    });
  });

  group('profile settings', () {
    const ProfileSettings chosen = (
      visibility: 'PRIVATE',
      workGoal: 'Short-term projects only',
      earningPrivacy: 'CLIENTS',
      experienceLevel: 'BEGINNER',
      interestSlugs: ['web-development'],
      githubUrl: '',
      websiteUrl: '',
      youtubeUrl: '',
    );

    test('one write carries everything the route replaces', () async {
      await _signIn();
      expect(await ProfileController.instance.saveSettings(chosen), isTrue);

      final body = _backend.bodyFor('/api/profile');
      expect(body['profileVisibility'], 'PRIVATE');
      expect(body['earningPrivacy'], 'CLIENTS');
      expect(body['workGoal'], 'Short-term projects only');
      expect(body['interestSlugs'], ['web-development']);
      expect(
        body.keys,
        containsAll(['name', 'title', 'bio', 'skills', 'hourlyRate']),
      );
      expect(ProfileController.instance.settings, chosen);
    });

    test('a slug the backend does not offer is not stored', () async {
      await _signIn();
      expect(
        await ProfileController.instance.saveSettings((
          visibility: 'PUBLIC',
          workGoal: 'Both short-term and long-term projects',
          earningPrivacy: 'EVERYONE',
          experienceLevel: 'PRO',
          interestSlugs: ['writing', 'not-a-category'],
          githubUrl: '',
          websiteUrl: '',
          youtubeUrl: '',
        )),
        isTrue,
      );
      expect(_backend.storedInterestSlugs, ['writing']);
    });

    test(
      'a category-less save is refused before anything is written',
      () async {
        await _signIn();
        expect(
          await ProfileController.instance.saveSettings((
            visibility: 'PRIVATE',
            workGoal: 'Short-term projects only',
            earningPrivacy: 'CLIENTS',
            experienceLevel: 'BEGINNER',
            interestSlugs: const <String>[],
            githubUrl: '',
            websiteUrl: '',
            youtubeUrl: '',
          )),
          isFalse,
        );
        expect(
          ProfileController.instance.errorMessage,
          'Select at least one category.',
        );
        // Only the read that opened the account touched the profile route.
        expect(_backend.countOf('/api/profile'), 1);
      },
    );

    test('a link longer than the schema allows is refused', () async {
      await _signIn();
      expect(
        await ProfileController.instance.saveLinkedAccounts(
          githubUrl: 'https://example.com/${'a' * 300}',
          websiteUrl: '',
          youtubeUrl: '',
        ),
        isFalse,
      );
      expect(
        ProfileController.instance.errorMessage,
        'GitHub link cannot be longer than 300 characters.',
      );
    });

    test('the saved settings are what a reopen shows', () async {
      await _signIn();
      await ProfileController.instance.saveSettings(chosen);

      ProfileController.instance.clear();
      await ProfileController.instance.load();
      expect(ProfileController.instance.settings.visibility, 'PRIVATE');
      expect(ProfileController.instance.settings.githubUrl, isEmpty);
    });

    test('a profile write keeps the phone the security route reported', () async {
      await _signIn();
      _backend.security['phone'] = '+92 300 0000000';
      await _account.load(force: true);

      await ProfileController.instance.saveIdentity(
        title: 'Developer',
        hourlyRate: '25',
        bio: 'I build Flutter apps.',
      );
      // The profile route nulls a phone the body leaves out, so the number that
      // gates SMS verification has to travel with every profile save.
      expect(_backend.bodyFor('/api/profile')['phone'], '+92 300 0000000');
      expect(_backend.security['phone'], '+92 300 0000000');
    });

    test('a signed-out device writes nothing', () async {
      await _signIn();
      ProfileController.instance.clear();
      expect(await ProfileController.instance.saveSettings(chosen), isFalse);
      expect(_backend.storedVisibility, isNull);
    });
  });
}
