import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/icon_badge.dart';
import '../controller/find_work_controller.dart';
import '../models/project_model.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  /// The proposal form owns the submission; this screen only reflects the
  /// result once the form pops back.
  Future<void> _apply() async {
    final messenger = ScaffoldMessenger.of(context);
    final cost = widget.project.proposalCost;
    final submitted = await Navigator.pushNamed(
      context,
      RouteNames.submitProposal,
      arguments: widget.project,
    );
    if (submitted != true || !mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text('Proposal sent. $cost Bids deducted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleSave() {
    // The board owns the bookmark set, so the list's count stays correct.
    FindWorkController.instance.toggleSave(widget.project.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final mainChildren = <Widget>[
      _Overview(project: project),
      const SizedBox(height: AppDimensions.md),
      _Expertise(project: project),
      const SizedBox(height: AppDimensions.md),
      _Activity(project: project),
    ];
    final sideChildren = <Widget>[
      _ApplyCard(project: project, onApply: _apply),
      const SizedBox(height: AppDimensions.md),
      _ClientCard(project: project),
    ];

    Widget scroll(List<Widget> children) => RefreshIndicator(
      onRefresh: () => FindWorkController.instance.load(force: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Project Details'),
        actions: [
          IconButton(
            onPressed: _toggleSave,
            icon: Icon(
              project.saved
                  ? Icons.bookmark_added
                  : Icons.bookmark_add_outlined,
              color: project.saved
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return scroll([...mainChildren, ...sideChildren]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: scroll(mainChildren)),
                SizedBox(width: 360, child: scroll(sideChildren)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final ProjectModel project;
  const _Overview({required this.project});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTag(project.postedIn, highlight: true),
          const SizedBox(height: AppDimensions.md),
          Text(
            project.title,
            style: AppTextStyles.heading2.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Text(
            'Summary',
            style: AppTextStyles.heading4.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppDimensions.sm),
          // The board sends one description; the web splits its `requirements`
          // and `deliverables` columns out, and neither is in this response.
          for (final paragraph in project.description.split('\n'))
            if (paragraph.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: Text(
                  paragraph.trim(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.7,
                  ),
                ),
              ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.lg,
            runSpacing: AppDimensions.md,
            children: [
              _Meta(icon: Icons.attach_money_outlined, label: project.price),
              if (project.level.isNotEmpty)
                _Meta(
                  icon: Icons.workspace_premium_outlined,
                  label: project.level,
                ),
              _Meta(icon: Icons.schedule_outlined, label: project.duration),
              if (project.category.isNotEmpty)
                _Meta(icon: Icons.folder_outlined, label: project.category),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(icon, size: 32),
        const SizedBox(width: AppDimensions.sm),
        Text(label, style: AppTextStyles.labelLarge),
      ],
    );
  }
}

class _Expertise extends StatelessWidget {
  final ProjectModel project;
  const _Expertise({required this.project});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skills and Expertise', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [for (final skill in project.skills) AppTag(skill)],
          ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  final ProjectModel project;
  const _Activity({required this.project});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity on this job', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          _Row(label: 'Proposals', value: '${project.proposals}'),
          _Row(label: 'Posted', value: project.postedDate),
          _Row(
            label: 'Payment',
            value: project.paymentVerified ? 'Verified' : 'Unverified',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          const SizedBox(width: AppDimensions.sm),
          // The value comes from a client's own profile text, so it gets the
          // remaining width and wraps there instead of overflowing the card.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onApply;

  const _ApplyCard({required this.project, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            label: 'Send a proposal for',
            value: '${project.proposalCost} Bids',
          ),
          const SizedBox(height: AppDimensions.sm),
          AppButton(
            text: project.applied ? 'Applied' : 'Apply Now',
            borderRadius: AppDimensions.radiusXl,
            backgroundColor: project.applied
                ? AppColors.surfaceVariant
                : AppColors.accent,
            textColor: project.applied
                ? AppColors.textSecondary
                : AppColors.primary,
            onPressed: project.applied ? null : onApply,
          ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final ProjectModel project;
  const _ClientCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About the client', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              AppAvatar(
                name: project.clientName,
                imageUrl: project.clientAvatar,
                radius: 22,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.clientName, style: AppTextStyles.labelLarge),
                    Text(project.clientLocation, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _Row(label: 'Name', value: project.clientName),
          _Row(label: 'Location', value: project.clientLocation),
          _Row(label: 'Total spent', value: project.spentLabel ?? 'Not stated'),
          _Row(
            label: 'Rating',
            value: project.clientRating > 0
                ? project.clientRating.toStringAsFixed(1)
                : 'Not stated',
          ),
        ],
      ),
    );
  }
}
