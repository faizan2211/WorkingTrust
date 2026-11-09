/// The account settings the `/api/account/…` routes store, in the words the
/// backend itself uses.
library;

/// The three two-step switches, plus what the security route reports about the
/// account around them.
typedef SecuritySettings = ({
  bool mobileApp,
  bool sms,
  bool authenticator,
  bool authenticatorConfigured,
  bool googleLinked,
  bool appleLinked,
  String phone,
  String email,
});

/// The six keys `/api/account/notifications` keeps as one JSON column. Values
/// are the backend's own tokens, never the labels shown in a dropdown.
typedef NotificationPreferences = ({
  String desktopShow,
  String desktopCounter,
  String mobileShow,
  String mobileCounter,
  String emailShow,
  String emailFrequency,
});

/// What `PATCH /api/account/contact` answers with: the row it wrote and the
/// sentence the web shows for it.
typedef ContactResult = ({String message, String name, String email});

/// The four columns the location section writes. There is no read endpoint for
/// them, so a device only knows what it saved itself.
typedef ProfileLocation = ({
  String timezone,
  String country,
  String stateProvince,
  String city,
});

/// The values the location section starts from before this device has saved
/// one.
const ProfileLocation emptyLocation = (
  timezone: '',
  country: '',
  stateProvince: '',
  city: '',
);

/// The profile-settings columns `PATCH /api/profile` writes and Settings edits.
/// The three URL values remain in this cached record for compatibility, but
/// Profile → About now reads and writes them from the server-backed profile.
typedef ProfileSettings = ({
  String visibility,
  String workGoal,
  String earningPrivacy,
  String experienceLevel,
  List<String> interestSlugs,
  String githubUrl,
  String websiteUrl,
  String youtubeUrl,
});

/// What the account's columns leave unset, in the words the web's own settings
/// form falls back to, so this device shows the same thing the web does for an
/// account that has never touched them.
const ProfileSettings defaultProfileSettings = (
  visibility: 'PUBLIC',
  workGoal: 'Both short-term and long-term projects',
  earningPrivacy: 'EVERYONE',
  experienceLevel: 'PRO',
  interestSlugs: <String>[],
  githubUrl: '',
  websiteUrl: '',
  youtubeUrl: '',
);

/// `profileVisibility` — the enum has two tokens, and the second one covers both
/// "Only me" and the web's "Private" wording.
const Map<String, String> profileVisibilityLevels = {
  'PUBLIC': 'Public',
  'PRIVATE': 'Only me',
};

/// `workGoal`: the column stores the sentence it displays, so token and label are
/// the same text. These are the web's `PROJECT_PREFERENCES`, exactly.
const List<String> workGoalOptions = [
  'Both short-term and long-term projects',
  'Short-term projects only',
  'Long-term projects only',
];

/// `earningPrivacy`.
const Map<String, String> earningPrivacyLevels = {
  'EVERYONE': 'Everyone',
  'CLIENTS': 'Clients I hire',
  'ONLY_ME': 'Only me',
};

/// `interestSlugs` — how many the picker lets one account tick. The schema allows
/// twelve; the web's own picker stops at eight, and this follows it.
const int categorySelectionLimit = 8;

/// The profile columns a write has to re-send and no read reports, each one
/// present only when this device actually holds a value for it.
///
/// `PATCH /api/profile` replaces the whole profile, so a save that knows the
/// account's phone or categories has to send them along — while a save for an
/// account this device has never read must leave them out and let the columns
/// stand. A null here is therefore "unknown", not "empty".
typedef ProfileContext = ({
  String? phone,
  ProfileLocation? location,
  ProfileSettings? settings,
});

/// One saved payment method, exactly as `/api/account/billing` reports it. A
/// card row only ever carries `cardLast4` with the name and expiry — the
/// account number the route was given is not in any of these fields, because
/// the server never kept it either.
typedef SavedBillingMethod = ({
  String id,
  String method,
  String label,
  String accountDetails,
  String createdAt,
  String firstName,
  String lastName,
  String cardLast4,
  String expMonth,
  String expYear,
  String walletAccount,
  String accountName,
});

/// One saved withdrawal account from `/api/account/withdrawals`. Listing it
/// here does not make it payable: withdrawal processing reads the separate
/// billing column, and this route owns only its own list.
typedef SavedWithdrawalMethod = ({
  String id,
  String method,
  String label,
  String accountDetails,
  String createdAt,
});

/// What `POST /api/account/security/totp` answers with. The route holds the
/// secret as pending until a code from the app is confirmed, so showing this
/// enables nothing by itself.
typedef TotpSetup = ({String secret, String otpauthUrl});

/// What `POST /api/account/security/sms` answers with: which way the code went,
/// and the server's own sentence about it. `channel` is `"sms"`, or `"email"`
/// when the SMS provider could not be used.
typedef SmsSetup = ({String channel, String message});

/// `BILLING_METHOD_TYPES` and `BILLING_METHOD_LABELS` on the backend.
const Map<String, String> billingMethodTypes = {
  'CARD': 'Debit or credit card',
  'JAZZCASH': 'JazzCash',
  'EASYPAISA': 'EasyPaisa',
};

/// `WITHDRAWAL_METHOD_TYPES` and `WITHDRAWAL_METHOD_LABELS`. The bank transfer
/// has no billing counterpart, and the two wallets mean different things in
/// each list.
const Map<String, String> withdrawalMethodTypes = {
  'EASYPAISA': 'EasyPaisa',
  'JAZZCASH': 'JazzCash',
  'BANK_TRANSFER': 'Bank transfer',
};

/// The route replaces the method it already holds rather than adding a second.
const int billingMethodLimit = 1;

/// The count `POST /api/account/withdrawals` refuses beyond.
const int withdrawalMethodLimit = 5;

/// `ACTIVITY_LEVELS` and `ACTIVITY_LEVEL_LABELS` on the backend.
const Map<String, String> activityLevels = {
  'ALL': 'All activity',
  'IMPORTANT': 'Important activity only',
  'NONE': 'Nothing',
};

/// `COUNTER_LEVELS` and `COUNTER_LEVEL_LABELS`. The counter has a
/// messages-only level the activity lists do not.
const Map<String, String> counterLevels = {
  'ALL': 'All activity',
  'MESSAGES': 'Direct messages only',
  'NONE': 'Nothing',
};

/// `EMAIL_FREQUENCIES` and `EMAIL_FREQUENCY_LABELS`.
const Map<String, String> emailFrequencies = {
  'IMMEDIATE': 'Immediately',
  'DAILY': 'Daily',
  'WEEKLY': 'Weekly',
  'NEVER': 'Never',
};

/// The values the route answers with when the account has never set anything,
/// which is what the app shows until the GET returns.
const NotificationPreferences defaultPreferences = (
  desktopShow: 'ALL',
  desktopCounter: 'ALL',
  mobileShow: 'ALL',
  mobileCounter: 'ALL',
  emailShow: 'ALL',
  emailFrequency: 'IMMEDIATE',
);
