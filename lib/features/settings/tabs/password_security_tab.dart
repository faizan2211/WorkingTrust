import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../widgets/settings_primitives.dart';

/// Password change, two-step verification and linked logins.
///
/// The switches are the three columns `GET /api/account/security` reports; the
/// mobile-app one is the only one its PATCH moves on a boolean. The SMS and the
/// authenticator go through their own setup routes, where the server sends a code
/// and confirms it, and the switch is read back from the security route after
/// that. The password goes to `POST /api/account/password`. A provider the route
/// reports as linked can be disconnected; connecting one stays a browser sign-in
/// this app cannot perform.
class PasswordSecurityTab extends StatefulWidget {
  const PasswordSecurityTab({super.key});

  @override
  State<PasswordSecurityTab> createState() => _PasswordSecurityTabState();
}

class _PasswordSecurityTabState extends State<PasswordSecurityTab> {
  final AccountController _account = AccountController.instance;

  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final List<bool> _revealed = [false, false, false];

  @override
  void initState() {
    super.initState();
    _account.load();
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
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

  Future<void> _updatePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changed = await _account.changePassword(
      currentPassword: _current.text,
      newPassword: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!changed) {
      _reportFailure('The password could not be changed.');
      return;
    }
    // The route accepted the change, so nothing the user typed is kept here.
    _current.clear();
    _password.clear();
    _confirm.clear();
    _note('Password updated.');
  }

  /// Writes one switch. The mobile-app switch is the only one the route moves on
  /// a boolean: an SMS or an authenticator has to be set up with a code the
  /// server confirms first, so those taps open that setup and the switch follows
  /// the answer afterwards.
  Future<void> _setSwitch(int index, bool value) async {
    final security = _account.security;
    // One write at a time: a tap while a setup or a save is running is ignored
    // rather than queued, and the switch keeps the server's value.
    if (security == null || _account.isSaving) return;
    if (index == 0) {
      final saved = await _account.saveSecurity(
        mobileApp: value,
        sms: security.sms,
        authenticator: security.authenticator,
      );
      if (!saved) _reportFailure('The server did not accept that change.');
      return;
    }
    if (value) {
      if (index == 1) {
        await _setupSms();
      } else {
        await _setupAuthenticator();
      }
      return;
    }
    if (index == 1) {
      await _turnOffSms();
    } else {
      await _turnOffAuthenticator();
    }
  }

  Future<void> _setupAuthenticator() async {
    final setup = await _account.startTotp();
    if (setup == null) {
      _reportFailure('The authenticator could not be started.');
      return;
    }
    if (!mounted) return;
    await _openCodeSheet(
      title: 'Authenticator app',
      intro:
          'Add this key in your authenticator app, then enter the code it shows '
          'to finish. Nothing is turned on until the server accepts it.',
      secret: setup.secret,
      link: setup.otpauthUrl,
      onVerify: _account.confirmTotp,
      onClose: _account.discardTotp,
    );
    _account.discardTotp();
  }

  Future<void> _setupSms() async {
    final setup = await _account.startSms();
    if (setup == null) {
      _reportFailure('A verification code could not be sent.');
      return;
    }
    if (!mounted) return;
    await _openCodeSheet(
      title: setup.channel == 'email'
          ? 'Code sent by email'
          : 'Code sent by text message',
      // The route's own sentence, which is also where it says the SMS provider
      // was unavailable and the code went to the email instead.
      intro: setup.message,
      onVerify: _account.confirmSms,
      onClose: _account.discardSms,
    );
    _account.discardSms();
  }

