import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/asset_constants.dart';
import '../../../core/constants/countries.dart';
import '../../../core/widgets/app_tag.dart';
import '../controller/auth_controller.dart';
import '../models/experience_level.dart';
import '../models/work_category.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  /// `registerSchema.interestSlugs` is capped at 12 by the backend.
  static const int _maxInterests = 12;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authController = AuthController();
  final Set<String> _interests = {};
  bool _obscurePassword = true;
  bool _acceptEmails = false;
  String _selectedCountryCode = '+92';
  ExperienceLevel? _experienceLevel;
  String _interestsError = '';

  static final List<String> _countries = [
    for (final country in kCountries) country.name,
  ];

  // Deduped (set literal): DropdownButton asserts one item matches the value.
  static final List<String> _countryCodes = {
    for (final country in kCountries) country.dial,
  }.toList();

  @override
  void initState() {
    super.initState();
    // The backend only accepts real category slugs, so the list comes from it.
    _authController.loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _phoneController.dispose();
    _authController.dispose();
    super.dispose();
  }

  void _toggleInterest(String slug) {
    setState(() {
      if (_interests.contains(slug)) {
        _interests.remove(slug);
      } else if (_interests.length >= _maxInterests) {
        _interestsError = 'You can pick up to $_maxInterests fields.';
        return;
      } else {
        _interests.add(slug);
      }
      _interestsError = '';
    });
  }

  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_interests.isEmpty) {
      setState(() => _interestsError = 'Pick at least one field to work in.');
      return;
    }
    final success = await _authController.signup(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      interestSlugs: _interests.toList(),
      experienceLevel: _experienceLevel!,
      phone: '$_selectedCountryCode${_phoneController.text.trim()}',
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
      postalCode: _postalController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.login,
        (route) => false,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Open the link in your verification email, then log in.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _onGoogle() async {
    final success = await _authController.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.home,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimensions.lg),
                      Image.asset(
                        AssetConstants.logo,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      const Center(
                        child: Text(
                          'Create Your Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Center(
                        child: Text(
                          "Create your account first — then you'll open payment for the plan you picked.",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      _FieldLabel('Full Name'),
                      const SizedBox(height: AppDimensions.sm),
                      _InputField(
                        controller: _nameController,
                        hint: 'Enter Your Name',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Email Address'),
                      const SizedBox(height: AppDimensions.sm),
                      _InputField(
                        controller: _emailController,
                        hint: 'Enter Email Address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Password (min 8)'),
                      const SizedBox(height: AppDimensions.sm),
                      _InputField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        suffixWidget: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Country'),
                      const SizedBox(height: AppDimensions.sm),
                      _DropdownField(
                        value: _countryController.text.isEmpty
                            ? null
                            : _countryController.text,
                        hint: 'Select Your Country',
                        icon: Icons.public_outlined,
                        items: _countries,
                        onChanged: (val) {
                          setState(() {
                            _countryController.text = val ?? '';
                            final index = kCountries.indexWhere(
                              (c) => c.name == val,
                            );
                            if (index >= 0) {
                              _selectedCountryCode = kCountries[index].dial;
                            }
                          });
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please select your country';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('City'),
                      const SizedBox(height: AppDimensions.sm),
                      _InputField(
                        controller: _cityController,
                        hint: 'Enter Your City',
                        icon: Icons.location_city_outlined,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your city';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Postal Code (Optional)'),
                      const SizedBox(height: AppDimensions.sm),
                      _InputField(
                        controller: _postalController,
                        hint: 'Enter Postal Code',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Phone'),
                      const SizedBox(height: AppDimensions.sm),
                      _PhoneField(
                        phoneController: _phoneController,
                        selectedCode: _selectedCountryCode,
                        countryCodes: _countryCodes,
                        onCodeChanged: (code) {
                          setState(() => _selectedCountryCode = code);
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Experience Level'),
                      const SizedBox(height: AppDimensions.sm),
                      _DropdownField(
                        value: _experienceLevel?.label,
                        hint: 'Select Your Experience Level',
                        icon: Icons.trending_up_outlined,
                        items: [
                          for (final level in ExperienceLevel.values)
                            level.label,
                        ],
                        onChanged: (val) {
                          setState(() {
                            final match = ExperienceLevel.values.where(
                              (level) => level.label == val,
                            );
                            _experienceLevel = match.isEmpty
                                ? null
                                : match.first;
                          });
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please select your experience level';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _FieldLabel('Fields You Want To Work In'),
                      const SizedBox(height: AppDimensions.sm),
                      _InterestsField(
                        categories: _authController.categories,
                        selected: _interests,
                        isLoading: _authController.categoriesLoading,
                        error: _authController.categoriesError.isNotEmpty
                            ? _authController.categoriesError
                            : _interestsError,
                        onToggle: _toggleInterest,
                        onRetry: _authController.loadCategories,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _acceptEmails,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() => _acceptEmails = val ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: AppDimensions.sm),
                          Expanded(
                            child: Text(
                              'Send me helpful emails to find rewarding work and job leads.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      if (_authController.errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimensions.md,
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
                      _PrimaryButton(
                        text: 'Continue',
                        isLoading: _authController.isLoading,
                        onPressed: _onContinue,
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      const _DividerLabel('Continue with'),
                      const SizedBox(height: AppDimensions.md),
                      _GoogleButton(onPressed: _onGoogle),
                      const SizedBox(height: AppDimensions.xl),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodyMedium,
                            children: [
                              const TextSpan(
                                text: 'Already registered? ',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.pushNamed(
                                    context,
                                    RouteNames.login,
                                  ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI pieces
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final Widget? suffixWidget;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const _InputField({
    required this.hint,
    required this.icon,
    this.controller,
    this.suffixWidget,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, size: 20, color: AppColors.textHint),
        ),
        suffixIcon: suffixWidget,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, size: 20, color: AppColors.textHint),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textHint),
    );
  }
}

/// The categories the backend lists at /api/categories, collapsed into a
/// dropdown that opens a checkbox menu so the form stays compact.
class _InterestsField extends StatelessWidget {
  final List<WorkCategory> categories;
  final Set<String> selected;
  final bool isLoading;
  final String error;
  final ValueChanged<String> onToggle;
  final VoidCallback onRetry;

  const _InterestsField({
    required this.categories,
    required this.selected,
    required this.isLoading,
    required this.error,
    required this.onToggle,
    required this.onRetry,
  });

  static const String _hint = 'Select Fields To Work In';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text(
                'Load work fields',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          )
        else
          Tooltip(
            message: 'Choose fields',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openMenu(context),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: error.isNotEmpty
                          ? AppColors.error
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: selected.isEmpty
                            ? const Text(
                                _hint,
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 14,
                                ),
                              )
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final category in categories)
                                    if (selected.contains(category.slug))
                                      AppTag(category.name, selected: true),
                                ],
                              ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.sm),
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
      ],
    );
  }

  /// The sheet reads the same [selected] set the parent mutates through
  /// [onToggle], so [StatefulBuilder] repainting it reflects each change.
  Future<void> _openMenu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose your fields',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final category in categories)
                        CheckboxListTile(
                          value: selected.contains(category.slug),
                          activeColor: AppColors.primary,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            category.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: category.description == null
                              ? null
                              : Text(
                                  category.description!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                          onChanged: (_) {
                            onToggle(category.slug);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController phoneController;
  final String selectedCode;
  final List<String> countryCodes;
  final ValueChanged<String> onCodeChanged;
  final String? Function(String?)? validator;

  const _PhoneField({
    required this.phoneController,
    required this.selectedCode,
    required this.countryCodes,
    required this.onCodeChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Icon(
              Icons.phone_android_outlined,
              size: 20,
              color: AppColors.textHint,
            ),
          ),
          DropdownButton<String>(
            value: selectedCode,
            underline: const SizedBox(),
            items: countryCodes
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) onCodeChanged(val);
            },
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 24, color: AppColors.border),
          const SizedBox(width: 4),
          Expanded(
            child: TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: validator,
              decoration: const InputDecoration(
                hintText: '3XX XXXXXXX',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _PrimaryButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String text;
  const _DividerLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/google.jpg', height: 20, width: 20),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Continue with Google',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
