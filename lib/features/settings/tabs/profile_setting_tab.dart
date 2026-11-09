import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_tag.dart';
import '../../auth/controller/auth_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../models/account_settings.dart';
import '../widgets/settings_primitives.dart';

/// Visibility, experience level and categories.
///
/// One `PATCH /api/profile` writes all of it, and the request carries the
/// identity fields as they stand — the route replaces the profile, so a body
/// that leaves the name or the skills out clears them.
///
/// Visibility, work preferences and categories are cached on this device
/// because the profile read does not report them. Linked URLs are managed in
/// Profile → About, where `GET /api/profile` restores them from the server.
class ProfileSettingTab extends StatefulWidget {
  const ProfileSettingTab({super.key});

  @override
  State<ProfileSettingTab> createState() => _ProfileSettingTabState();
}

class _ProfileSettingTabState extends State<ProfileSettingTab> {
  final ProfileController _profile = ProfileController.instance;
  final AccountController _account = AccountController.instance;

  /// The backend's own work fields, which are what a category row can be. Built
  /// here rather than shared, the way the sign-up screen builds its own.
  final AuthController _auth = AuthController();

  /// What the user has changed and the route has not answered for yet. Null
  /// while every row still shows the saved values.
  ProfileSettings? _draft;

  @override
  void initState() {
    super.initState();
    // Each of these asks for nothing it already holds, so opening this tab from
    // the Settings screen costs no extra request when the session is on screen.
    _profile.load();
    _account.load();
    _auth.loadCategories();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  ProfileSettings get _settings => _draft ?? _profile.settings;

  void _note(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// One changed row, kept next to the saved values until `PATCH` answers.
  void _edit({
    String? visibility,
    String? workGoal,
    String? earningPrivacy,
    String? experienceLevel,
    List<String>? interestSlugs,
  }) {
    final current = _settings;
    setState(() {
      _draft = (
        visibility: visibility ?? current.visibility,
        workGoal: workGoal ?? current.workGoal,
        earningPrivacy: earningPrivacy ?? current.earningPrivacy,
        experienceLevel: experienceLevel ?? current.experienceLevel,
        interestSlugs: interestSlugs ?? current.interestSlugs,
        githubUrl: current.githubUrl,
        websiteUrl: current.websiteUrl,
        youtubeUrl: current.youtubeUrl,
      );
    });
  }

  Future<void> _save() async {
    final saved = await _profile.saveSettings(_settings);
    if (!saved) {
      _note(
        _profile.errorMessage.isEmpty
            ? 'The server did not accept these settings.'
            : _profile.errorMessage,
      );
      return;
    }
    // The write-through left the saved values in the controller, so the pending
    // edits have nothing left to override.
    setState(() => _draft = null);
    _note('Profile settings saved.');
  }

  Future<void> _pickCategories() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) =>
          _CategorySheet(auth: _auth, initial: _settings.interestSlugs),
    );
    if (picked == null) return;
    _edit(interestSlugs: picked);
    if (picked.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pick at least one category before saving.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// A dropdown of the tokens one column holds, labelled with the words the
  /// design uses for them.
  Widget _dropdown({
    required String label,
    required Map<String, String> levels,
    required String value,
    required ValueChanged<String> onSelect,
  }) {
    final items = levels.values.toList();
    final tokens = levels.keys.toList();
    final index = items.indexOf(levels[value] ?? items.first);
    return FieldBlock(
      label: label,
      child: AppDropdown(
        value: items[index < 0 ? 0 : index],
        items: items,
        icon: null,
        onChanged: (choice) => onSelect(tokens[items.indexOf(choice)]),
      ),
    );
  }

  int _experienceIndex(String token) {
    final levels = SettingsData.experienceLevels;
    for (int index = 0; index < levels.length; index++) {
      if (levels[index].value == token) return index;
    }
    return levels.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_profile, _account, _auth]),
      builder: (context, child) {
        if (_profile.isLoading && !_profile.isSignedIn) {
          return const AppLoader();
        }
        if (!_profile.isSignedIn) {
          return _OfflineCard(
            message: _profile.errorMessage.isEmpty
                ? 'These settings need a signed-in account.'
                : _profile.errorMessage,
            onRetry: () => _profile.load(force: true),
          );
        }
        final settings = _settings;
        final names = settings.interestSlugs.map(_categoryName).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'My Profile',
              children: [
                const _SavedElsewhereNote(),
                _dropdown(
                  label: 'Visibility',
                  levels: profileVisibilityLevels,
                  value: settings.visibility,
                  onSelect: (token) => _edit(visibility: token),
                ),
                const SizedBox(height: AppDimensions.md),
                _dropdown(
                  label: 'Project preference',
                  levels: {for (final goal in workGoalOptions) goal: goal},
                  value: settings.workGoal,
                  onSelect: (token) => _edit(workGoal: token),
                ),
                const SizedBox(height: AppDimensions.md),
                _dropdown(
                  label: 'Earning Privacy',
                  levels: earningPrivacyLevels,
                  value: settings.earningPrivacy,
                  onSelect: (token) => _edit(earningPrivacy: token),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SectionCard(
              title: 'Experience Level',
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final selected = _experienceIndex(settings.experienceLevel);
                    final cells = <Widget>[
                      for (
                        int index = 0;
                        index < SettingsData.experienceLevels.length;
                        index++
                      )
                        ChoiceCard(
                          title: SettingsData.experienceLevels[index].title,
                          description:
                              SettingsData.experienceLevels[index].description,
                          selected: selected == index,
                          onTap: () => _edit(
                            experienceLevel:
                                SettingsData.experienceLevels[index].value,
                          ),
                        ),
                    ];
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final cell in cells)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.sm,
                              ),
                              child: cell,
                            ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        for (final cell in cells)
                          SizedBox(
                            width:
                                (constraints.maxWidth - AppDimensions.sm) / 2,
                            child: cell,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SectionCard(
              title: 'Categories',
              trailing: GhostIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Choose categories',
                onPressed: _pickCategories,
              ),
              children: [
                if (names.isEmpty)
                  Text(
                    _auth.categoriesLoading
                        ? 'Loading the work fields…'
                        : 'No category is chosen yet. Pick at least one.',
                    style: AppTextStyles.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: [for (final name in names) AppTag(name)],
                  ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'These are the categories the backend offers; saving replaces '
                  'the ones this device has never seen.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            SaveChangesButton(
              onPressed: _profile.isSaving ? () {} : _save,
              text: _profile.isSaving ? 'Saving…' : 'Save Changes',
            ),
          ],
        );
      },
    );
  }

  /// The backend's name for a saved slug, or the slug itself for a field this
  /// device has not been given a list of.
  String _categoryName(String slug) {
    for (final category in _auth.categories) {
      if (category.slug == slug) return category.name;
    }
    return slug;
  }
}

