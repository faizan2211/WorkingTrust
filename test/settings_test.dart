import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/core/widgets/app_card.dart';
import 'package:working_trust/features/finance/controller/overview_controller.dart';
import 'package:working_trust/features/finance/controller/wallet_controller.dart';
import 'package:working_trust/features/finance/controller/withdrawals_controller.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/settings/controller/account_controller.dart';
import 'package:working_trust/features/settings/screens/settings_screen.dart';
import 'package:working_trust/features/settings/widgets/settings_primitives.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

Map<String, WidgetBuilder> routeTable() =>
    Map<String, WidgetBuilder>.of(AppRoutes.routes)
      ..remove(Navigator.defaultRouteName);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String hint, String value) async {
  await tester.enterText(find.widgetWithText(TextField, hint), value);
  await tester.pump();
}

/// Types into a field the tabs already prefilled, where the hint is no longer
/// the only text on screen — the label above the control identifies it.
Future<void> _typeField(WidgetTester tester, String label, String value) async {
  final field = find.descendant(
    of: find.widgetWithText(FieldBlock, label),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, value);
  await tester.pump();
}

/// Matches a loaded asset image, which is how the brand marks are drawn.
Finder _assetImage(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == name,
);

/// Snacks queue, so let a message expire before the next one is asserted.
Future<void> _drainSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pump();
}

/// The messenger shows one snack at a time, so a queued message can hide the
/// one a test is about to assert. Empty the whole queue first.
Future<void> _drainSnacks(WidgetTester tester) async {
  for (var attempt = 0; attempt < 6; attempt++) {
    if (find.byType(SnackBar).evaluate().isEmpty) return;
    await _drainSnack(tester);
  }
}

/// A signed-in device, so the tabs can read the account routes they are built on.
Future<void> _openSettings(
  WidgetTester tester, {
  double width = 400,
  String? googleId,
}) async {
  await _backend.install();
  // The install resets the account, so a provider id has to be filed after it.
  if (googleId != null) _backend.security['googleId'] = googleId;
  _backend.issueSessionCookie();
  ProfileController.instance.clear();
  await ProfileController.instance.load();
  AccountController.instance.clear();
  // The money figures are read by singletons too, so a tab that opens must ask
  // for them rather than keep what an earlier test saw.
  OverviewController.instance.clear();
  WithdrawalsController.instance.clear();
  WalletController.instance.clear();
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(routes: routeTable(), home: const SettingsScreen()),
  );
  await _settle(tester);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await _settle(tester);
}

/// The title of the job [FakeBackend.assignments] gains from [_addPayableJob].
const String _payableJobTitle =
    'Mobile App UI Design in Figma for a Delivery Service';

/// One approved job on the account with no withdrawal against it, priced by its
/// own task rather than by a number the test hands the app.
void _addPayableJob() {
  final now = DateTime.now().toUtc().toIso8601String();
  _backend.assignments.add({
    'id': 'a9',
    'userId': _backend.sessionId,
    'taskId': 't3',
    'bidId': null,
    'status': 'APPROVED',
    'payoutAmount': null,
    'dueAt': now,
    'createdAt': now,
    'updatedAt': now,
  });
}

/// The `billingMethods` entry a payout request looks for, in the shape the
/// billing tab's own save writes.
void _addBillingMethod() {
  _backend.billingMethods.add({
    'id': 'bm_test',
    'method': 'JAZZCASH',
    'label': 'JazzCash',
    'accountName': 'Arslan Sabir',
    'walletAccount': '03001234567',
    'accountDetails': 'Arslan Sabir · 03001234567',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });
}

