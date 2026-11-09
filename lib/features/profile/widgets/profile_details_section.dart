import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_badge.dart';
import '../../../core/widgets/equal_column_grid.dart';
import '../controller/profile_controller.dart';
import '../models/video_intro.dart';
import 'profile_form_dialog.dart';

/// The four detail cards shown under About: Languages, Education, Linked
/// Accounts and the video intro.
///
/// Languages, education, linked URLs and the intro video are all backed by the
/// signed-in profile and restored by `GET /api/profile`.
class ProfileDetailsSection extends StatefulWidget {
  final int columns;

  const ProfileDetailsSection({super.key, required this.columns});

  @override
  State<ProfileDetailsSection> createState() => _ProfileDetailsSectionState();
}

typedef _Account = ({
  String key,
  IconData icon,
  String label,
  String? asset,
  String hint,
});

const List<_Account> _linkedAccounts = [
  (
    key: 'githubUrl',
    icon: Icons.code,
    label: 'GitHub',
    asset: 'assets/icons/github.png',
    hint: 'https://github.com/username',
  ),
  (
    key: 'websiteUrl',
    icon: Icons.language,
    label: 'Website',
    asset: null,
    hint: 'https://your-site.com',
  ),
  (
    key: 'youtubeUrl',
    icon: Icons.smart_display,
    label: 'YouTube',
    asset: null,
    hint: 'https://youtube.com/@channel',
  ),
];

