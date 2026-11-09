import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/models/json_read.dart';
import '../../finance/models/wallet_data.dart';
import '../../finance/widgets/read_view.dart';
import '../../home/screens/home_screen.dart';
import '../../settings/data/settings_data.dart';
import '../widgets/buy_bids_sheet.dart';

/// The account's money at a glance, read from `GET /api/wallet`.
///
/// The balance, the connects count, both ledgers and the jobs that paid out are
/// the server's own rows — the same query the website's Wallet page runs. The
/// screen reads once when it opens and again when it is pulled, never on a
/// timer, and a read that fails is shown as an error with a retry rather than as
/// a number the app cannot confirm.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  /// Settings opens straight onto the tab that takes a payout request.
  static int get withdrawalsTab => SettingsData.tabs.indexOf('Withdrawals');

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => WalletController.instance.load(),
    );
  }

  void _openWithdrawals(BuildContext context) => Navigator.pushNamed(
    context,
    RouteNames.settings,
    arguments: WalletScreen.withdrawalsTab,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WalletController.instance,
      builder: (context, _) {
        final controller = WalletController.instance;
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bodyWidth = constraints.maxWidth > 760
                    ? 760.0
                    : constraints.maxWidth;

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
                        builder: (context) => _WalletBody(
                          snapshot: controller.value,
                          onWithdrawals: () => _openWithdrawals(context),
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
    );
  }
}

class _WalletBody extends StatelessWidget {
  final WalletSnapshot snapshot;
  final VoidCallback onWithdrawals;

  const _WalletBody({required this.snapshot, required this.onWithdrawals});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final deposit = snapshot.pendingDeposit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BalanceCard(
          balance: snapshot.balance,
          connects: snapshot.connects,
          sideBySide: width >= 480,
          onWithdrawals: onWithdrawals,
        ),
        const SizedBox(height: AppDimensions.xs + 2),
        Text(
          'Track your balance, connects and money activity. '
          'Payouts are requested from Settings → Withdrawals.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (deposit != null) ...[
          const SizedBox(height: AppDimensions.md),
          _DepositRow(deposit: deposit),
        ],
        const SizedBox(height: AppDimensions.lg),
        _QuickActionsCard(onWithdrawals: onWithdrawals),
        const SizedBox(height: AppDimensions.md),
        _MoneyActivityCard(rows: snapshot.moneyActivity),
        const SizedBox(height: AppDimensions.md),
        _ConnectsActivityCard(rows: snapshot.connectsActivity),
        const SizedBox(height: AppDimensions.md),
        _EarningsCard(rows: snapshot.earnings),
        const SizedBox(height: AppDimensions.md),
      ],
    );
  }
}

/// The dark summary card: what can be withdrawn, what is left to apply with,
/// and the one action that turns either into money.
class _BalanceCard extends StatelessWidget {
  final double? balance;
  final int? connects;
  final bool sideBySide;
  final VoidCallback onWithdrawals;

  const _BalanceCard({
    required this.balance,
    required this.connects,
    required this.sideBySide,
    required this.onWithdrawals,
  });

