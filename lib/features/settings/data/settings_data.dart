import 'package:flutter/material.dart';

import '../models/account_settings.dart';

/// Content for the Settings screen. The option lists here are picker choices;
/// the account settings keep theirs in [account_settings.dart] so they match the
/// values the backend accepts.
class SettingsData {
  SettingsData._();

  static const List<String> tabs = [
    'Profile Setting',
    'Password & Security',
    'Contact Info',
    'Notification',
    'Withdrawals',
    'Billing & Payments',
  ];

  /// The three experience cards, in the tokens `PATCH /api/profile` stores and
  /// the words the design shows.
  static const List<({String value, String title, String description})>
  experienceLevels = [
    (
      value: 'BEGINNER',
      title: 'Entry level',
      description: 'I am relatively new to this field',
    ),
    (
      value: 'INTERMEDIATE',
      title: 'Intermediate',
      description: 'I have substantial experience in this field',
    ),
    (
      value: 'PRO',
      title: 'Expert',
      description: 'I have comprehensive and deep expertise in this field',
    ),
  ];

  static const List<({String title, String subtitle})> verificationMethods = [
    (
      title: 'Mobile app notifications',
      subtitle: 'Verify with a push notification on your mobile app.',
    ),
    (
      title: 'SMS text messages',
      subtitle: 'Verify one-time codes sent to your mobile number.',
    ),
    (
      title: 'Authenticator app codes',
      subtitle:
          'Verify one-time codes generated in your preferred third '
          'party authenticator app.',
    ),
  ];

  /// Third-party sign-in options. [asset] is the provider's own mark, which
  /// keeps its colours; [icon] is the fallback glyph.
  static const List<({IconData icon, String label, String? asset})>
  loginProviders = [
    (
      icon: Icons.g_mobiledata_rounded,
      label: 'Google',
      asset: 'assets/icons/google.jpg',
    ),
    (icon: Icons.apple_rounded, label: 'Connect', asset: null),
  ];

  static const List<String> timeZones = [
    'UTC+05:00 Islamabad, Karachi',
    'UTC+00:00 London',
    'UTC-05:00 New York',
  ];
  static const List<String> countries = [
    'Pakistan',
    'United Arab Emirates',
    'United Kingdom',
  ];
  static const List<String> states = ['Punjab', 'Sindh', 'Khyber Pakhtunkhwa'];
  static const List<String> cities = ['Lahore', 'Karachi', 'Islamabad'];

  /// The six keys `/api/account/notifications` stores, laid out as the cards
  /// show them. Every option is the backend's own token paired with the label it
  /// displays, so a value the account already holds always has a matching
  /// choice and nothing the route would reject can be sent.
  static const List<
    ({
      String title,
      List<({String key, String label, Map<String, String> options})> fields,
    })
  >
  notificationGroups = [
    (
      title: 'Desktop',
      fields: [
        (
          key: 'desktopShow',
          label: 'Show notifications for:',
          options: activityLevels,
        ),
        (
          key: 'desktopCounter',
          label: 'Increment message counter for:',
          options: counterLevels,
        ),
      ],
    ),
    (
      title: 'Mobile',
      fields: [
        (
          key: 'mobileShow',
          label: 'Show notifications for:',
          options: activityLevels,
        ),
        (
          key: 'mobileCounter',
          label: 'Increment message counter for:',
          options: counterLevels,
        ),
      ],
    ),
    (
      title: 'Email',
      fields: [
        (
          key: 'emailShow',
          label: 'Send an email with unread activity for:',
          options: activityLevels,
        ),
        (key: 'emailFrequency', label: 'Frequency', options: emailFrequencies),
      ],
    ),
  ];

  /// The two notes the Withdrawals tab shows when the account has nothing of
  /// that kind yet. The money figures are not here: the balance, the pending
  /// total and the payout rows all come from the routes behind that tab.
  static const withdrawals = (
    scheduleNote:
        "You haven't set up a schedule yet. You'll be able to set "
        'it up once you have added a withdrawal method.',
    methodsNote: "You haven't set up any withdrawal methods yet.",
  );

  static const billingNote =
      'You haven\'t set up any billing methods yet. '
      'Your billing method will be charged only when you make a purchase.';

  static const List<String> billingMethods = [
    'Debit or credit card',
    'JazzCash',
    'EasyPaisa',
  ];

  /// Card brand marks shown on the billing form. Logos are Wikimedia
  /// rasterisations of the SVGs on Commons (en.wikipedia.org, CC-BY-SA /
  /// public domain uploads) and are used as identification only.
  static const List<({String label, String asset})> cardBrands = [
    (label: 'Visa', asset: 'assets/icons/visa.png'),
    (label: 'Mastercard', asset: 'assets/icons/mastercard.png'),
    (label: 'PayPal', asset: 'assets/icons/paypal.png'),
    (label: 'Discover', asset: 'assets/icons/discover.png'),
    (label: 'Diners Club', asset: 'assets/icons/diners-club.png'),
  ];
}