class _ProfileDetailsSectionState extends State<ProfileDetailsSection> {
  final _name = TextEditingController();
  final _level = TextEditingController();
  final _institution = TextEditingController();
  final _degree = TextEditingController();
  final _handle = TextEditingController();
  final _intro = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _level.dispose();
    _institution.dispose();
    _degree.dispose();
    _handle.dispose();
    _intro.dispose();
    super.dispose();
  }

  /// Shows [fields] in the shared themed profile dialog.
  Future<ProfileFormResult> _prompt(
    String title,
    List<Widget> fields, {
    bool removable = false,
  }) => showProfileFormDialog(
    context,
    title: title,
    fields: fields,
    removable: removable,
  );

  // Languages ----------------------------------------------------------------

  Future<void> _languageForm([int index = -1]) async {
    final profile = ProfileController.instance;
    final entry = index < 0 ? null : profile.languages[index];
    _name.text = entry?.name ?? '';
    _level.text = entry?.level ?? '';
    final result = await _prompt(index < 0 ? 'Add language' : 'Edit language', [
      AppTextField(
        hint: 'Language',
        controller: _name,
        validator: requiredField,
      ),
      const SizedBox(height: AppDimensions.sm),
      AppTextField(
        hint: 'Proficiency',
        controller: _level,
        validator: requiredField,
      ),
    ], removable: entry != null);
    if (!mounted) return;
    if (result == ProfileFormResult.remove && entry != null) {
      _report(await profile.removeLanguage(index));
      return;
    }
    if (result != ProfileFormResult.save) return;
    _report(
      await profile.saveLanguage((
        id: entry?.id ?? '',
        name: _name.text.trim(),
        level: _level.text.trim(),
      ), index: index),
    );
  }

  // Education ----------------------------------------------------------------

  Future<void> _educationForm([int index = -1]) async {
    final profile = ProfileController.instance;
    final entry = index < 0 ? null : profile.education[index];
    _institution.text = entry?.institution ?? '';
    _degree.text = entry?.degree ?? '';
    final result = await _prompt(
      index < 0 ? 'Add education' : 'Edit education',
      [
        AppTextField(
          hint: 'Institution',
          controller: _institution,
          validator: requiredField,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          hint: 'Degree',
          controller: _degree,
          validator: requiredField,
        ),
      ],
      removable: entry != null,
    );
    if (!mounted) return;
    if (result == ProfileFormResult.remove && entry != null) {
      _report(await profile.removeEducation(index));
      return;
    }
    if (result != ProfileFormResult.save) return;
    _report(
      await profile.saveEducation((
        id: entry?.id ?? '',
        institution: _institution.text.trim(),
        degree: _degree.text.trim(),
      ), index: index),
    );
  }

  String _accountUrl(ProfileController profile, _Account account) =>
      switch (account.key) {
        'githubUrl' => profile.githubUrl,
        'websiteUrl' => profile.websiteUrl,
        _ => profile.youtubeUrl,
      };

  Future<void> _editAccount(_Account account) async {
    final profile = ProfileController.instance;
    _handle.text = _accountUrl(profile, account);
    final result = await _prompt('Edit ${account.label}', [
      AppTextField(
        hint: account.hint,
        controller: _handle,
        keyboardType: TextInputType.url,
        validator: _optionalWebLink,
      ),
    ]);
    if (!mounted || result != ProfileFormResult.save) return;

    var githubUrl = profile.githubUrl;
    var websiteUrl = profile.websiteUrl;
    var youtubeUrl = profile.youtubeUrl;
    switch (account.key) {
      case 'githubUrl':
        githubUrl = _handle.text.trim();
      case 'websiteUrl':
        websiteUrl = _handle.text.trim();
      default:
        youtubeUrl = _handle.text.trim();
    }
    _report(
      await profile.saveLinkedAccounts(
        githubUrl: githubUrl,
        websiteUrl: websiteUrl,
        youtubeUrl: youtubeUrl,
      ),
    );
  }

  String? _optionalWebLink(String? value) {
    final link = value?.trim() ?? '';
    if (link.isEmpty || Validators.isWebAddress(link)) return null;
    return 'Enter a valid URL beginning with http:// or https://.';
  }

  Future<void> _openAccount(String url) async {
    final failure = await LinkOpener.open(url);
    if (failure != null && mounted) _note(failure);
  }

  Widget _linkedAccountRow(ProfileController profile, _Account account) {
    final url = _accountUrl(profile, account);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Row(
          children: [
            BrandBadge(
              icon: account.icon,
              asset: account.asset,
              label: account.label,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: url.isEmpty ? null : () => _openAccount(url),
                    child: Text(
                      url.isEmpty ? 'Not linked' : url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: url.isEmpty
                            ? AppColors.textHint
                            : AppColors.primary,
                        decoration: url.isEmpty
                            ? TextDecoration.none
                            : TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit ${account.label}',
              onPressed: () => _editAccount(account),
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  // Video intro --------------------------------------------------------------

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// A row the server refused never reaches the profile, so the only sign it
  /// went wrong is what the route said.
  void _report(bool saved) {
    if (saved) return;
    final message = ProfileController.instance.errorMessage;
    if (message.isNotEmpty) _note(message);
  }

  /// The intro route stores a link, not a file — there is no upload for it —
  /// so the form asks for the address of a video already hosted elsewhere.
  Future<void> _introForm() async {
    final profile = ProfileController.instance;
    final editing = profile.videoIntro.isNotEmpty;
    _intro.text = profile.videoIntro;
    final result = await _prompt(
      editing ? 'Edit video intro' : 'Add video intro',
      [
        AppTextField(
          hint: 'Paste a video link',
          controller: _intro,
          keyboardType: TextInputType.url,
          validator: _introLink,
        ),
      ],
      removable: editing,
    );
    if (!mounted) return;
    if (result == ProfileFormResult.remove && editing) {
      _report(await profile.removeVideoIntro());
      return;
    }
    if (result != ProfileFormResult.save) return;
    _report(await profile.saveVideoIntro(_intro.text));
  }

  /// Reuses the server's own rejection wording, but decides before the request
  /// so a malformed link never leaves the device.
  static String? _introLink(String? value) =>
      requiredField(value) ?? Validators.videoLink(value);

  Future<void> _openIntro() async {
    final failure = await LinkOpener.open(
      ProfileController.instance.videoIntro,
    );
    if (failure == null || !mounted) return;
    _note(failure);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    final intro = profile.videoIntro;
    return EqualColumnGrid(
      columns: widget.columns,
      children: [
        _DetailCard(
          title: 'Languages',
          onAdd: () => _languageForm(),
          onEdit: profile.languages.isEmpty ? null : () => _languageForm(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final language in profile.languages)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: language.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ': ${language.level}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (profile.languages.isEmpty)
                const _EmptyHint('No languages yet'),
            ],
          ),
        ),
        _DetailCard(
          title: 'Education',
          onAdd: () => _educationForm(),
          onEdit: profile.education.isEmpty ? null : () => _educationForm(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in profile.education)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.institution,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.degree,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (profile.education.isEmpty)
                const _EmptyHint('No education yet'),
            ],
          ),
        ),
        _DetailCard(
          title: 'Linked Accounts',
          child: Column(
            children: [
              for (final account in _linkedAccounts)
                _linkedAccountRow(profile, account),
            ],
          ),
        ),
        _DetailCard(
          title: 'Video Intro',
          onAdd: intro.isEmpty ? _introForm : null,
          onEdit: intro.isEmpty ? null : _introForm,
          onRemove: intro.isEmpty ? null : _removeIntro,
          child: intro.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _EmptyHint('No video intro'),
                    const SizedBox(height: AppDimensions.sm),
                    AppButton(
                      text: 'Add video intro',
                      icon: Icons.add,
                      isOutlined: true,
                      onPressed: _introForm,
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _openIntro,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _IntroPoster(link: intro),
                          Center(
                            child: Tooltip(
                              message: 'Video intro • $intro',
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: AppDimensions.iconMd,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _removeIntro() async {
    _report(await ProfileController.instance.removeVideoIntro());
  }
}

/// The picture behind the play button. YouTube and Vimeo addresses carry a
/// video id, and both hosts publish a still for it, so the card can show one
/// without asking the backend for anything. Every other link — a bare
/// `…/intro.mp4` in particular — has no id to derive from and keeps the
/// placeholder. Opening the video never depends on this.
class _IntroPoster extends StatelessWidget {
  final String link;

  const _IntroPoster({required this.link});

  @override
  Widget build(BuildContext context) {
    final poster = videoPosterUrl(link);
    if (poster == null) return _IntroPlaceholder(label: link);
    return Image.network(
      poster,
      fit: BoxFit.cover,
      // A still that fails to download says nothing about the link, so it
      // falls back to the address rather than an error box.
      errorBuilder: (_, _, _) => _IntroPlaceholder(label: link),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _IntroPlaceholder(label: link),
    );
  }
}

/// The poster area for the stored intro link. The route holds a URL and the app
/// has no video decoder, so the address stands in for a frame.
class _IntroPlaceholder extends StatelessWidget {
  final String? label;

  const _IntroPlaceholder({this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      child: label == null
          ? const Center(
              child: Icon(
                Icons.movie_outlined,
                color: AppColors.textHint,
                size: AppDimensions.iconLg,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(AppDimensions.xs),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
    );
  }
}

/// A detail card with its heading and the circular add / edit / remove
/// controls from the mock.
class _DetailCard extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final Widget child;

  const _DetailCard({
    required this.title,
    required this.child,
    this.onAdd,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.heading4)),
              if (onAdd != null)
                _RoundButton(
                  icon: Icons.add,
                  tooltip: 'Add to $title',
                  onPressed: onAdd!,
                ),
              if (onEdit != null) ...[
                const SizedBox(width: AppDimensions.xs),
                _RoundButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit $title',
                  onPressed: onEdit!,
                ),
              ],
              if (onRemove != null)
                _RoundButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Remove $title',
                  tone: AppColors.error,
                  onPressed: onRemove!,
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          child,
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color tone;
  final VoidCallback onPressed;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.accent,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Icon(icon, size: AppDimensions.iconSm, color: tone),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
    );
  }
}