  @override
  Widget build(BuildContext context) {
    final figures = [
      _Figure(
        label: 'Available balance',
        value: balance == null ? '—' : usd(balance!),
        note: balance == null
            ? 'The server has not reported a balance.'
            : 'What a withdrawal request can draw on.',
      ),
      _Figure(
        label: 'Connects on account',
        value: connects == null ? '—' : '$connects',
        note: (connects ?? 0) > 0
            ? 'Enough to keep applying.'
            : 'Activate a plan or buy bids to apply.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sideBySide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: figures.first),
                  const SizedBox(width: AppDimensions.lg),
                  Expanded(child: figures.last),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                figures.first,
                const SizedBox(height: AppDimensions.md),
                figures.last,
              ],
            ),
          const SizedBox(height: AppDimensions.lg),
          _PillButton(
            label: 'Go to Withdrawals',
            icon: Icons.arrow_outward_rounded,
            onTap: onWithdrawals,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String note;

  const _Figure({required this.label, required this.value, required this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.accent,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppDimensions.xs + 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.xs),
        Text(
          note,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// A deposit the server has recorded but not yet credited.
class _DepositRow extends StatelessWidget {
  final WalletDeposit deposit;

  const _DepositRow({required this.deposit});

  @override
  Widget build(BuildContext context) {
    final amount = deposit.amountUsd == null ? '—' : usd(deposit.amountUsd!);
    final connects = deposit.connects;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(Icons.hourglass_bottom_rounded),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${deposit.packageName} deposit pending',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  '$amount${connects == null ? '' : ' · $connects connects'}'
                  ' · recorded ${_depositWhen(deposit.at)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _depositWhen(DateTime? at) =>
      at == null ? 'by the server' : shortDate(at);
}

/// The four destinations this screen can actually reach.
class _QuickActionsCard extends StatelessWidget {
  final VoidCallback onWithdrawals;

  const _QuickActionsCard({required this.onWithdrawals});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick actions', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              _PillButton(
                label: 'Activate plan',
                icon: Icons.workspace_premium_outlined,
                filled: false,
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.membershipPlan),
              ),
              _PillButton(
                label: 'Buy bids',
                icon: Icons.gavel,
                filled: false,
                onTap: () => showBuyBidsSheet(context),
              ),
              _PillButton(
                label: 'Find work',
                icon: Icons.work_outline,
                filled: false,
                onTap: () => HomeScreen.openTab(context, HomeScreen.boardTab),
              ),
              _PillButton(
                label: 'Withdraw earnings',
                icon: Icons.payments_outlined,
                filled: false,
                onTap: onWithdrawals,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Manage payout methods and withdrawal requests in Settings → '
            'Withdrawals.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The wallet ledger, newest first, exactly as far as the server has answered.
class _MoneyActivityCard extends StatelessWidget {
  final List<MoneyRow> rows;

  const _MoneyActivityCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _LedgerCard(
      title: 'Money activity',
      icon: Icons.account_balance_wallet_outlined,
      empty: 'No money activity yet.',
      note: 'The server keeps a ledger row for each movement of the balance.',
      link: 'Open transactions',
      onLink: () => Navigator.pushNamed(context, RouteNames.transactions),
      entries: [
        for (final row in rows.take(_LedgerCard.shown))
          _LedgerRow(
            title: row.reason.isEmpty ? _typeLabel(row.type) : row.reason,
            subtitle: row.at == null
                ? _typeLabel(row.type)
                : '${_typeLabel(row.type)} · ${shortDateTime(row.at!)}',
            trailing: row.amountLabel,
            credit: (row.amount ?? 0) >= 0,
          ),
      ],
      total: rows.length,
    );
  }
}

class _ConnectsActivityCard extends StatelessWidget {
  final List<ConnectsRow> rows;

  const _ConnectsActivityCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _LedgerCard(
      title: 'Connects activity',
      icon: Icons.account_tree_outlined,
      empty: 'No connects activity yet.',
      note: 'A purchase adds connects and applying to a project spends them.',
      link: 'Buy connects',
      onLink: () => showBuyBidsSheet(context),
      entries: [
        for (final row in rows.take(_LedgerCard.shown))
          _LedgerRow(
            title: row.reason,
            subtitle: row.at == null ? '' : shortDateTime(row.at!),
            trailing: row.deltaLabel,
            credit: (row.delta ?? 0) >= 0,
          ),
      ],
      total: rows.length,
    );
  }
}

/// The jobs that cleared escrow, with what happened to each payout.
class _EarningsCard extends StatelessWidget {
  final List<WalletEarning> rows;

  const _EarningsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _LedgerCard(
      title: 'Earnings by job',
      icon: Icons.trending_up_rounded,
      empty: 'No approved job has paid out yet.',
      note: 'Only work the client approved appears here.',
      link: 'View overview',
      onLink: () => Navigator.pushNamed(context, RouteNames.overview),
      entries: [
        for (final row in rows.take(_LedgerCard.shown))
          _LedgerRow(
            title: row.taskTitle.isEmpty ? 'Project' : row.taskTitle,
            subtitle: [
              if (row.clientName.isNotEmpty) row.clientName,
              if (row.at != null) shortDate(row.at!),
              row.statusLabel,
            ].join(' · '),
            trailing: row.amountLabel,
            credit: true,
          ),
      ],
      total: rows.length,
    );
  }
}

/// The frame all three lists share: header, rows or empty state, and the link
/// that takes the screen to the module that shows the whole thing.
class _LedgerCard extends StatelessWidget {
  static const int shown = 6;

  final String title;
  final IconData icon;
  final String empty;
  final String note;
  final String link;
  final VoidCallback onLink;
  final List<Widget> entries;
  final int total;

  const _LedgerCard({
    required this.title,
    required this.icon,
    required this.empty,
    required this.note,
    required this.link,
    required this.onLink,
    required this.entries,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: AppTextStyles.heading4)),
              const SizedBox(width: AppDimensions.sm),
              IconBadge(icon),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          if (entries.isEmpty) ...[
            Text(empty, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimensions.xs + 2),
          ] else ...[
            for (final row in entries) row,
            if (total > entries.length) ...[
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Showing the latest ${entries.length} of $total.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.sm),
          ],
          Text(
            note,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              label: link,
              icon: Icons.arrow_forward_rounded,
              filled: false,
              onTap: onLink,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final bool credit;

  const _LedgerRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.credit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              trailing,
              style: AppTextStyles.labelLarge.copyWith(
                color: credit ? AppColors.success : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sage action pill on the dark card, and its outlined twin on white.
///
/// The label is fitted rather than wrapped so the narrowest phone can still
/// read a two-word action instead of losing it to an overflow.
class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final onDark = filled;
    return Material(
      color: onDark ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: onDark ? AppColors.accent : AppColors.border,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: AppDimensions.iconSm,
                  color: onDark ? AppColors.primary : AppColors.primaryLight,
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: onDark ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Which way one ledger row moved the balance, in words the account can read.
/// The stored `type` is the column's own `CREDIT` or `DEBIT`.
String _typeLabel(String type) => switch (type.toUpperCase()) {
  'CREDIT' => 'Money in',
  'DEBIT' => 'Money out',
  _ => type,
};