void main() {
  testWidgets('profile setting shows the visibility, experience and account '
      'blocks', (tester) async {
    await _openSettings(tester);

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Visibility'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Experience Level'), findsOneWidget);
    expect(find.text('Entry level'), findsOneWidget);
    // The categories card has nothing to show until the account picks some, so
    // it says so instead of listing a made-up field.
    expect(find.text('Categories'), findsOneWidget);
    expect(
      find.text('No category is chosen yet. Pick at least one.'),
      findsOneWidget,
    );
    expect(find.text('Linked Account'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(_assetImage('assets/icons/github.png'), findsOneWidget);
    expect(find.byIcon(Icons.smart_display), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tab strip lines up with the cards below it', (tester) async {
    await _openSettings(tester);

    final label = tester.getTopLeft(find.text('Profile Setting')).dx;
    final card = tester.getTopLeft(find.byType(AppCard).first).dx;
    expect(
      label,
      closeTo(card, 4),
      reason: 'the scrollable tab strip must not indent past the content',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('experience level moves when another card is tapped', (
    tester,
  ) async {
    await _openSettings(tester);

    int selected() =>
        tester.widgetList<Icon>(find.byIcon(Icons.radio_button_checked)).length;
    expect(selected(), 1);
    await _tap(tester, find.text('Entry level'));
    expect(find.text('I am relatively new to this field'), findsOneWidget);
    expect(selected(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categories come from the backend and save with the profile', (
    tester,
  ) async {
    await _openSettings(tester);

    await _tap(tester, find.byTooltip('Choose categories'));
    expect(find.text('Choose your categories'), findsOneWidget);
    await _tap(tester, find.text('Graphic Design'));
    await _tap(tester, find.text('Done'));

    expect(find.text('Graphic Design'), findsWidgets);

    await _tap(tester, find.text('Save Changes'));
    expect(find.text('Profile settings saved.'), findsOneWidget);
    // The slug the route resolves against its own table is what is stored.
    expect(_backend.profileUpdate!['interestSlugs'], ['graphic-design']);
    expect(_backend.storedInterestSlugs, ['graphic-design']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a link is kept as a draft until the profile is saved', (
    tester,
  ) async {
    await _openSettings(tester);

    // The route keeps a category list, and the profile needs at least one
    // before it will write, so a field is picked first.
    await _tap(tester, find.byTooltip('Choose categories'));
    await _tap(tester, find.text('Graphic Design'));
    await _tap(tester, find.text('Done'));

    await _tap(tester, find.byTooltip('Edit GitHub'));
    expect(find.text('Link GitHub'), findsOneWidget);
    await _type(tester, 'https://github.com/username', 'github.com/arslan');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));

    expect(find.text('github.com/arslan'), findsOneWidget);
    expect(find.text('GitHub saved.'), findsOneWidget);
    // The dialog only edits the draft; nothing was written to the profile.
    expect(_backend.profileUpdate, isNull);

    await _tap(tester, find.text('Save Changes'));
    expect(_backend.storedGithubUrl, 'github.com/arslan');
    await _drainSnacks(tester);

    // An empty answer is an answer: the route clears a column sent empty.
    await _tap(tester, find.byTooltip('Edit GitHub'));
    // The row prefills the link it already holds, so the dialog's own field is
    // cleared by type rather than by its hint.
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '',
    );
    await tester.pump();
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('GitHub unlinked.'), findsOneWidget);
    await _drainSnacks(tester);

    await _tap(tester, find.text('Save Changes'));
    expect(_backend.profileUpdate!['githubUrl'], isEmpty);
    expect(_backend.storedGithubUrl, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password fields reveal, validate and reach the route', (
    tester,
  ) async {
    await _openSettings(tester);
    await _openTab(tester, 'Password & Security');

    expect(find.text('Two-step verification'), findsOneWidget);
    expect(find.text('Login details'), findsOneWidget);

    await _tap(tester, find.byTooltip('Show password').first);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Enter your current password'),
          )
          .obscureText,
      isFalse,
    );

    await _type(tester, 'Enter your current password', 'demo1234');
    await _type(tester, 'Create strong password', 'newpassword1');
    await _type(tester, 'Confirm password', 'differentpassword');
    await _tap(tester, find.text('Update Password'));
    expect(find.text('The two passwords do not match'), findsOneWidget);
    // Nothing was sent while the form itself disagreed.
    expect(_backend.countOf('/api/account/password'), 0);
    expect(tester.takeException(), isNull);

    await _type(tester, 'Confirm password', 'newpassword1');
    await _tap(tester, find.text('Update Password'));
    expect(find.text('Password updated.'), findsOneWidget);
    expect(_backend.storedPassword, 'newpassword1');
    // The typed passwords are not left on screen after the change.
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Create strong password'),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('two-step switches write to the security route', (tester) async {
    await _openSettings(tester);
    await _openTab(tester, 'Password & Security');

    final switches = find.byType(Switch);
    expect(tester.widget<Switch>(switches.first).value, isFalse);

    await _tap(tester, switches.first);
    expect(_backend.security['twoStepMobileApp'], isTrue);
    expect(tester.widget<Switch>(switches.first).value, isTrue);
    await _drainSnack(tester);

    // The account has no phone, so the route refuses SMS and the switch stays
    // where the server left it.
    await _tap(tester, switches.at(1));
    expect(
      find.textContaining('Add a phone number to your profile'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
    expect(_backend.security['twoStepSms'], isNot(true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a provider this account does not link cannot be linked from '
      'here', (tester) async {
    await _openSettings(tester);
    await _openTab(tester, 'Password & Security');

    expect(find.text('Google'), findsOneWidget);
    await _tap(tester, find.text('Google'));
    expect(find.textContaining('completed in a browser'), findsOneWidget);
    expect(_backend.countOf('/api/account/security/oauth'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a linked provider is disconnected only through the oauth '
      'route', (tester) async {
    await _openSettings(tester, googleId: 'google-1');
    await _openTab(tester, 'Password & Security');

    expect(find.text('Google connected'), findsOneWidget);
    await _tap(tester, find.text('Google connected'));
    expect(find.text('Disconnect Google?'), findsOneWidget);
    await _tap(tester, find.text('Keep it'));
    expect(_backend.countOf('/api/account/security/oauth'), 0);
    expect(_backend.security['googleId'], 'google-1');

    await _tap(tester, find.text('Google connected'));
    await _tap(tester, find.widgetWithText(TextButton, 'Disconnect'));
    expect(_backend.bodyFor('/api/account/security/oauth'), {
      'provider': 'google',
    });
    expect(_backend.security['googleId'], isNull);
    // The read after the write is what puts the button back to "Google".
    expect(find.text('Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('contact info is prefilled and savable', (tester) async {
    await _openSettings(tester);
    await _openTab(tester, 'Contact Info');

    expect(find.text('u1'), findsOneWidget);
    expect(find.text('Someone'), findsOneWidget);
    expect(find.text(FakeBackend.validEmail), findsOneWidget);
    expect(find.text('Time Zone'), findsOneWidget);
    expect(find.text('UTC+05:00 Islamabad, Karachi'), findsOneWidget);

    await _tap(tester, find.byType(DropdownButton<String>).at(1));
    await _tap(tester, find.text('United Kingdom'));
    expect(find.text('United Kingdom'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _typeField(tester, 'Name', 'Arslan Sabir');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('Account details saved.'), findsOneWidget);
    expect(_backend.storedName, 'Arslan Sabir');

    // The location block is the contact route's other section, and it is the
    // only place these four values can be kept.
    await _tap(tester, find.text('Save Changes'));
    expect(_backend.storedLocation['country'], 'United Kingdom');
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification groups expose their own option lists', (
    tester,
  ) async {
    await _openSettings(tester);
    await _openTab(tester, 'Notification');

    expect(find.text('Desktop'), findsOneWidget);
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(
      find.text('Send an email with unread activity for:'),
      findsOneWidget,
    );
    expect(find.text('Immediately'), findsOneWidget);

    await _tap(tester, find.byType(DropdownButton<String>).last);
    await _tap(tester, find.text('Daily'));
    expect(find.text('Daily'), findsWidgets);

    await _tap(tester, find.text('Save Changes'));
    expect(find.text('Notification settings saved.'), findsOneWidget);
    expect(jsonDecode(_backend.prefsColumn!)['emailFrequency'], 'DAILY');
    expect(tester.takeException(), isNull);
  });

  testWidgets('withdrawals shows the balance, the pending total and the payout '
      'rows the server reports', (tester) async {
    await _openSettings(tester);
    await _openTab(tester, 'Withdrawals');

    expect(find.text('Available balance'), findsOneWidget);
    // Both figures are the overview route's own: the stored balance and the sum
    // of the requests still waiting to be paid.
    expect(find.text(r'$1240.50'), findsOneWidget);
    expect(find.text(r'+$400.00 pending'), findsOneWidget);
    expect(find.text(r'$27.00'), findsNothing);
    expect(find.text(r'+$120.00 pending'), findsNothing);

    // The history is the Transactions feed asked for its Withdrawal type alone,
    // so a row here is the same row that page shows.
    expect(find.text('Recent withdrawals'), findsOneWidget);
    expect(find.text(r'-$400.00'), findsOneWidget);
    expect(find.text(r'-$250.00'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    final feed = _backend.requests.lastWhere(
      (each) => each.url.path == '/api/reports/transactions',
    );
    expect(feed.url.queryParameters['type'], 'Withdrawal');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved withdrawal account round-trips through the route', (
    tester,
  ) async {
    await _openSettings(tester);
    await _openTab(tester, 'Withdrawals');

    expect(
      find.text("You haven't set up any withdrawal methods yet."),
      findsOneWidget,
    );

    await _tap(tester, find.text('Add a Method'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Bank transfer'),
      ),
    );
    await _type(
      tester,
      'Mobile number or account number',
      'PK36BAIK0001234567',
    );
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save'));
    expect(find.text('Withdrawal account saved.'), findsOneWidget);
    // The method token and the label the route names for it are what is kept.
    expect(_backend.withdrawalMethods.single['method'], 'BANK_TRANSFER');
    expect(_backend.withdrawalMethods.single['label'], 'Bank transfer');
    expect(
      find.text('PK36BAIK0001234567'),
      findsOneWidget,
      reason: 'the saved account comes back on the list the route answered',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a balance the column does not hold is a dash, never zero', (
    tester,
  ) async {
    await _openSettings(tester);
    _backend.storedBalance = null;
    await _openTab(tester, 'Withdrawals');

    expect(find.text('—'), findsWidgets);
    expect(find.text(r'$0.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a withdrawal request names approved jobs and lets the server '
      'price them', (tester) async {
    await _openSettings(tester);
    _addPayableJob();
    _addBillingMethod();
    await _openTab(tester, 'Withdrawals');
    expect(find.text(r'$1240.50'), findsOneWidget);

    await _tap(tester, find.text('Withdrawal now'));
    expect(find.text('Withdraw funds'), findsOneWidget);
    // The one job offered is the one the wallet reports with no request against
    // it, at the amount its own task carries.
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text(r'$480.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(r'$120.00')),
      findsNothing,
    );
    await _tap(
      tester,
      find.descendant(of: sheet, matching: find.text(_payableJobTitle)),
    );
    await _tap(tester, find.text('Request Withdrawal (1)'));
    await _settle(tester);
    await _settle(tester);

    expect(find.text('Withdrawal requested for 1 job.'), findsOneWidget);
    final row = _backend.withdrawals.singleWhere(
      (each) => each['assignmentId'] == 'a9',
    );
    // The route priced the job off its task and left the request pending.
    expect(row['amount'], 480.0);
    expect(row['status'], 'PENDING');
    // What the device sent was the job id, and nothing else.
    final request = _backend.requests.lastWhere(
      (each) => each.url.path == '/api/withdrawals',
    );
    expect(jsonDecode(request.body), {
      'assignmentIds': ['a9'],
    });
    // Both figures are read back from the routes rather than corrected here.
    expect(find.text(r'$760.50'), findsOneWidget);
    expect(find.text(r'+$880.00 pending'), findsOneWidget);
    expect(find.text(r'-$480.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tab repeats the server\'s refusal and moves nothing', (
    tester,
  ) async {
    await _openSettings(tester);
    _addPayableJob();
    await _openTab(tester, 'Withdrawals');

    await _tap(tester, find.text('Withdrawal now'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(_payableJobTitle),
      ),
    );
    await _tap(tester, find.text('Request Withdrawal (1)'));
    await _settle(tester);

    // A payout needs the billing method on the account, which only the route
    // can say — and its own words are what the snack carries.
    expect(
      find.text('Add a payment method before requesting a withdrawal.'),
      findsOneWidget,
    );
    expect(
      _backend.withdrawals.map((each) => each['assignmentId']),
      isNot(contains('a9')),
    );
    expect(_backend.storedBalance, 1240.50);
    expect(find.text(r'$1240.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no approved job left to pay out nothing is sent', (
    tester,
  ) async {
    await _openSettings(tester);
    await _openTab(tester, 'Withdrawals');

    await _tap(tester, find.text('Withdrawal now'));

    expect(
      find.text('No approved job is waiting to be paid out.'),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(_backend.countOf('/api/withdrawals'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the money tab re-reads it and pulling another tab asks '
      'for none of it', (tester) async {
    await _openSettings(tester);
    await _openTab(tester, 'Withdrawals');
    expect(_backend.countOf('/api/reports/overview'), 1);
    final before =
        _backend.countOf('/api/reports/overview') +
        _backend.countOf('/api/reports/transactions');

    await tester.drag(find.text('Available balance'), const Offset(0, 420));
    await _settle(tester);
    await _settle(tester);

    expect(
      _backend.countOf('/api/reports/overview') +
          _backend.countOf('/api/reports/transactions'),
      greaterThan(before),
    );

    await _openTab(tester, 'Notification');
    final untouched = _backend.countOf('/api/reports/overview');
    await tester.drag(find.text('Email'), const Offset(0, 420));
    await _settle(tester);
    await _settle(tester);

    expect(_backend.countOf('/api/reports/overview'), untouched);
    expect(tester.takeException(), isNull);
  });

  testWidgets('billing keeps a wallet, then a card reduced to its last four', (
    tester,
  ) async {
    await _openSettings(tester);
    await _openTab(tester, 'Billing & Payments');

    expect(find.text('Billing methods'), findsOneWidget);
    expect(
      find.textContaining('charged only when you make a purchase'),
      findsOneWidget,
    );

    await _tap(tester, find.text('Add a billing method'));
    expect(find.text('Add billing methods'), findsOneWidget);

    // An empty form is answered on the device, not sent to the route.
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save'));
    expect(find.textContaining('are missing.'), findsOneWidget);
    expect(_backend.billingMethods, isEmpty);
    await _drainSnack(tester);

    await _tap(tester, find.text('JazzCash'));
    await _type(tester, 'Account name', 'Arslan Sabir');
    await _type(tester, 'JazzCash account number', '03001234567');
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save'));
    expect(
      find.text('Arslan Sabir · 03001234567 is your billing method.'),
      findsOneWidget,
    );
    expect(_backend.billingMethods.single['method'], 'JAZZCASH');
    await _drainSnack(tester);

    // One method per account, so this second save replaces the wallet.
    await _tap(tester, find.text('Replace the billing method'));
    expect(find.byTooltip('PayPal'), findsOneWidget);
    expect(find.byTooltip('Amex'), findsNothing);
    expect(find.byTooltip('Diners Club'), findsOneWidget);

    await _tap(tester, find.byTooltip('Mastercard'));
    await _type(tester, 'Card number', '4321876512349995');
    await _type(tester, 'First Name', 'Arslan');
    await _type(tester, 'Last Name', 'Sabir');
    await _type(tester, 'Expiration month', '11');
    await _type(tester, 'Expiration year', '2030');
    await _type(tester, 'Security code', '123');
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save'));
    expect(
      find.text('Arslan Sabir ···· 9995 · Exp 11/2030 is your billing method.'),
      findsOneWidget,
    );
    // Only the last four and the expiry survive the round trip.
    final stored = jsonEncode(_backend.billingMethods.single);
    expect(_backend.billingMethods.single['cardLast4'], '9995');
    expect(stored, isNot(contains('4321876512349995')));
    expect(stored, isNot(contains('12349995')));
    expect(stored, isNot(contains('securityCode')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the billing panel can be cancelled', (tester) async {
    await _openSettings(tester);
    await _openTab(tester, 'Billing & Payments');

    await _tap(tester, find.text('Add a billing method'));
    expect(find.text('Debit or credit card'), findsOneWidget);
    await _tap(tester, find.text('Cancel'));
    expect(find.text('Add billing methods'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card form fits a narrow phone', (tester) async {
    await _openSettings(tester, width: 320);
    await _openTab(tester, 'Billing & Payments');

    await _tap(tester, find.text('Add a billing method'));
    expect(find.byTooltip('Visa'), findsOneWidget);
    expect(find.byTooltip('Diners Club'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab renders from phone to desktop width', (tester) async {
    const markers = {
      'Profile Setting': 'My Profile',
      'Password & Security': 'Two-step verification',
      'Contact Info': 'Location',
      'Notification': 'Email',
      'Withdrawals': 'Withdrawal methods',
      'Billing & Payments': 'Billing methods',
    };
    for (final width in [320.0, 700.0, 1200.0]) {
      await _openSettings(tester, width: width);
      for (final entry in markers.entries) {
        await _openTab(tester, entry.key);
        expect(
          find.text(entry.value),
          findsWidgets,
          reason: '${entry.key} at ${width}dp',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} at ${width}dp',
        );
      }
    }
  });

  testWidgets('settings keeps its route', (tester) async {
    expect(AppRoutes.routes.containsKey(RouteNames.settings), isTrue);
    await _openSettings(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
