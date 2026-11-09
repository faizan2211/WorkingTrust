import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../profile/controller/profile_controller.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../widgets/settings_primitives.dart';

/// Account contact details and the location the profile reports.
///
/// `PATCH /api/account/contact` is the only route either section has: the
/// account part takes name and email, the location part the four dropdowns, and
/// neither can be read back. The user id is not writable, the phone is the one
/// the security route reports, and the address has no column behind it, so those
/// three are shown as they are rather than edited.
class ContactInfoTab extends StatefulWidget {
  const ContactInfoTab({super.key});

  @override
  State<ContactInfoTab> createState() => _ContactInfoTabState();
}

class _ContactInfoTabState extends State<ContactInfoTab> {
  final AccountController _account = AccountController.instance;

  final _userId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  /// The last pick per dropdown, or null while the row still shows the saved one.
  final Map<String, String> _picks = {};

  /// The account the read-only fields were filled for, so a sign-in switch
  /// repopulates them instead of leaving the previous user's details on screen.
  String _seededFor = '';

  void _seed() {
    final profile = ProfileController.instance;
    if (_seededFor == profile.userId) return;
    _seededFor = profile.userId;
    _userId.text = profile.userId;
    _name.text = profile.name;
    _email.text = _account.email;
    _phone.text = _account.phone;
  }

  @override
  void initState() {
    super.initState();
    _account.load();
  }

  @override
  void dispose() {
    _userId.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _note(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _reportFailure(String fallback) =>
      _note(_account.errorMessage.isEmpty ? fallback : _account.errorMessage);

  Future<void> _saveAccount() async {
    final result = await _account.saveAccount(
      name: _name.text.trim(),
      email: _email.text.trim(),
    );
    if (result == null) {
      _reportFailure('The server did not accept these details.');
      return;
    }
    // The route answers with the row it wrote, and the fields show that.
    _name.text = result.name;
    _email.text = result.email;
    _note(result.message.isEmpty ? 'Account details saved.' : result.message);
  }

  Future<void> _saveLocation() async {
    final message = await _account.saveLocation((
      timezone: _value('timezone', SettingsData.timeZones),
      country: _value('country', SettingsData.countries),
      stateProvince: _value('stateProvince', SettingsData.states),
      city: _value('city', SettingsData.cities),
    ));
    if (message == null) {
      _reportFailure('The server did not accept the location.');
      return;
    }
    _picks.clear();
    _note(message);
  }

  /// The pick for this dropdown, or the value this account last saved.
  String _value(String key, List<String> options) {
    final picked = _picks[key];
    if (picked != null) return picked;
    final stored = switch (key) {
      'timezone' => _account.location.timezone,
      'country' => _account.location.country,
      'stateProvince' => _account.location.stateProvince,
      _ => _account.location.city,
    };
    return options.contains(stored) ? stored : options.first;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _account,
      builder: (context, child) {
        if (_account.isLoading && !_account.hasLoaded) {
          return const AppLoader();
        }
        if (!_account.hasLoaded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Contact info',
                children: [
                  Text(
                    _account.errorMessage.isEmpty
                        ? 'These details are unread without a session.'
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
        _seed();
        final locations = <({String key, String label, List<String> items})>[
          (key: 'timezone', label: 'Time Zone', items: SettingsData.timeZones),
          (key: 'country', label: 'Country', items: SettingsData.countries),
          (
            key: 'stateProvince',
            label: 'State/Province',
            items: SettingsData.states,
          ),
          (key: 'city', label: 'City', items: SettingsData.cities),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Account',
              children: [
                FieldBlock(
                  label: 'User ID',
                  child: AppTextField(
                    controller: _userId,
                    hint: 'Your user id',
                    enabled: false,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                FieldBlock(
                  label: 'Name',
                  child: AppTextField(controller: _name, hint: 'Your name'),
                ),
                const SizedBox(height: AppDimensions.md),
                FieldBlock(
                  label: 'Email',
                  child: AppTextField(
                    controller: _email,
                    hint: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                FieldBlock(
                  label: 'Phone',
                  child: AppTextField(
                    controller: _phone,
                    hint: 'Phone number',
                    keyboardType: TextInputType.phone,
                    enabled: false,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(
                        left: AppDimensions.md,
                        right: AppDimensions.sm,
                      ),
                      child: Icon(
                        Icons.sim_card_outlined,
                        size: AppDimensions.iconSm,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: PillButton(
                    text: _account.isSaving ? 'Saving…' : 'Save',
                    onPressed: _account.isSaving ? () {} : _saveAccount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SectionCard(
              title: 'Location',
              children: [
                for (int index = 0; index < locations.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppDimensions.md),
                  FieldBlock(
                    label: locations[index].label,
                    child: AppDropdown(
                      value: _value(
                        locations[index].key,
                        locations[index].items,
                      ),
                      items: locations[index].items,
                      icon: null,
                      onChanged: (choice) =>
                          setState(() => _picks[locations[index].key] = choice),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.md),
                FieldBlock(
                  label: 'Address',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _address,
                        hint: 'Street address',
                        enabled: false,
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        'No account field stores a street address, so this '
                        'cannot be saved.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SaveChangesButton(
              onPressed: _account.isSaving ? () {} : _saveLocation,
              text: _account.isSaving ? 'Saving…' : 'Save Changes',
            ),
          ],
        );
      },
    );
  }
}
