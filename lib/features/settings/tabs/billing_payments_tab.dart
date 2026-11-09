import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../models/account_settings.dart';
import '../widgets/settings_primitives.dart';

/// The one saved payment method and the form that writes it.
///
/// `GET /api/account/billing` answers with at most a single method, so the list
/// is that one row or the empty note. `POST` replaces it, and the row a card
/// leaves behind holds only the last four digits and the expiry — the number and
/// the security code travel as far as the route's own check and are kept
/// nowhere, so nothing here can show them again. The brand marks pick the form's
/// look; the route stores no brand, so the saved row shows the summary the
/// server wrote.
class BillingPaymentsTab extends StatefulWidget {
  const BillingPaymentsTab({super.key});

  @override
  State<BillingPaymentsTab> createState() => _BillingPaymentsTabState();
}

class _BillingPaymentsTabState extends State<BillingPaymentsTab> {
  final AccountController _account = AccountController.instance;

  final _card = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _wallet = TextEditingController();

  bool _adding = false;
  int _method = 0;
  int _brand = 0;

  bool get _isCard => _method == 0;

  /// The token `method` is sent as, in the order the radio rows list them.
  String get _methodToken => billingMethodTypes.keys.toList()[_method];

  @override
  void initState() {
    super.initState();
    _account.loadMethods();
  }

  @override
  void dispose() {
    _card.dispose();
    _first.dispose();
    _last.dispose();
    _month.dispose();
    _year.dispose();
    _code.dispose();
    _name.dispose();
    _wallet.dispose();
    super.dispose();
  }

  void _note(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _reportFailure(String fallback) =>
      _note(_account.errorMessage.isEmpty ? fallback : _account.errorMessage);

  void _clearForm() {
    for (final field in [
      _card,
      _first,
      _last,
      _month,
      _year,
      _code,
      _name,
      _wallet,
    ]) {
      field.clear();
    }
  }

  void _cancel() {
    setState(() {
      _adding = false;
      _method = 0;
      _brand = 0;
      _clearForm();
    });
  }

  /// The route's own limits, checked here only so an empty form is not sent.
  /// Anything the server disagrees with comes back in its words.
  List<String> get _missing {
    if (_isCard) {
      final digits = _card.text.replaceAll(RegExp(r'\D'), '');
      return [
        if (digits.length < 13 || digits.length > 19) 'Card number',
        if (_first.text.trim().isEmpty) 'First name',
        if (_last.text.trim().isEmpty) 'Last name',
        if (_month.text.trim().isEmpty) 'Expiration month',
        if (_year.text.trim().isEmpty) 'Expiration year',
        if (_code.text.trim().length < 3) 'Security code',
      ];
    }
    return [
      if (_name.text.trim().length < 2) 'Account name',
      if (_wallet.text.trim().length < 5) 'Account number',
    ];
  }

  Future<void> _save() async {
    final invalid = _missing;
    if (invalid.isNotEmpty) {
      _note(
        '${invalid.join(', ')} ${invalid.length == 1 ? 'is' : 'are'} missing.',
      );
      return;
    }
    final saved = _isCard
        ? await _account.saveCard(
            cardNumber: _card.text.replaceAll(RegExp(r'\D'), ''),
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            expMonth: _month.text.trim(),
            expYear: _year.text.trim(),
            securityCode: _code.text.trim(),
          )
        : await _account.saveWallet(
            method: _methodToken,
            accountName: _name.text.trim(),
            walletAccount: _wallet.text.trim(),
          );
    if (!saved) {
      _reportFailure('The billing method could not be saved.');
      return;
    }
    // Nothing typed for the route to check is kept on the device afterwards.
    _clearForm();
    setState(() {
      _adding = false;
      _method = 0;
      _brand = 0;
    });
    final row = _account.billingMethod;
    _note(
      row == null
          ? 'Billing method saved.'
          : '${row.accountDetails} is your billing method.',
    );
  }

  Future<void> _remove(SavedBillingMethod method) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Remove this billing method?',
          style: AppTextStyles.heading4,
        ),
        content: Text(
          'Nothing will be left to charge for the next purchase.',
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await _account.removeBilling();
    if (!removed) _reportFailure('The billing method could not be removed.');
  }

  Widget _radioRow(String label, int index) {
    final selected = _method == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        onTap: () => setState(() => _method = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.sm,
            horizontal: AppDimensions.xs,
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: AppDimensions.iconSm + 2,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandChips() => Padding(
    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
    child: Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        for (int index = 0; index < SettingsData.cardBrands.length; index++)
          _BrandChip(
            brand: SettingsData.cardBrands[index],
            selected: _brand == index,
            onTap: () => setState(() => _brand = index),
          ),
      ],
    ),
  );