/// The one line that says why this card can show a choice without having read
/// it back.
class _SavedElsewhereNote extends StatelessWidget {
  const _SavedElsewhereNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Text(
        'These settings are saved on this device. Linked profile URLs are '
        'managed from Profile → About.',
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// The card the tab falls back to with no session to write through.
class _OfflineCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OfflineCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'My Profile',
      children: [
        Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Align(
          alignment: Alignment.centerRight,
          child: PillButton(text: 'Retry', onPressed: onRetry),
        ),
      ],
    );
  }
}

/// The real category list from `GET /api/categories`, ticked up to the cap the
/// web's own picker applies.
class _CategorySheet extends StatefulWidget {
  final AuthController auth;
  final List<String> initial;

  const _CategorySheet({required this.auth, required this.initial});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  AuthController get _auth => widget.auth;

  late final Set<String> _picked = {...widget.initial};
  String _error = '';

  void _toggle(String slug) {
    setState(() {
      if (_picked.contains(slug)) {
        _picked.remove(slug);
      } else if (_picked.length >= categorySelectionLimit) {
        _error = 'You can pick up to $categorySelectionLimit categories.';
        return;
      } else {
        _picked.add(slug);
      }
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, child) {
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.md,
            AppDimensions.md + safeBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your categories',
                style: AppTextStyles.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Up to $categorySelectionLimit of the fields the backend lists.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Flexible(
                child: _auth.categoriesLoading
                    ? const Padding(
                        padding: EdgeInsets.all(AppDimensions.lg),
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
                      )
                    : _auth.categories.isEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _auth.loadCategories,
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.primary,
                          ),
                          label: const Text(
                            'Load work fields',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: AppDimensions.sm,
                          runSpacing: AppDimensions.sm,
                          children: [
                            for (final category in _auth.categories)
                              AppTag(
                                category.name,
                                selected: _picked.contains(category.slug),
                                onTap: () => _toggle(category.slug),
                              ),
                          ],
                        ),
                      ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(
                  _error,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              if (_auth.categoriesError.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(
                  _auth.categoriesError,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppDimensions.md),
              PillButton(
                text: 'Done',
                onPressed: () => Navigator.pop(context, _picked.toList()),
              ),
            ],
          ),
        );
      },
    );
  }
}
