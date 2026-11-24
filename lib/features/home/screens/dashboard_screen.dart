import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../finance/controller/overview_controller.dart';
import '../../finance/controller/stats_controller.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/models/json_read.dart';
import '../../finance/models/my_stats.dart';
import '../../finance/models/reports_overview.dart';
import '../../finance/models/wallet_data.dart';
import '../../finance/widgets/read_view.dart';
import '../../profile/controller/profile_controller.dart';

/// Home tab: the account's scorecard, read from the three routes the website
/// itself runs — `GET /api/wallet`, `GET /api/reports/overview` and
/// `GET /api/reports/my-stats`.
///
/// Every figure here is a column the server answered with, written by the
/// model's own `usd`, `earningsLabel`, `successLabel` and `shortDate`, so an
/// amount no route reported stays a dash rather than becoming an estimate. A
/// tile nothing reports was dropped instead of filled in: the response rate,
/// on-time delivery, a positive rating, an average selling price, an active and
/// a cancelled order count, a seller level and a level progress bar have no
/// endpoint behind them.
///
/// The three reads start once, after the first frame, and are asked again only
/// by a pull. Nothing here runs on a timer, and a read that fails becomes its
/// own error card with a retry rather than a figure carried over from the last.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// The three reads this screen shares with the wallet, overview and stats
  /// modules. They are singletons, so a figure already read for one of those
  /// screens is not asked for a second time here.
  static final Listenable _readables = Listenable.merge([
    WalletController.instance,
    OverviewController.instance,
    StatsController.instance,
  ]);

  @override
  void initState() {
    super.initState();
    // Deferred to after the frame because each controller notifies from inside
    // the very listener this build installs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WalletController.instance.load();
      OverviewController.instance.load();
      StatsController.instance.load();
    });
  }

  /// Pull-to-refresh only: the three routes, forced, in one go.
  Future<void> _refresh() => Future.wait([
    WalletController.instance.refresh(),
    OverviewController.instance.refresh(),
    StatsController.instance.refresh(),
  ]);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: _readables,
        builder: (context, _) {
          final wallet = WalletController.instance;
          final overview = OverviewController.instance;
          final stats = StatsController.instance;
          // Each section is drawn from its own route, so one read that fails
          // costs that card alone and offers its own retry.
          final connectsBody = _ConnectsCard(
            snapshot: wallet.value,
            onWallet: () => Navigator.pushNamed(context, RouteNames.wallet),
          );
          final earningsBody = _EarningsCard(
            overview: overview.value,
            onDetails: () =>
                Navigator.pushNamed(context, RouteNames.transactions),
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The chip carries the plan the wallet route reports, and
                      // stays out of the row until that read has answered, so
                      // the greeting cannot imply a plan nothing confirmed.
                      _IdentityRow(
                        badge: wallet.hasValue
                            ? (wallet.value.planActive
                                  ? 'Plan active'
                                  : 'No active plan')
                            : null,
                      ),
                      const SizedBox(height: AppDimensions.lg),
                      ReadView(
                        state: stats.state,
                        error: stats.error,
                        onRetry: () => stats.load(force: true),
                        builder: (context) => _PerformancesCard(
                          stats: stats.value,
                          proposalDays: stats.proposalDays,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // A wallet with no ledger rows still has its connects and
                      // its pending deposit, so the card is drawn for that too.
                      ReadView(
                        state: wallet.state,
                        error: wallet.error,
                        onRetry: () => wallet.load(force: true),
                        builder: (context) => connectsBody,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      // The four amounts are totals the overview route works
                      // out whether or not it sent any job rows with them.
                      ReadView(
                        state: overview.state,
                        error: overview.error,
                        onRetry: () => overview.load(force: true),
                        builder: (context) => earningsBody,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The account's own name, which is the session's, and the plan it holds.
class _IdentityRow extends StatelessWidget {
  final String? badge;

  const _IdentityRow({this.badge});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileController.instance,
      builder: (context, _) {
        final name = ProfileController.instance.name;
        return Row(
          children: [
            Expanded(
              child: Text(
                name.isEmpty ? 'Your dashboard' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading3,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: AppDimensions.md),
              _PlanChip(label: badge!),
            ],
          ],
        );
      },
    );
  }
}

/// The level chip the demo account carried, now the plan the wallet route
/// reports for this one.
class _PlanChip extends StatelessWidget {
  final String label;

  const _PlanChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified,
            size: AppDimensions.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.xs + 2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One judged figure: the number it shows and how far its ring is filled.
typedef _Metric = ({String label, String value, double fraction});

/// The one performance percentage a route reports, beside the earnings total
/// and the proposal funnel the same stats route worked out.
class _PerformancesCard extends StatelessWidget {
  final MyStatsSnapshot stats;
  final int proposalDays;

  const _PerformancesCard({required this.stats, required this.proposalDays});

  @override
  Widget build(BuildContext context) {
    final score = stats.jobSuccessScore;
    final metric = (
      label: 'Job Success Score',
      value: score == null ? '—' : stats.successLabel,
      // The sweep is the score's own percentage, not a second figure the screen
      // worked out.
      fraction: ((score ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
    );

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performances', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final facts = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FactRow(
                    label: 'Earnings (last 12 months)',
                    value: stats.earningsLabel,
                  ),
                  for (final bar in stats.funnelBars)
                    _FactRow(label: bar.label, value: '${bar.value}'),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    'The score, the earnings total and this funnel are the '
                    'stats route\'s own figures, with proposals counted over '
                    'its $proposalDays-day window. ${stats.bidBonusLabel}',
                    style: AppTextStyles.caption,
                  ),
                ],
              );
              final ring = _MetricRing(
                metric: metric,
                diameter: (constraints.maxWidth * 0.3).clamp(46.0, 76.0),
              );
              // Ring and figures share a row as soon as both stay readable at
              // that width; below it they stack.
              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ring,
                    const SizedBox(height: AppDimensions.md),
                    facts,
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ring,
                    const SizedBox(width: AppDimensions.md),
                    Expanded(child: facts),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricRing extends StatelessWidget {
  final _Metric metric;
  final double diameter;

  const _MetricRing({required this.metric, required this.diameter});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          // Begins empty so the sweep reads as progress even for a full ring.
          tween: Tween(
            begin: 0,
            end: metric.fraction.clamp(0.0, 1.0).toDouble(),
          ),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => SizedBox(
            width: diameter,
            height: diameter,
            child: CustomPaint(
              painter: _RingPainter(
                progress: value,
                stroke: (diameter * 0.09).clamp(4.0, 7.0),
                trackColor: AppColors.surfaceVariant,
                fillColor: AppColors.primary,
              ),
              child: Center(child: _Figure(metric: metric)),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          width: diameter + 18,
          child: Text(
            metric.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

/// The number inside a ring. No route reports a rating, so no figure here
/// carries the star the demo rating did.
class _Figure extends StatelessWidget {
  final _Metric metric;

  const _Figure({required this.metric});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        metric.value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Color trackColor;
  final Color fillColor;

  const _RingPainter({
    required this.progress,
    required this.stroke,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    if (progress <= 0) return;
    // The sweep begins at twelve o'clock and closes clockwise.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

/// The connects the wallet route counts and the deposit it is still holding,
/// opened on request so the scorecard stays short by default.
class _ConnectsCard extends StatefulWidget {
  final WalletSnapshot snapshot;
  final VoidCallback onWallet;

  const _ConnectsCard({required this.snapshot, required this.onWallet});

  @override
  State<_ConnectsCard> createState() => _ConnectsCardState();
}

class _ConnectsCardState extends State<_ConnectsCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final deposit = widget.snapshot.pendingDeposit;

    return AppCard(
      onTap: () => setState(() => _open = !_open),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(Icons.trending_up_outlined, size: 30),
              const SizedBox(width: AppDimensions.md),
              const Expanded(
                child: Text(
                  'Connects and deposits',
                  style: AppTextStyles.labelLarge,
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(
                  Icons.expand_more,
                  size: AppDimensions.iconMd,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FactRow(
                          label: 'Connects on account',
                          value: _count(widget.snapshot.connects),
                        ),
                        if (deposit != null) ...[
                          if (deposit.packageName.isNotEmpty)
                            _FactRow(
                              label: '${deposit.packageName} deposit',
                              value: deposit.status.isEmpty
                                  ? '—'
                                  : deposit.status,
                            ),
                          _FactRow(
                            label: 'Deposit amount',
                            value: _money(deposit.amountUsd),
                          ),
                          _FactRow(
                            label: 'Deposit connects',
                            value: _count(deposit.connects),
                          ),
                          _FactRow(
                            label: 'Recorded',
                            value: deposit.at == null
                                ? '—'
                                : shortDate(deposit.at!),
                          ),
                        ] else
                          Text(
                            'No deposit is waiting to be credited.',
                            style: AppTextStyles.bodySmall,
                          ),
                        const SizedBox(height: AppDimensions.sm),
                        Text(
                          'A purchase adds connects and applying to a project '
                          'spends them. Balances, ledgers and payout requests '
                          'are on the wallet screen.',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        // Navigation only: this card reports no figure that
                        // belongs on the wallet screen's own summary.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: widget.onWallet,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.sm,
                              ),
                              foregroundColor: AppColors.primaryLight,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Open wallet',
                              style: AppTextStyles.labelMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          const SizedBox(width: AppDimensions.md),
          // A figure the route left out is a dash, and a long one gives up
          // width rather than pushing past the card.
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _EarningsCell = ({String label, String value, Color color});

/// The four amounts the overview route totals for the account, with the
/// transactions screen one tap away.
class _EarningsCard extends StatelessWidget {
  final ReportsOverview overview;
  final VoidCallback onDetails;

  const _EarningsCard({required this.overview, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final cells = <_EarningsCell>[
      (
        label: 'Available for withdrawal',
        value: _money(overview.availableBalance),
        color: AppColors.secondary,
      ),
      (
        label: 'Work in progress',
        value: _money(overview.workInProgressAmount),
        color: AppColors.info,
      ),
      (
        label: 'In review',
        value: _money(overview.inReviewAmount),
        color: AppColors.primaryLight,
      ),
      (
        label: 'Payments being cleared',
        value: _money(overview.pendingWithdrawalsAmount),
        color: Color.lerp(AppColors.warning, AppColors.primaryDark, 0.35)!,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? 3 : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Earnings', style: AppTextStyles.heading4),
                  ),
                  TextButton(
                    onPressed: onDetails,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                      ),
                      foregroundColor: AppColors.primaryLight,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Details',
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              for (int start = 0; start < cells.length; start += columns)
                Padding(
                  padding: EdgeInsets.only(
                    top: start == 0 ? 0 : AppDimensions.lg,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: start + column < cells.length
                              ? _EarningsCellWidget(cell: cells[start + column])
                              : const SizedBox(),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppDimensions.md),
              Text(
                'Each amount is a total the overview route worked out for this '
                'account. A total it left out is a dash, never a zero.',
                style: AppTextStyles.caption,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EarningsCellWidget extends StatelessWidget {
  final _EarningsCell cell;

  const _EarningsCellWidget({required this.cell});

  @override
  Widget build(BuildContext context) {
    final value = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: cell.color,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cell.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppDimensions.xs),
        // A payout figure can outgrow a half-width phone cell, so it gives up
        // size rather than spilling past the card.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(cell.value, style: value),
        ),
      ],
    );
  }
}

/// An amount the route did not send stays a dash; the writing of a figure that
/// did arrive is the model layer's own [usd].
String _money(double? amount) => amount == null ? '—' : usd(amount);

/// A count the route did not send is a dash rather than the zero it never
/// reported.
String _count(int? value) => value == null ? '—' : '$value';
