import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/overview_controller.dart';
import '../../finance/models/json_read.dart';
import '../../finance/models/reports_overview.dart';
import '../../finance/widgets/read_view.dart';

/// Balance summary plus the work that currently sits behind each of them, read
/// from `GET /api/reports/overview`.
///
/// The four figures and the job list come from one route, so a tile shows what
/// the server reported or an em dash — never a number this screen cannot
/// confirm. It reads once when it opens and again when it is pulled, not on a
/// timer, so the amounts cannot shift under a page someone is still reading.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => OverviewController.instance.load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModuleAppBar(
        title: 'Overview',
        subtitle: 'Profile summary at a glance',
      ),
      body: ListenableBuilder(
        listenable: OverviewController.instance,
        builder: (context, _) {
          final controller = OverviewController.instance;
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 900 ? 4 : (width >= 480 ? 2 : 1);
                  final bodyWidth = width > 1100 ? 1100.0 : width;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppDimensions.md),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: bodyWidth),
                        child: ReadView(
                          state: controller.state,
                          error: controller.error,
                          onRetry: () => controller.load(force: true),
                          builder: (context) => _OverviewBody(
                            snapshot: controller.value,
                            columns: columns,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  final ReportsOverview snapshot;
  final int columns;

  const _OverviewBody({required this.snapshot, required this.columns});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileGrid(
          columns: columns,
          tiles: [
            (
              label: 'Work in Progress',
              amount: snapshot.workInProgressAmount,
              tone: 0,
            ),
            (label: 'In Review', amount: snapshot.inReviewAmount, tone: 1),
            (
              label: 'Pending',
              amount: snapshot.pendingWithdrawalsAmount,
              tone: 2,
            ),
            (
              label: 'Available Balance',
              amount: snapshot.availableBalance,
              tone: 3,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.lg),
        if (snapshot.jobs.isEmpty)
          const AppEmptyState(message: 'No active jobs on this account.')
        else
          for (final section in _sectionsOf(snapshot.jobs)) ...[
            Text(section.title, style: AppTextStyles.heading4),
            const SizedBox(height: AppDimensions.sm),
            for (final job in section.jobs) ...[
              _WorkRow(job: job),
              const SizedBox(height: AppDimensions.sm),
            ],
            const SizedBox(height: AppDimensions.md),
          ],
      ],
    );
  }
}

const List<String> _sectionOrder = [
  'Work in Progress',
  'In Review',
  'Needs revision',
];

/// The jobs grouped under the heading their own status answers to.
///
/// A section is drawn only when the server put rows in it. Pending withdrawals
/// deliberately has no section: this route carries that figure as a total on
/// the tile alone, with nothing behind it to list.
List<({String title, List<OverviewJob> jobs})> _sectionsOf(
  List<OverviewJob> jobs,
) {
  final grouped = <String, List<OverviewJob>>{};
  for (final job in jobs) {
    final title = _sectionTitleOf(job);
    if (title != null) {
      grouped.putIfAbsent(title, () => []).add(job);
    }
  }
  return [
    for (final title in _sectionOrder)
      if ((grouped[title] ?? const <OverviewJob>[]).isNotEmpty)
        (title: title, jobs: grouped[title]!),
  ];
}

/// The status column and the wording the route sends with it say the same
/// thing, so either one is enough to place a row. A status neither names is
/// left out rather than filed under a heading it does not answer to.
String? _sectionTitleOf(OverviewJob job) {
  final status = '${job.status} ${job.statusLabel}'.toUpperCase();
  if (status.contains('REJECTED')) return 'Needs revision';
  if (status.contains('SUBMITTED')) return 'In Review';
  if (status.contains('ACTIVE')) return 'Work in Progress';
  return null;
}

class _TileGrid extends StatelessWidget {
  final int columns;
  final List<({String label, double? amount, int tone})> tiles;

  const _TileGrid({required this.columns, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var row = 0; row < tiles.length; row += columns) {
      final slice = tiles.skip(row).take(columns).toList();
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < slice.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimensions.sm),
                  Expanded(child: _BalanceTile(tile: slice[i])),
                ],
                for (var pad = slice.length; pad < columns; pad++) ...[
                  const SizedBox(width: AppDimensions.sm),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: children);
  }
}

class _BalanceTile extends StatelessWidget {
  final ({String label, double? amount, int tone}) tile;

  const _BalanceTile({required this.tile});

  Color get _accent => switch (tile.tone) {
    1 => AppColors.warning,
    2 => AppColors.info,
    3 => AppColors.success,
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final amount = tile.amount;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              // A figure the route left out stays a dash: no tile here may
              // imply money the server has not reported.
              amount == null ? '—' : usd(amount),
              style: AppTextStyles.heading3.copyWith(
                color: _accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            tile.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  final OverviewJob job;

  const _WorkRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final status = job.statusLabel.isNotEmpty ? job.statusLabel : job.status;
    final due = job.dueAt;
    final tags = [
      if (status.isNotEmpty) AppTag(status, highlight: true),
      if (due != null) AppTag('Due ${shortDate(due)}'),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  job.shortTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  job.amountLabel,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            // The separator only goes in where the server sent a client to
            // separate.
            job.clientName.isEmpty
                ? job.milestoneLabel
                : '${job.clientName} · ${job.milestoneLabel}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.xs,
              children: tags,
            ),
          ],
        ],
      ),
    );
  }
}
