import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/grid_section.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/models/wallet_data.dart';
import '../controller/profile_controller.dart';
import '../models/profile_entries.dart';
import '../widgets/buy_bids_sheet.dart';
import '../widgets/edit_identity_dialog.dart';
import '../widgets/edit_skills_dialog.dart';
import '../widgets/experience_sections.dart';
import '../widgets/profile_details_section.dart';

/// Profile tab content, built from the supplied screenshots. The identity
/// block, the section lists and their empty states all come from the shared
/// [ProfileController]: real values from the signed-in session, and nothing
/// invented for the fields the backend cannot return.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // After this frame: the controller notifies its listeners, and the screens
    // that read it are still being built. Opening the profile is where a device
    // asks who it is signed in as, and the controller skips a known session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProfileController.instance.load();
      // The Bids figure is the wallet's connects, so the card asks the same
      // route for it. A known answer is not read twice.
      WalletController.instance.load();
    });
  }

  Future<void> _removePortfolio(
    BuildContext context,
    ProfileController profile,
    int index,
  ) async {
    final title = profile.portfolio[index].title;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove project?'),
        content: Text('“$title” will be removed from your portfolio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await profile.removePortfolio(index)) return;
    if (!mounted) return;
    final message = profile.errorMessage;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message.isEmpty ? 'The project could not be removed.' : message,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    return Scaffold(
      appBar: const ModuleAppBar(
        title: 'View Profile',
        subtitle: 'Photo, stats, portfolio & work history',
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1000
                    ? 3
                    : width >= 700
                    ? 2
                    : 1;
                final detailColumns = width >= 1100
                    ? 4
                    : width >= 700
                    ? 2
                    : 1;
                final bodyWidth = width > 1240 ? 1240.0 : width;
                return Center(
                  child: RefreshIndicator(
                    onRefresh: () => profile.load(force: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppDimensions.md),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: bodyWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IdentityCard(profile: profile),
                            const SizedBox(height: AppDimensions.md),
                            _StatsRow(),
                            const SizedBox(height: AppDimensions.md),
                            _AboutCard(profile: profile),
                            const SizedBox(height: AppDimensions.md),
                            ProfileDetailsSection(columns: detailColumns),
                            const SizedBox(height: AppDimensions.md),
                            GridSection(
                              title: 'Portfolio',
                              columns: columns,
                              action: _CreateNewButton(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  RouteNames.addPortfolio,
                                ),
                              ),
                              children: [
                                for (
                                  var index = 0;
                                  index < profile.portfolio.length;
                                  index++
                                )
                                  _PortfolioTile(
                                    item: profile.portfolio[index],
                                    onRemove: () => _removePortfolio(
                                      context,
                                      profile,
                                      index,
                                    ),
                                  ),
                                if (profile.portfolio.isEmpty)
                                  const _EmptyTile('No projects added yet.'),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.md),
                            const _WorkHistorySection(),
                            const SizedBox(height: AppDimensions.md),
                            GridSection(
                              title: 'Skills',
                              columns: columns,
                              action: _CreateNewButton(
                                label: 'Add',
                                tooltip: 'Add a skill',
                                onTap: () => showEditSkillsDialog(context),
                              ),
                              children: [
                                for (final skill in profile.skills)
                                  _SkillTile(skill: skill),
                                if (profile.skills.isEmpty)
                                  const _EmptyTile('No skills added yet.'),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.md),
                            ExperienceSections(columns: columns),
                            const SizedBox(height: AppDimensions.lg),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final ProfileController profile;

  const _IdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isEmpty ? 'Your profile' : profile.name;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                name: profile.name,
                imageUrl: profile.avatarUrl,
                imageBytes: profile.avatarBytes,
                radius: 42,
                online: true,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heading3.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Only an account the backend handed back gets the
                        // badge; the session says nothing about verification.
                        if (profile.isSignedIn) ...[
                          const SizedBox(width: AppDimensions.xs),
                          const Icon(
                            Icons.verified_outlined,
                            size: AppDimensions.iconSm,
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    if (profile.location.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        profile.location,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (profile.title.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        profile.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge,
                      ),
                    ],
                    if (profile.hourlyRate.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.xs),
                      Text(
                        profile.hourlyRate,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile details',
                onPressed: () => showEditIdentityDialog(context),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: AppDimensions.iconMd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppDimensions.md),
          _StatusLine(profile: profile),
        ],
      ),
    );
  }
}

/// The line under the identity block: whatever the session request currently
/// says, in the caption style the mock used for its member-since text.
class _StatusLine extends StatelessWidget {
  final ProfileController profile;

  const _StatusLine({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile.isLoading) {
      return const Text('Loading profile…', style: AppTextStyles.caption);
    }
    if (profile.sessionError.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              profile.sessionError,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => profile.load(force: true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: AppTextStyles.labelLarge),
          ),
        ],
      );
    }
    // Nothing else is knowable about this account: the backend has no read
    // endpoint for a joining date or a last-seen timestamp.
    return Text(
      profile.email.isEmpty ? 'Not signed in.' : profile.email,
      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _StatsRow extends StatelessWidget {
  /// Earnings, jobs and hours live on the backend's own dashboards; no
  /// endpoint returns them to a device, so the tiles keep their place empty
  /// instead of repeating the figures the mock shipped with.
  static const String _unknown = '—';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: AppDimensions.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statBlock(label: 'Total Earning', value: _unknown),
                ),
                Expanded(
                  child: _statBlock(label: 'Jobs', value: _unknown),
                ),
                Expanded(
                  child: _statBlock(label: 'Hours', value: _unknown),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        ListenableBuilder(
          listenable: WalletController.instance,
          builder: (context, _) => AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.md,
            ),
            onTap: () => showBuyBidsSheet(context),
            child: Row(
              children: [
                const IconBadge(Icons.gavel),
                const SizedBox(width: AppDimensions.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      WalletController.instance.value.bidsLabel,
                      style: AppTextStyles.heading4.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Bids',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBlock({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.heading4.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _AboutCard extends StatefulWidget {
  final ProfileController profile;

  const _AboutCard({required this.profile});

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bio = widget.profile.bio;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.sm),
          Text(
            bio.isEmpty ? 'No description added yet.' : bio,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: bio.isEmpty ? AppColors.textHint : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (bio.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded ? 'See Less' : 'See More',
                  style: AppTextStyles.labelLarge,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The small pill control next to a section heading.
class _CreateNewButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _CreateNewButton({
    this.label = 'Create New',
    this.tooltip = 'Create a new portfolio project',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppTag(label, icon: Icons.add, highlight: true, onTap: onTap),
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  final PortfolioItem item;
  final VoidCallback onRemove;

  const _PortfolioTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: item.kind == 'file' ? () => _openDocument(context) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cover(),
                  Positioned(
                    top: AppDimensions.xs,
                    right: AppDimensions.xs,
                    child: Material(
                      color: AppColors.surface.withValues(alpha: .92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Remove ${item.title}',
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A project's cover is the URL the media route stored. Rows this device did
  /// not publish have no URL to show, so the placeholder stands in.
  Widget _cover() {
    if (item.kind == 'file') {
      return Container(
        color: AppColors.surfaceVariant,
        width: double.infinity,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: AppDimensions.iconLg,
            ),
            SizedBox(height: AppDimensions.xs),
            Text('PDF / Word document'),
          ],
        ),
      );
    }
    final url = item.image;
    if (url.isEmpty) return _fallback();
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stack) => _fallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(),
    );
  }

  Future<void> _openDocument(BuildContext context) async {
    final failure = await LinkOpener.open(item.image);
    if (failure == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textHint,
          size: AppDimensions.iconLg,
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final String skill;

  const _SkillTile({required this.skill});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.md,
      ),
      child: Row(
        children: [
          IconBadge(Icons.workspace_premium_outlined, size: 30),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              skill,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's own empty state, sized like the tiles it stands in for.
class _EmptyTile extends StatelessWidget {
  final String text;

  const _EmptyTile(this.text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.md,
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
      ),
    );
  }
}

class _WorkHistorySection extends StatefulWidget {
  const _WorkHistorySection();

  @override
  State<_WorkHistorySection> createState() => _WorkHistorySectionState();
}

class _WorkHistorySectionState extends State<_WorkHistorySection> {
  static const List<String> _statuses = ['Complete', 'In Progress'];

  int _status = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileController.instance,
      builder: (context, _) {
        final jobs = ProfileController.instance.workHistory.where(
          (item) => item.inProgress == (_status == 1),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Text('Work History', style: AppTextStyles.heading4),
            ),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                AppTag('Most Recent', icon: Icons.swap_vert, onTap: () {}),
                for (var i = 0; i < _statuses.length; i++)
                  AppTag(
                    _statuses[i],
                    selected: _status == i,
                    highlight: _status == i,
                    onTap: () => setState(() => _status = i),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            for (final job in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: _WorkCard(job: job),
              ),
            if (jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: AppDimensions.md),
                child: _EmptyTile('No completed projects yet.'),
              ),
          ],
        );
      },
    );
  }
}

class _WorkCard extends StatelessWidget {
  final ({
    String title,
    double rating,
    int reviews,
    String period,
    String review,
    String amount,
    String pricing,
    bool inProgress,
  })
  job;

  const _WorkCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${job.rating.toStringAsFixed(1)} (${job.reviews} reviews)',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Flexible(
                        child: Text(
                          job.period,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              final payment = Column(
                crossAxisAlignment: wide
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    job.amount,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    job.pricing,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: AppDimensions.sm),
                    payment,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppDimensions.md),
                  payment,
                ],
              );
            },
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            job.review,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
