import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/stats_controller.dart';
import '../../finance/models/my_stats.dart';
import '../../finance/widgets/read_view.dart';
import '../widgets/buy_bids_sheet.dart';

/// My stats, read from `GET /api/reports/my-stats`.
///
/// The earnings total, the Job Success Score, the connects on the account, the
/// proposal funnel and the daily profile series are the server's own rows — the
/// same query the website's My stats page runs, for the selected date ranges. A
/// figure the account has not earned stays the server's absence rather than
/// becoming a number the app invented. The screen reads once when it opens and
/// again when it is pulled, never on a timer.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const List<String> _metricTabs = [
    'Profile Views',
    'Impression & Clicks',
  ];

  int _metricTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StatsController.instance.load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModuleAppBar(
        title: 'My stats',
        subtitle: 'Earnings, jobs and hours',
      ),
      body: ListenableBuilder(
        listenable: StatsController.instance,
        builder: (context, _) {
          final controller = StatsController.instance;
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardsSideBySide = width >= 900;
                final panelsSideBySide = width >= 1080;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: ReadView(
                          state: controller.state,
                          error: controller.error,
                          onRetry: () => controller.load(force: true),
                          builder: (context) => _body(
                            context,
                            controller,
                            cardsSideBySide,
                            panelsSideBySide,
                          ),
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

  Widget _body(
    BuildContext context,
    StatsController controller,
    bool cardsSideBySide,
    bool panelsSideBySide,
  ) {
    final stats = controller.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'View proposal history, earnings, profile analytics, '
          'and your Job Success Score.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        _cardsRow(context, stats, cardsSideBySide),
        const SizedBox(height: AppDimensions.lg),
        _panelsRow(controller, stats, panelsSideBySide),
        const SizedBox(height: AppDimensions.lg),
      ],
    );
  }

  Widget _cardsRow(
    BuildContext context,
    MyStatsSnapshot stats,
    bool sideBySide,
  ) {
    final List<Widget> cards = [
      _SummaryCard(
        value: stats.earningsLabel,
        label: '12-month earnings',
        link: 'Transaction history',
        onLink: () => Navigator.pushNamed(context, RouteNames.transactions),
      ),
      _SummaryCard(
        value: stats.successLabel,
        label: 'Job Success Score',
        link: 'View insight',
        onLink: () => _note(
          context,
          stats.jobSuccessScore == null
              ? 'The server has no Job Success Score for this account yet.'
              : "Job Success Score is the server's own figure for this account.",
        ),
      ),
      _SummaryCard(
        value: stats.connects == null ? '—' : 'Bids: ${stats.connects}',
        label: stats.bidBonusLabel,
        link: 'Buy Bids',
        onLink: () => showBuyBidsSheet(context),
      ),
    ];

    if (!sideBySide) {
      return Column(
        children: [
          for (final card in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: card,
            ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimensions.sm),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }

  Widget _panelsRow(
    StatsController controller,
    MyStatsSnapshot stats,
    bool sideBySide,
  ) {
    final proposals = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Proposals (${stats.funnel.proposals})',
            range: _CalendarRange(
              start: controller.proposalStart,
              end: controller.proposalEnd,
              enabled: !controller.isBusy,
              onChanged: controller.setProposalRange,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          _BarChart(
            bars: stats.funnelBars,
            color: AppColors.info,
            twoLineLabels: false,
          ),
        ],
      ),
    );

    final metrics = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Profile metrics',
            range: _CalendarRange(
              start: controller.profileStart,
              end: controller.profileEnd,
              enabled: !controller.isBusy,
              onChanged: controller.setProfileRange,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.xs,
            children: [
              for (var i = 0; i < _metricTabs.length; i++)
                AppTag(
                  _metricTabs[i],
                  selected: _metricTab == i,
                  onTap: () => setState(() => _metricTab = i),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          if (_metricSeries(stats).isEmpty)
            Text(
              'The server reported no profile activity in this window.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ..._metricChart(stats),
        ],
      ),
    );

    if (!sideBySide) {
      return Column(
        children: [
          proposals,
          const SizedBox(height: AppDimensions.md),
          metrics,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: proposals),
          const SizedBox(width: AppDimensions.md),
          Expanded(flex: 3, child: metrics),
        ],
      ),
    );
  }

  /// The daily series the selected tab asks for, in the server's own order.
  List<({String label, int value})> _metricSeries(MyStatsSnapshot stats) =>
      _metricTab == 0 ? stats.viewBars : stats.impressionBars;

  List<Widget> _metricChart(MyStatsSnapshot stats) {
    final series = _metricSeries(stats);
    final impressions = stats.impressions;
    final clicks = stats.clicks;

    return [
      _BarChart(
        bars: series,
        color: AppColors.primary,
        twoLineLabels: true,
        scrollable: true,
      ),
      if (_metricTab == 1) ...[
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Impressions ${impressions ?? '—'} · Clicks ${clicks ?? '—'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ];
  }

  void _note(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final String link;
  final VoidCallback onLink;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.link,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.heading3.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(label, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppDimensions.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onLink,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  const Icon(
                    Icons.arrow_outward,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final String title;
  final Widget range;

  const _PanelHeader({required this.title, required this.range});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heading4),
        const SizedBox(height: AppDimensions.sm),
        range,
      ],
    );
  }
}

class _CalendarRange extends StatelessWidget {
  final DateTime start;
  final DateTime? end;
  final bool enabled;
  final Future<void> Function(DateTime start, DateTime? end) onChanged;

  const _CalendarRange({
    required this.start,
    required this.end,
    required this.enabled,
    required this.onChanged,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _label(DateTime? date) {
    if (date == null) return 'Today (optional)';
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickStart(BuildContext context) async {
    final today = _dateOnly(DateTime.now());
    final chosen = await showDatePicker(
      context: context,
      initialDate: start.isAfter(today) ? today : start,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Select start date',
    );
    if (chosen == null) return;
    final nextStart = _dateOnly(chosen);
    await onChanged(
      nextStart,
      end != null && end!.isBefore(nextStart) ? null : end,
    );
  }

  Future<void> _pickEnd(BuildContext context) async {
    final today = _dateOnly(DateTime.now());
    final currentEnd = end;
    final chosen = await showDatePicker(
      context: context,
      initialDate: currentEnd ?? (start.isAfter(today) ? today : start),
      firstDate: start,
      lastDate: today,
      helpText: 'Select optional end date',
    );
    if (chosen == null) return;
    await onChanged(start, _dateOnly(chosen));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.xs,
      runSpacing: AppDimensions.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? () => _pickStart(context) : null,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text('From ${_label(start)}'),
        ),
        OutlinedButton.icon(
          onPressed: enabled ? () => _pickEnd(context) : null,
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text('To ${_label(end)}'),
        ),
        if (end != null)
          IconButton(
            tooltip: 'Clear end date',
            onPressed: enabled ? () => onChanged(start, null) : null,
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<({String label, int value})> bars;
  final Color color;
  final bool twoLineLabels;
  final bool scrollable;

  const _BarChart({
    required this.bars,
    required this.color,
    this.twoLineLabels = false,
    this.scrollable = false,
  });

  static const double _chartHeight = 150;

  @override
  Widget build(BuildContext context) {
    var peak = 1;
    for (final bar in bars) {
      if (bar.value > peak) peak = bar.value;
    }

    final chart = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bar in bars)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${bar.value}',
                      maxLines: 1,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Container(
                    height: (bar.value / peak) * _chartHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppDimensions.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  twoLineLabels
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            children: [
                              Text(
                                bar.label.split(' ').first,
                                maxLines: 1,
                                style: AppTextStyles.caption,
                              ),
                              Text(
                                bar.label.split(' ').last,
                                maxLines: 1,
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          height: 28,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              bar.label,
                              maxLines: 1,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
      ],
    );
    if (!scrollable) return chart;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, bars.length * 64).toDouble(),
          child: chart,
        ),
      ),
    );
  }
}
