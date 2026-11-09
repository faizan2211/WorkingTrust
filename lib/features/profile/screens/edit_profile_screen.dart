import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../controller/profile_controller.dart';

/// Edits the shared in-memory profile. Nothing is written until "Save Changes"
/// passes validation, so Back or Cancel discards unsaved typing.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _rate;
  late final TextEditingController _bio;

  @override
  void initState() {
    super.initState();
    final profile = ProfileController.instance;
    _name = TextEditingController(text: profile.name);
    _title = TextEditingController(text: profile.title);
    _location = TextEditingController(text: profile.location);
    _rate = TextEditingController(text: profile.hourlyRate);
    _bio = TextEditingController(text: profile.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _location.dispose();
    _rate.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final profile = ProfileController.instance;
    // Resolved before popping: after the route is gone this context is dead.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final saved = await profile.saveIdentity(
      name: _name.text.trim(),
      title: _title.text.trim(),
      hourlyRate: _rate.text.trim(),
      bio: _bio.text.trim(),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            profile.errorMessage.isEmpty
                ? 'The changes could not be saved.'
                : profile.errorMessage,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Location has no endpoint a device can read back, so it stays a value for
    // this session only.
    profile.update(location: _location.text.trim());
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Profile updated.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModuleAppBar(title: 'Edit Profile'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'Full Name',
                          controller: _name,
                          hint: 'Your name',
                          textInputAction: TextInputAction.next,
                          validator: _required,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        AppTextField(
                          label: 'Professional Title',
                          controller: _title,
                          hint: 'e.g. UI/UX Designer',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Location',
                                  controller: _location,
                                  hint: 'City, Country',
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.md),
                              Expanded(
                                child: AppTextField(
                                  label: 'Hourly Rate',
                                  controller: _rate,
                                  hint: '\$10/hr',
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          AppTextField(
                            label: 'Location',
                            controller: _location,
                            hint: 'City, Country',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          AppTextField(
                            label: 'Hourly Rate',
                            controller: _rate,
                            hint: '\$10/hr',
                            textInputAction: TextInputAction.next,
                          ),
                        ],
                        const SizedBox(height: AppDimensions.md),
                        AppTextField(
                          label: 'About',
                          controller: _bio,
                          hint: 'Describe your work',
                          maxLines: 5,
                          validator: _required,
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        AppButton(
                          text: _saving ? 'Saving…' : 'Save Changes',
                          onPressed: _saving ? null : _onSave,
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        AppButton(
                          text: 'Cancel',
                          isOutlined: true,
                          backgroundColor: AppColors.textSecondary,
                          textColor: AppColors.textPrimary,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required' : null;
}
