import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../auth/controller/auth_controller.dart';
import '../../find_work/controller/find_work_controller.dart';
import '../../notifications/controller/notification_controller.dart';
import '../../settings/controller/account_controller.dart';
import '../controller/profile_controller.dart';
import '../data/profile_menu_items.dart';
import '../widgets/profile_photo_sheet.dart';

/// Profile tab: the account menu. The detailed profile itself lives behind
/// "View Profile", so this screen is the entry point for every section.
class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the frame because the controller notifies the very
    // listeners this screen is built inside.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ProfileController.instance.load();
    });
  }

  void _logout(BuildContext context) {
    // Signing out must not leave a feed of someone else's activity in memory,
    // nor the session cookie that would let the next poll keep running.
    AuthController().logout();
    NotificationController.instance.endSession();
    ProfileController.instance.clear();
    AccountController.instance.clear();
    FindWorkController.instance.clear();
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteNames.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileController.instance,
      builder: (context, _) {
        final profile = ProfileController.instance;
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () => profile.load(force: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(profile: profile),
                      const SizedBox(height: AppDimensions.lg),
                      Text('Profile Modules', style: AppTextStyles.heading4),
                      const SizedBox(height: AppDimensions.sm),
                      for (final item in ProfileMenuItems.all)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimensions.sm + 2,
                          ),
                          child: _MenuRow(
                            item: item,
                            onTap: () =>
                                Navigator.pushNamed(context, item.route),
                          ),
                        ),
                      const SizedBox(height: AppDimensions.sm),
                      AppButton(
                        text: 'Log out',
                        icon: Icons.logout,
                        backgroundColor: AppColors.error,
                        textColor: Colors.white,
                        borderRadius: AppDimensions.radiusXl,
                        onPressed: () => _logout(context),
                      ),
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

class _HeaderCard extends StatelessWidget {
  final ProfileController profile;

  const _HeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    // The avatar keeps a fixed diameter and the card caps at 560dp, so it
    // cannot overflow even at 320dp screen width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = constraints.maxWidth >= 480 ? 50.0 : 42.0;
        return Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Column(
            children: [
              _AvatarButton(
                profile: profile,
                radius: radius,
                onEdit: () => showProfilePhotoSheet(context),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                profile.name.isEmpty ? 'Your profile' : profile.name,
                textAlign: TextAlign.center,
                style: AppTextStyles.heading4.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: AppDimensions.iconSm,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(width: AppDimensions.xs + 2),
                  Flexible(
                    child: Text(
                      profile.email.isEmpty ? 'Not signed in' : profile.email,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                alignment: WrapAlignment.center,
                children: [
                  // Only what the account actually carries. A pill for a field
                  // no endpoint can return would be an invented fact.
                  for (final label in <String>[
                    profile.title.split('|').first.trim(),
                    profile.location,
                    profile.role,
                  ])
                    if (label.isNotEmpty) _Pill(label),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final ProfileController profile;
  final double radius;
  final VoidCallback onEdit;

  const _AvatarButton({
    required this.profile,
    required this.radius,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.xs),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: Stack(
          children: [
            AppAvatar(
              name: profile.name,
              imageUrl: profile.avatarUrl,
              imageBytes: profile.avatarBytes,
              radius: radius,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(radius * 0.14),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white70, width: 2),
                  ),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: radius * 0.38,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final ProfileMenuItem item;
  final VoidCallback onTap;

  const _MenuRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          IconBadge(item.icon),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          const Icon(
            Icons.chevron_right,
            size: AppDimensions.iconMd,
            color: AppColors.textHint,
          ),
        ],
      ),
    );
  }
}