  Future<void> _openCodeSheet({
    required String title,
    required String intro,
    required Future<bool> Function(String code) onVerify,
    required VoidCallback onClose,
    String? secret,
    String? link,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusLg),
      ),
    ),
    builder: (sheetContext) => _VerificationSheet(
      title: title,
      intro: intro,
      secret: secret,
      link: link,
      onVerify: onVerify,
      onClose: () {
        onClose();
        Navigator.pop(sheetContext);
      },
    ),
  );

  Future<void> _turnOffAuthenticator() async {
    if (!await _confirmTurnOff(
      'the authenticator app',
      'The saved key is removed as well, so signing in will stop asking for '
          'codes generated in it.',
    )) {
      return;
    }
    final removed = await _account.removeTotp();
    if (!removed) _reportFailure('The authenticator could not be removed.');
  }

  Future<void> _turnOffSms() async {
    if (!await _confirmTurnOff(
      'SMS verification',
      'Signing in will stop asking for codes sent to your mobile number.',
    )) {
      return;
    }
    final removed = await _account.removeSms();
    if (!removed) _reportFailure('SMS verification could not be turned off.');
  }

  Future<bool> _confirmTurnOff(
    String what,
    String detail, {
    String? title,
    String? action,
  }) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title ?? 'Turn off $what?', style: AppTextStyles.heading4),
        content: Text(detail, style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action ?? 'Turn off'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Disconnects a provider the security route reported as linked. Nothing here
  /// can link one: that is a browser sign-in.
  Future<void> _unlinkProvider(int index) async {
    final provider = index == 0 ? 'google' : 'apple';
    final name = index == 0 ? 'Google' : 'Apple';
    if (!await _confirmTurnOff(
      name,
      'This account will no longer sign in through $name. Keep a password or '
      'another way in before you do.',
      title: 'Disconnect $name?',
      action: 'Disconnect',
    )) {
      return;
    }
    final unlinked = await _account.unlinkProvider(provider);
    if (!unlinked) _reportFailure('$name could not be disconnected.');
  }

  Future<void> _saveSecurity() async {
    final security = _account.security;
    if (security == null) return;
    final saved = await _account.saveSecurity(
      mobileApp: security.mobileApp,
      sms: security.sms,
      authenticator: security.authenticator,
    );
    if (saved) {
      _note('Security settings saved.');
    } else {
      _reportFailure('The server did not accept these settings.');
    }
  }

  bool _switchAt(int index) {
    final security = _account.security;
    if (security == null) return false;
    return switch (index) {
      0 => security.mobileApp,
      1 => security.sms,
      _ => security.authenticator,
    };
  }

  bool _linkedAt(int index) =>
      index == 0 ? _account.googleLinked : _account.appleLinked;

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required' : null;

  String? _confirmCheck(String? value) {
    if ((value ?? '').isEmpty) return 'Confirm your new password';
    if (value != _password.text) return 'The two passwords do not match';
    return null;
  }

  Widget _passwordField({
    required int index,
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    final shown = _revealed[index];
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      obscureText: !shown,
      textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
      validator: validator,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _revealed[index] = !shown),
        tooltip: shown ? 'Hide password' : 'Show password',
        icon: Icon(
          shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: AppDimensions.iconSm + 2,
          color: AppColors.textSecondary,
        ),
      ),
    );
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
                title: 'Password & Security',
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
            SectionCard(
              title: 'Password',
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _passwordField(
                        index: 0,
                        label: 'Current Password',
                        hint: 'Enter your current password',
                        controller: _current,
                        validator: _required,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _passwordField(
                        index: 1,
                        label: 'Create new password',
                        hint: 'Create strong password',
                        controller: _password,
                        validator: (value) {
                          if ((value ?? '').length < 8) {
                            return 'Use at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _passwordField(
                        index: 2,
                        label: 'Confirm password',
                        hint: 'Confirm password',
                        controller: _confirm,
                        validator: _confirmCheck,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: PillButton(
                    text: _account.isSaving ? 'Updating…' : 'Update Password',
                    onPressed: _account.isSaving ? () {} : _updatePassword,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SectionCard(
              title: 'Two-step verification',
              children: [
                for (
                  int index = 0;
                  index < SettingsData.verificationMethods.length;
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: ToggleRow(
                      title: SettingsData.verificationMethods[index].title,
                      subtitle:
                          SettingsData.verificationMethods[index].subtitle,
                      value: _switchAt(index),
                      onChanged: (value) => _setSwitch(index, value),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SectionCard(
              title: 'Login details',
              children: [
                for (
                  int index = 0;
                  index < SettingsData.loginProviders.length;
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: _ProviderButton(
                      provider: SettingsData.loginProviders[index],
                      linked: _linkedAt(index),
                      onTap: () => _linkedAt(index)
                          ? _unlinkProvider(index)
                          : _note(
                              '${SettingsData.loginProviders[index].label} '
                              'sign-in has to be completed in a browser.',
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SaveChangesButton(
              onPressed: _account.isSaving ? () {} : _saveSecurity,
              text: _account.isSaving ? 'Saving…' : 'Save Changes',
            ),
          ],
        );
      },
    );
  }
}

/// A linked-login row. [linked] is the security route's answer, never a tap.
class _ProviderButton extends StatelessWidget {
  final ({IconData icon, String label, String? asset}) provider;
  final bool linked;
  final VoidCallback onTap;

  const _ProviderButton({
    required this.provider,
    required this.linked,
    required this.onTap,
  });

  /// `loginProviders` labels the Apple row "Connect", which would read as a
  /// done action once the account really is linked.
  String get _name => provider.label == 'Connect' ? 'Apple' : provider.label;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: linked ? '$_name connected' : _name,
      isOutlined: true,
      icon: provider.icon,
      leading: provider.asset == null
          ? null
          : Image.asset(
              provider.asset!,
              height: 20,
              width: 20,
              semanticLabel: _name,
            ),
      backgroundColor: linked ? AppColors.accent : AppColors.border,
      textColor: AppColors.textPrimary,
      borderRadius: AppDimensions.radiusXl,
      onPressed: onTap,
    );
  }
}

/// The code step of an authenticator or SMS setup. The secret has been asked for,
/// or the code has been sent, before this opens: [onVerify] is the route's own
/// confirmation, and nothing here is enabled until it says yes.
class _VerificationSheet extends StatefulWidget {
  const _VerificationSheet({
    required this.title,
    required this.intro,
    required this.onVerify,
    required this.onClose,
    this.secret,
    this.link,
  });

  final String title;
  final String intro;
  final Future<bool> Function(String code) onVerify;
  final VoidCallback onClose;

  /// The authenticator key, shown only while the setup is open and never
  /// written to device storage.
  final String? secret;

  /// The `otpauth://` link the route built around that key, for an app that
  /// wants to be typed into rather than scanned.
  final String? link;

  @override
  State<_VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<_VerificationSheet> {
  final AccountController _account = AccountController.instance;
  final TextEditingController _code = TextEditingController();

  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final confirmed = await widget.onVerify(code);
    if (!mounted) return;
    if (confirmed) {
      Navigator.pop(context);
      return;
    }
    // The route says what went wrong: a code that is not yet due, wrong, or a
    // setup that was never started.
    setState(() {
      _busy = false;
      _error = _account.errorMessage.isEmpty
          ? 'That code was not accepted.'
          : _account.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.md,
        right: AppDimensions.md,
        top: AppDimensions.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: AppTextStyles.heading4),
              ),
              GhostIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            widget.intro,
            style: AppTextStyles.bodySmall.copyWith(height: 1.6),
          ),
          if (widget.secret != null && widget.secret!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                widget.secret!,
                style: AppTextStyles.bodyMedium.copyWith(letterSpacing: 2),
              ),
            ),
            if (widget.link != null && widget.link!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.sm),
              SelectableText(
                widget.link!,
                maxLines: 3,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
          const SizedBox(height: AppDimensions.md),
          AppTextField(
            label: 'Verification code',
            hint: 'Enter the code',
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verify(),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              _error,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          SaveChangesButton(
            text: _busy ? 'Verifying…' : 'Verify',
            onPressed: _busy ? () {} : _verify,
          ),
        ],
      ),
    );
  }
}
