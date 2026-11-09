import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
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
/// same query the website's My stats page runs, with the same two windows. A
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

  /// The chart renders one `Expanded` per day, so 30 points on a narrow phone
  /// crush to nothing: it draws the latest stretch and says so underneath.
  static const int _chartDays = 14;

  int _metricTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => StatsController.instance.load(),
    );
  }

  static String _windowLabel(int days) => 'Last $days Days';

  static List<String> get _windowItems => [
    for (final days in StatsController.windows) _windowLabel(days),
  ];

  /// The label back to the day count the route accepts. A label outside the
  /// three the screen offers is ignored rather than sent as a window the server
  /// would quietly swap for its own default.
  static int? _daysFor(String label) {
    for (final days in StatsController.windows) {
      if (_windowLabel(days) == label) return days;
    }
    return null;
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
            dropdown: AppDropdown(
              value: _windowLabel(controller.proposalDays),
              items: _windowItems,
              onChanged: (value) {
                final days = _daysFor(value);
                if (days != null) controller.setProposalDays(days);
              },
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
            dropdown: AppDropdown(
              value: _windowLabel(controller.profileDays),
              items: _windowItems,
              onChanged: (value) {
                final days = _daysFor(value);
                if (days != null) controller.setProfileDays(days);
              },
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

  /// The capped chart plus what the server totals for the window it covers.
  List<Widget> _metricChart(MyStatsSnapshot stats) {
    final series = _metricSeries(stats);
    final shown = series.length > _chartDays
        ? series.sublist(series.length - _chartDays)
        : series;
    final impressions = stats.impressions;
    final clicks = stats.clicks;

    return [
      _BarChart(bars: shown, color: AppColors.primary, twoLineLabels: true),
      if (series.length > shown.length) ...[
        const SizedBox(height: AppDimensions.sm),
        Text(
          'Showing the latest ${shown.length} of ${series.length} days.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
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
  final Widget dropdown;

  const _PanelHeader({required this.title, required this.dropdown});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dropdownWidth = 176.0;
        if (constraints.maxWidth < dropdownWidth + 140) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading4),
              const SizedBox(height: AppDimensions.sm),
              SizedBox(width: constraints.maxWidth, child: dropdown),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.heading4)),
            SizedBox(width: dropdownWidth, child: dropdown),
          ],
        );
      },
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<({String label, int value})> bars;
  final Color color;
  final bool twoLineLabels;

  const _BarChart({
    required this.bars,
    required this.color,
    this.twoLineLabels = false,
  });

  static const double _chartHeight = 150;

  @override
  Widget build(BuildContext context) {
    var peak = 1;
    for (final bar in bars) {
      if (bar.value > peak) peak = bar.value;
    }

    return Row(
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
  }
}
