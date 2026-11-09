import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/asset_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/auth_controller.dart';

class ResetPasswordScreen extends StatefulWidget {
  /// The token `POST /api/auth/verify-otp` returned.
  final String resetToken;

  const ResetPasswordScreen({super.key, this.resetToken = ''});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const double _pill = 30;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final AuthController _authController = AuthController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.resetToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your verification expired. Please start again.'),
        ),
      );
      return;
    }

    final success = await _authController.resetPassword(
      token: widget.resetToken,
      password: _passwordController.text,
    );
    if (!mounted) return;

    if (!success) return;
    // The "code sent" banner from step one may still be on screen; the success
    // message has to replace it rather than queue behind it.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.login,
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Password reset successfully. Please log in.'),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return AppTextField(
      label: label,
      hint: '********',
      controller: controller,
      obscureText: _obscure,
      borderRadius: _pill,
      textInputAction: TextInputAction.done,
      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.textHint,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    child: Image.asset(
                      AssetConstants.logo,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.lg,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Reset Password',
                              style: AppTextStyles.heading2,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimensions.xs),
                            Text(
                              'Choose a new password for your account.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimensions.xl),
                            _passwordField(
                              label: 'Create New Password',
                              controller: _passwordController,
                              validator: Validators.password,
                            ),
                            const SizedBox(height: AppDimensions.md),
                            _passwordField(
                              label: 'Confirm Password',
                              controller: _confirmController,
                              validator: (value) => Validators.confirmPassword(
                                value,
                                _passwordController.text,
                              ),
                            ),
                            if (_authController.errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppDimensions.md,
                                ),
                                child: Text(
                                  _authController.errorMessage,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: AppDimensions.lg),
                            AppButton(
                              text: 'Reset Password',
                              borderRadius: _pill,
                              isLoading: _authController.isLoading,
                              onPressed: _onSubmit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
