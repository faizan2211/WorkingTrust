import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../controller/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authController = AuthController();

  @override
  void dispose() {
    _emailController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    // The backend answers the same way whether or not the address is registered,
    // so this message has to stay neutral.
    final message = await _authController.forgotPassword(email: email);

    if (!mounted) return;
    if (message == null) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message.trim().isEmpty
              ? 'If an account exists for this email, a verification code will be sent.'
              : message,
        ),
      ),
    );
    navigator.pushNamed(RouteNames.emailVerification, arguments: email);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authController,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Forgot Password')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: _buildFormView(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text('Enter Your Email', style: AppTextStyles.heading2),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Enter your email address and we\'ll send you a 6-digit verification code.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.xl),
          AppTextField(
            label: 'Email',
            hint: 'Enter your email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: Validators.email,
          ),
          const SizedBox(height: AppDimensions.lg),
          if (_authController.errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: Text(
                _authController.errorMessage,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          AppButton(
            text: 'Send OTP',
            onPressed: _onSubmit,
            isLoading: _authController.isLoading,
          ),
          const SizedBox(height: AppDimensions.md),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }
}
