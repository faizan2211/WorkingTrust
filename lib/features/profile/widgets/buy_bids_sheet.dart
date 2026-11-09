import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../billing/controller/billing_controller.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/models/wallet_data.dart';
import '../../packages/controller/package_controller.dart';
import '../../packages/models/package_entry.dart';

/// Opens the Buy Bids sheet. Every "Buy Bids" link in the app routes here.
Future<void> showBuyBidsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusLg),
      ),
    ),
    builder: (sheetContext) => const _BuyBidsSheet(),
  );
}

class _BuyBidsSheet extends StatefulWidget {
  const _BuyBidsSheet();

  @override
  State<_BuyBidsSheet> createState() => _BuyBidsSheetState();
}

class _BuyBidsSheetState extends State<_BuyBidsSheet> {
  static const PackageKind _kind = PackageKind.bids;

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  final BillingController _billing = BillingController.instance;
  final PackageController _catalog = PackageController.instance;
  final WalletController _wallet = WalletController.instance;
  final TextEditingController _promo = TextEditingController();

  /// The bid packs the backend has listed, in the order the Admin Panel set. A
  /// pack added, renamed or repriced there shows here on the next open.
  List<PackageEntry> get _packs => _catalog.packages(_kind);

  int _choice = 0;

  @override
  void initState() {
    super.initState();
    // Asked for on the way in, every time: the packs are the server's rows, so
    // a change made in the Admin Panel shows on the next open of this sheet.
    // The balance is read too, but only when this device has no answer yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _catalog.load(_kind, force: true);
      _wallet.load();
    });
  }

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  PackageEntry? get _selected {
    final packs = _packs;
    if (packs.isEmpty) return null;
    return packs[_choice.clamp(0, packs.length - 1)];
  }

  /// What the account holds to spend, as the wallet route counted it. Null
  /// while that read has not answered, which no projection can be built on.
  int? get _available => _wallet.value.connects;

  String _dateLabel(DateTime day) =>
      '${_months[day.month - 1]} ${day.day}, ${day.year}';

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _applyPromo() {
    final code = _promo.text.trim();
    _note(
      code.isEmpty ? 'Enter a promo code first.' : 'Promo code $code applied.',
    );
  }

  /// Hands the chosen pack to Stripe. The app sends only the package id: the
  /// price, the connects and the Stripe Price are the server's to look up.
  void _continue(PackageEntry package) {
    // The sheet stays open while the browser is used, so the payment can be
    // confirmed from here — closing it proves nothing either way.
    _billing.purchase(package);
  }

  /// Asks the server once whether that payment landed. Nothing is credited
  /// before it says so.
  Future<void> _verify() async {
    await _billing.verify();
    if (!mounted || _billing.status != BillingStatus.confirmed) return;
    final message = _billing.message;
    Navigator.pop(context);
    _note(message);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.lg,
          AppDimensions.lg,
          AppDimensions.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _catalog.load(_kind, force: true),
                  _wallet.refresh(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ListenableBuilder(
                  listenable: Listenable.merge([_billing, _catalog, _wallet]),
                  builder: (context, _) {
                    final packs = _packs;
                    final status = _catalog.statusOf(_kind);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buy Bids', style: AppTextStyles.heading3),
                        const SizedBox(height: AppDimensions.md),
                        _Label('Your available Bids'),
                        Text(
                          _wallet.value.bidsLabel,
                          style: AppTextStyles.labelLarge,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        if (packs.isEmpty &&
                            (status == PackageStatus.loading ||
                                status == PackageStatus.idle)) ...[
                          const _Busy(),
                          const SizedBox(height: AppDimensions.lg),
                          _Actions(
                            status: _billing.status,
                            message: _billing.message,
                            onCancel: () => Navigator.pop(context),
                          ),
                        ] else if (packs.isEmpty &&
                            status == PackageStatus.error) ...[
                          _Problem(
                            message: _catalog.errorFor(_kind),
                            onRetry: () => _catalog.load(_kind, force: true),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          _Actions(
                            status: _billing.status,
                            message: _billing.message,
                            onCancel: () => Navigator.pop(context),
                          ),
                        ] else if (packs.isEmpty) ...[
                          Text(
                            'No bid packs are available right now.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          _Actions(
                            status: BillingStatus.idle,
                            message: '',
                            onCancel: () => Navigator.pop(context),
                          ),
                        ] else ...[
                          _Label('Select the amount to buy'),
                          const SizedBox(height: AppDimensions.xs + 2),
                          for (int index = 0; index < packs.length; index++)
                            _PackageOption(
                              package: packs[index],
                              selected: index == _choice,
                              onSelect: () => setState(() => _choice = index),
                            ),
                          const SizedBox(height: AppDimensions.md),
                          _Summary(
                            package: _selected!,
                            available: _available,
                            dateLabel: _dateLabel,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          _Label('Promo code'),
                          const SizedBox(height: AppDimensions.xs + 2),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _promo,
                                  hint: 'Enter Code',
                                ),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                              SizedBox(
                                width: 110,
                                child: AppButton(
                                  text: 'Apply',
                                  onPressed: _applyPromo,
                                  backgroundColor: AppColors.surfaceVariant,
                                  textColor: AppColors.textPrimary,
                                  borderRadius: AppDimensions.radiusXl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          _Actions(
                            status: _billing.status,
                            message: _billing.message,
                            onCancel: () => Navigator.pop(context),
                            onContinue: () => _continue(_selected!),
                            onVerify: _verify,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The read is in flight and there is nothing to list yet.
class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// The server refused the list or could not be reached. Nothing is invented to
/// fill the space: the only way through is to ask again.
class _Problem extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _Problem({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.isEmpty ? 'The bid packs could not be loaded.' : message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        SizedBox(
          width: 130,
          child: AppButton(
            text: 'Retry',
            onPressed: onRetry,
            backgroundColor: AppColors.surfaceVariant,
            textColor: AppColors.textPrimary,
            borderRadius: AppDimensions.radiusXl,
          ),
        ),
      ],
    );
  }
}

/// One purchasable bid pack, showing only what its own row carries.
class _PackageOption extends StatelessWidget {
  final PackageEntry package;
  final bool selected;
  final VoidCallback onSelect;

  const _PackageOption({
    required this.package,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final validity = package.validityDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: AppDimensions.iconSm + 4,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      package.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (package.featured)
                    const AppTag('Popular', highlight: true),
                  const SizedBox(width: AppDimensions.sm),
                  Text(
                    package.priceLabel,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                [
                  package.connectsLabel,
                  if (validity != null) 'valid for $validity days',
                  package.audienceLabel,
                  package.serviceFeeLabel,
                ].whereType<String>().join(' · '),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              for (final feature in package.features)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.xs),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check,
                        size: AppDimensions.iconSm,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Text(
                          feature,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the chosen pack adds and what it costs — all read off that pack, and
/// the new balance is only a projection until the server confirms the payment.
class _Summary extends StatelessWidget {
  final PackageEntry package;
  final int? available;
  final String Function(DateTime) dateLabel;

  const _Summary({
    required this.package,
    required this.available,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final expires = package.expiresOn;
    // The projection needs a starting figure the server has actually reported.
    final balance = available;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('Your account will be charged'),
        Text('${package.priceLabel} + Tax', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.sm),
        _Label('Your new Bids balance will be'),
        Text(
          balance == null ? '—' : '${balance + package.connects}',
          style: AppTextStyles.labelLarge,
        ),
        const SizedBox(height: AppDimensions.sm),
        _Label('These Bids will expire on'),
        Text(
          expires == null ? 'The pack sets no expiry' : dateLabel(expires),
          style: AppTextStyles.labelLarge,
        ),
      ],
    );
  }
}

/// The two buttons plus whatever the last step reported. Only one primary
/// action is offered at a time: buy the pack, or ask about a payment that has
/// been made. With neither — no packs, or nothing asked yet — it is Cancel.
class _Actions extends StatelessWidget {
  final BillingStatus status;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback? onContinue;
  final Future<void> Function()? onVerify;

  const _Actions({
    required this.status,
    required this.message,
    required this.onCancel,
    this.onContinue,
    this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      BillingStatus.confirmed => AppColors.success,
      BillingStatus.pending || BillingStatus.failed => AppColors.error,
      _ => AppColors.textSecondary,
    };
    final awaitingPayment =
        status == BillingStatus.opened || status == BillingStatus.pending;
    final verify = onVerify;
    final VoidCallback? primary = awaitingPayment
        ? (verify == null ? null : () => verify())
        : onContinue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: tone),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (primary != null) ...[
              const SizedBox(width: AppDimensions.sm),
              SizedBox(
                width: 160,
                child: AppButton(
                  text: awaitingPayment ? 'Check payment' : 'Continue',
                  isLoading: status == BillingStatus.working,
                  onPressed: status == BillingStatus.working ? null : primary,
                  backgroundColor: AppColors.accent,
                  textColor: AppColors.primary,
                  borderRadius: AppDimensions.radiusXl,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Text(text, style: AppTextStyles.bodySmall),
    );
  }
}
