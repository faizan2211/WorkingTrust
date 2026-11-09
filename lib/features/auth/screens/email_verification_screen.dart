import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/asset_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../controller/auth_controller.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? email;

  const EmailVerificationScreen({super.key, this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const int _otpLength = 6;
  static const int _resendSeconds = 30;
  static const double _pill = 30;

  final _otpController = TextEditingController();
  final AuthController _authController = AuthController();
  Timer? _resendTimer;
  int _secondsLeft = _resendSeconds;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _authController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsLeft <= 1) {
          _secondsLeft = 0;
          timer.cancel();
        } else {
          _secondsLeft--;
        }
      });
    });
  }

  Future<void> _onVerify() async {
    final email = widget.email?.trim() ?? '';
    if (email.isEmpty) {
      setState(() => _error = 'Start again from the forgot password screen.');
      return;
    }
    if (_otpController.text.length != _otpLength) {
      setState(() => _error = 'Enter the 6-digit code we sent you');
      return;
    }

    // Returns the short-lived token the reset endpoint expects.
    final resetToken = await _authController.verifyOtp(
      email: email,
      otp: _otpController.text,
    );
    if (!mounted) return;

    if (resetToken != null) {
      Navigator.pushNamed(
        context,
        RouteNames.resetPassword,
        arguments: resetToken,
      );
    } else {
      setState(() => _error = _authController.errorMessage);
    }
  }

  /// Asking for the code again is the same request that first emailed it.
  Future<void> _resendCode(String email) async {
    _startResendCountdown();
    if (email.isEmpty) return;
    await _authController.forgotPassword(email: email);
  }

  String get _maskedEmail {
    final email = widget.email ?? '';
    final at = email.indexOf('@');
    if (at < 5) return email.isEmpty ? 'your email' : email;
    return '${email.substring(0, 3)}****${email.substring(at - 2)}';
  }

  String get _countdown {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Email Verification',
                            style: AppTextStyles.heading2,
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text.rich(
                            TextSpan(
                              text: 'Enter 6-Digit OTP sent to ',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: _maskedEmail,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.xl),
                          _buildOtpBoxes(),
                          const SizedBox(height: AppDimensions.sm),
                          SizedBox(
                            height: 18,
                            child: _error.isEmpty
                                ? const SizedBox.shrink()
                                : Text(
                                    _error,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                          _buildResendRow(),
                          const SizedBox(height: AppDimensions.xl),
                          AppButton(
                            text: 'Verify & Continue',
                            borderRadius: _pill,
                            isLoading: _authController.isLoading,
                            onPressed: _onVerify,
                          ),
                        ],
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

  /// One invisible field drives all six boxes, so typing, pasting and
  /// back-spacing stay in sync without six focus nodes.
  Widget _buildOtpBoxes() {
    final code = _otpController.text;

    return SizedBox(
      height: AppDimensions.textFieldHeight,
      child: Stack(
        children: [
          Row(
            children: List.generate(_otpLength, (index) {
              final isFilled = index < code.length;
              final isActive = index == code.length;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radius),
                    border: Border.all(
                      color: isFilled || isActive
                          ? AppColors.primary
                          : AppColors.border,
                      width: isActive ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    isFilled ? code[index] : '',
                    style: AppTextStyles.heading4,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                onChanged: (_) => setState(() => _error = ''),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.xs,
      children: [
        Text("Don't Receive Code?", style: AppTextStyles.bodySmall),
        if (_secondsLeft > 0)
          Text(
            'Resend in $_countdown',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else if (_authController.isLoading)
          Text(
            'Sending…',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          _LinkText(
            label: 'Resend Code',
            onTap: () => _resendCode(widget.email?.trim() ?? ''),
          ),
        _LinkText(label: 'Change Email', onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LinkText({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
