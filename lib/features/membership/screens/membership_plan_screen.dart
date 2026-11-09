import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../billing/controller/billing_controller.dart';
import '../../packages/controller/package_controller.dart';
import '../../packages/models/package_entry.dart';
import '../data/membership_plans.dart';
import '../widgets/plan_card.dart';

/// Membership Plan tab, built from the supplied reference and from the
/// `MEMBERSHIP` packages the backend sells. Continuing opens Stripe's hosted
/// Checkout; the tier only becomes active once the server confirms the payment.
class MembershipPlanScreen extends StatefulWidget {
  const MembershipPlanScreen({super.key});

  @override
  State<MembershipPlanScreen> createState() => _MembershipPlanScreenState();
}

class _MembershipPlanScreenState extends State<MembershipPlanScreen> {
  static const PackageKind _kind = PackageKind.membership;

  final BillingController _billing = BillingController.instance;
  final PackageController _catalog = PackageController.instance;

  @override
  void initState() {
    super.initState();
    // The tiers are the server's rows, asked for on every visit so a change
    // made in the Admin Panel shows without relaunching the app.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _catalog.load(_kind, force: true),
    );
  }

  void _buy(MembershipPlan plan) => _billing.purchase(plan);

  Future<void> _verify() async {
    await _billing.verify();
    if (!mounted || _billing.status != BillingStatus.confirmed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_billing.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final threeColumns = width >= 980;

          return RefreshIndicator(
            onRefresh: () => _catalog.load(_kind, force: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Simple, Honest Pricing',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading1.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            'Applying is always free. Paid tiers add visibility, '
                            'workflow tools and support.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      _StatusStrip(
                        billing: _billing,
                        onVerify: _verify,
                        onDismiss: _billing.reset,
                      ),
                      const SizedBox(height: AppDimensions.xl),
                      _PlanArea(
                        catalog: _catalog,
                        threeColumns: threeColumns,
                        onBuy: _buy,
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

/// What the last checkout step reported, and the one action that follows it:
/// ask the server about the payment, or clear the message. Nothing here runs on
/// a timer — the browser closing is not an event the app acts on.
class _StatusStrip extends StatelessWidget {
  final BillingController billing;
  final Future<void> Function() onVerify;
  final VoidCallback onDismiss;

  const _StatusStrip({
    required this.billing,
    required this.onVerify,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) {
        final status = billing.status;
        if (status == BillingStatus.idle) return const SizedBox.shrink();
        final awaitingPayment =
            status == BillingStatus.opened || status == BillingStatus.pending;
        final text = billing.message.isEmpty
            ? 'Contacting Stripe…'
            : billing.message;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.lg),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radius),
              border: Border.all(
                color: switch (status) {
                  BillingStatus.confirmed => AppColors.success,
                  BillingStatus.pending ||
                  BillingStatus.failed => AppColors.error,
                  _ => AppColors.border,
                },
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                SizedBox(
                  width: 150,
                  child: AppButton(
                    text: awaitingPayment ? 'Check payment' : 'Dismiss',
                    isLoading: status == BillingStatus.working,
                    onPressed: status == BillingStatus.working
                        ? null
                        : () => awaitingPayment ? onVerify() : onDismiss(),
                    backgroundColor: AppColors.accent,
                    textColor: AppColors.primary,
                    borderRadius: AppDimensions.radiusXl,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The tiers on screen, or whatever the read answered. The list is asked for
/// when the screen opens and when Retry is pressed — never on a timer.
class _PlanArea extends StatelessWidget {
  final PackageController catalog;
  final bool threeColumns;
  final ValueChanged<MembershipPlan> onBuy;

  const _PlanArea({
    required this.catalog,
    required this.threeColumns,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        const kind = PackageKind.membership;
        final status = catalog.statusOf(kind);
        final plans = catalog.packages(kind);

        // Tiers already on screen stay put while the fresh rows are read, so a
        // visit never blanks the list out.
        if (plans.isEmpty &&
            (status == PackageStatus.loading || status == PackageStatus.idle)) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.xxl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (plans.isEmpty && status == PackageStatus.error) {
          final message = catalog.errorFor(kind);
          return Column(
            children: [
              Text(
                message.isEmpty
                    ? 'The membership plans could not be loaded.'
                    : message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              SizedBox(
                width: 130,
                child: AppButton(
                  text: 'Retry',
                  onPressed: () => catalog.load(kind, force: true),
                  backgroundColor: AppColors.surfaceVariant,
                  textColor: AppColors.textPrimary,
                  borderRadius: AppDimensions.radiusXl,
                ),
              ),
            ],
          );
        }

        final cards = [
          for (final plan in plans)
            _PlanSlot(plan: plan, onContinue: () => onBuy(plan)),
        ];
        if (cards.isEmpty) {
          return Center(
            child: Text(
              'Membership plans are not available right now.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        if (threeColumns) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index != cards.length - 1)
                    const SizedBox(width: AppDimensions.lg),
                ],
              ],
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                for (final card in cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.xl),
                    // The stacked column is unbounded, so give the
                    // card a height to lay its Spacer out against.
                    child: IntrinsicHeight(child: card),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanSlot extends StatelessWidget {
  final MembershipPlan plan;
  final VoidCallback onContinue;

  const _PlanSlot({required this.plan, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: plan.featured ? AppDimensions.lg : 0),
          child: PlanCard(plan: plan, onContinue: onContinue),
        ),
        if (plan.featured)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.xs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            ),
            child: Text(
              'Most Popular',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