  Widget _pair(String left, String right, {TextInputFormatter? formatter}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final fields = [left, right];
          if (constraints.maxWidth < 380) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: _form(field, formatter: formatter),
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _form(fields[0], formatter: formatter)),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: _form(fields[1], formatter: formatter)),
            ],
          );
        },
      );

  Widget _form(String label, {TextInputFormatter? formatter}) => AppTextField(
    label: label,
    hint: label,
    controller: switch (label) {
      'Card number' => _card,
      'First Name' => _first,
      'Last Name' => _last,
      'Expiration month' => _month,
      'Expiration year' => _year,
      'Security code' => _code,
      'Account name' => _name,
      _ => _wallet,
    },
    keyboardType: formatter == null ? null : TextInputType.number,
    inputFormatters: [?formatter],
    obscureText: label == 'Security code',
    prefixIcon: label == 'Card number'
        ? const Icon(
            Icons.lock_outline,
            size: AppDimensions.iconSm,
            color: AppColors.textSecondary,
          )
        : null,
  );

  /// The saved row. [SavedBillingMethod.accountDetails] is the summary the
  /// route wrote — a name, the last four digits and an expiry for a card — so
  /// the screen has no longer value to show even if one were ever typed.
  Widget _savedRow(SavedBillingMethod method) {
    final summary = method.accountDetails.isEmpty
        ? method.label
        : method.accountDetails;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        children: [
          Icon(
            method.method == 'CARD'
                ? Icons.credit_card_outlined
                : Icons.account_balance_wallet_outlined,
            size: AppDimensions.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: AppTextStyles.bodyMedium),
                if (summary != method.label)
                  Text(
                    method.label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          GhostIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Remove ${method.label}',
            onPressed: () => _remove(method),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _account,
      builder: (context, child) {
        if (_account.isLoading && !_account.hasLoadedMethods) {
          return const AppLoader();
        }
        if (!_account.hasLoadedMethods) {
          return SectionCard(
            title: 'Billing methods',
            icon: Icons.payments_outlined,
            children: [
              Text(
                _account.errorMessage.isEmpty
                    ? 'These settings are unread without a session.'
                    : _account.errorMessage,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Align(
                alignment: Alignment.centerRight,
                child: PillButton(
                  text: 'Retry',
                  onPressed: () => _account.loadMethods(force: true),
                ),
              ),
            ],
          );
        }
        final method = _account.billingMethod;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Billing methods',
              icon: Icons.payments_outlined,
              children: [
                if (method == null)
                  Text(
                    SettingsData.billingNote,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                  )
                else
                  _savedRow(method),
                const SizedBox(height: AppDimensions.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PillButton(
                    text: method == null
                        ? 'Add a billing method'
                        : 'Replace the billing method',
                    icon: Icons.add,
                    onPressed: () => setState(() => _adding = true),
                  ),
                ),
              ],
            ),
            if (_adding) ...[
              const SizedBox(height: AppDimensions.md),
              SectionCard(
                title: 'Add billing methods',
                trailing: PillButton(text: 'Cancel', onPressed: _cancel),
                children: [
                  for (
                    var index = 0;
                    index < SettingsData.billingMethods.length;
                    index++
                  )
                    _radioRow(SettingsData.billingMethods[index], index),
                  if (_isCard) ...[
                    const SizedBox(height: AppDimensions.sm),
                    _brandChips(),
                    _form('Card number', formatter: _CardNumberFormatter()),
                    const SizedBox(height: AppDimensions.sm),
                    _pair('First Name', 'Last Name'),
                    _pair(
                      'Expiration month',
                      'Expiration year',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                    ),
                    _form(
                      'Security code',
                      formatter: FilteringTextInputFormatter.digitsOnly,
                    ),
                  ] else ...[
                    const SizedBox(height: AppDimensions.sm),
                    _form('Account name'),
                    const SizedBox(height: AppDimensions.sm),
                    _form(
                      '${SettingsData.billingMethods[_method]} account number',
                    ),
                  ],
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    method == null
                        ? 'Only the last digits of a card are kept, and no '
                              'security code is kept at all.'
                        : 'Saving this replaces the '
                              '${method.label.toLowerCase()} you have on file.',
                    style: AppTextStyles.caption.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  SaveChangesButton(
                    text: _account.isSaving ? 'Saving…' : 'Save',
                    onPressed: _account.isSaving ? () {} : _save,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Selectable card brand mark.
class _BrandChip extends StatelessWidget {
  final ({String label, String asset}) brand;
  final bool selected;
  final VoidCallback onTap;

  const _BrandChip({
    required this.brand,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: brand.label,
      child: Material(
        color: selected ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: AppDimensions.xs + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radius),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  brand.asset,
                  height: 20,
                  semanticLabel: brand.label,
                ),
                if (selected) ...[
                  const SizedBox(width: AppDimensions.xs),
                  const Icon(
                    Icons.check_circle,
                    size: AppDimensions.iconSm,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Groups card digits in fours so the field reads like a real card entry.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{4})(?=\d)'),
      (match) => '${match.group(1)} ',
    );
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
