import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_loader.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../models/account_settings.dart';
import '../widgets/settings_primitives.dart';

/// Desktop, mobile and email notification preferences.
///
/// The six values come from `GET /api/account/notifications` and go back through
/// its PATCH, so a change made on the web is here the next time the tab opens.
class NotificationTab extends StatefulWidget {
  const NotificationTab({super.key});

  @override
  State<NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<NotificationTab> {
  final AccountController _account = AccountController.instance;

  /// Only the rows changed in this visit. Everything else keeps showing what the
  /// route answered, so a failed save cannot leave the screen claiming a value
  /// the account does not hold.
  final Map<String, String> _choices = {};

  @override
  void initState() {
    super.initState();
    _account.load();
  }

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    if (_account.isSaving) return;
    final saved = await _account.savePreferences((
      desktopShow: _token('desktopShow'),
      desktopCounter: _token('desktopCounter'),
      mobileShow: _token('mobileShow'),
      mobileCounter: _token('mobileCounter'),
      emailShow: _token('emailShow'),
      emailFrequency: _token('emailFrequency'),
    ));
    if (!saved) {
      _note(
        _account.errorMessage.isEmpty
            ? 'The server did not accept these preferences.'
            : _account.errorMessage,
      );
      return;
    }
    _choices.clear();
    _note('Notification settings saved.');
  }

  String _token(String key) =>
      _choices[key] ?? _stored(_account.preferences, key);

  static String _stored(NotificationPreferences prefs, String key) =>
      switch (key) {
        'desktopShow' => prefs.desktopShow,
        'desktopCounter' => prefs.desktopCounter,
        'mobileShow' => prefs.mobileShow,
        'mobileCounter' => prefs.mobileCounter,
        'emailShow' => prefs.emailShow,
        'emailFrequency' => prefs.emailFrequency,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _account,
      builder: (context, child) {
        if (_account.isLoading && !_account.hasLoaded) return const AppLoader();
        if (!_account.hasLoaded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Notification settings',
                children: [
                  Text(
                    _account.errorMessage.isEmpty
                        ? 'These settings are unread without a session.'
                        : _account.errorMessage,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PillButton(
                      text: 'Retry',
                      onPressed: () => _account.load(force: true),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (
              int group = 0;
              group < SettingsData.notificationGroups.length;
              group++
            ) ...[
              if (group > 0) const SizedBox(height: AppDimensions.md),
              SectionCard(
                title: SettingsData.notificationGroups[group].title,
                children: [
                  for (
                    int field = 0;
                    field <
                        SettingsData.notificationGroups[group].fields.length;
                    field++
                  ) ...[
                    if (field > 0) const SizedBox(height: AppDimensions.md),
                    _PreferenceField(
                      row: SettingsData.notificationGroups[group].fields[field],
                      token: _token(
                        SettingsData
                            .notificationGroups[group]
                            .fields[field]
                            .key,
                      ),
                      onSelect: (key, token) =>
                          setState(() => _choices[key] = token),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            SaveChangesButton(
              onPressed: _account.isSaving ? () {} : _save,
              text: _account.isSaving ? 'Saving…' : 'Save Changes',
            ),
          ],
        );
      },
    );
  }
}

/// One preference dropdown. It shows the label the backend's token stands for
/// and hands the token — never the label — back to the tab.
class _PreferenceField extends StatelessWidget {
  final ({String key, String label, Map<String, String> options}) row;
  final String token;
  final void Function(String key, String token) onSelect;

  const _PreferenceField({
    required this.row,
    required this.token,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = row.options;
    final label = options[token] ?? options.values.first;
    return FieldBlock(
      label: row.label,
      child: AppDropdown(
        value: label,
        items: options.values.toList(),
        icon: null,
        onChanged: (choice) {
          final picked = options.entries
              .firstWhere(
                (entry) => entry.value == choice,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          if (picked.isNotEmpty) onSelect(row.key, picked);
        },
      ),
    );
  }
}
