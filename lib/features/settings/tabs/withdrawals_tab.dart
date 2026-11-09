import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../finance/controller/overview_controller.dart';
import '../../finance/controller/read_state.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/controller/withdrawals_controller.dart';
import '../../finance/models/transaction_feed.dart';
import '../../finance/models/wallet_data.dart';
import '../controller/account_controller.dart';
import '../data/settings_data.dart';
import '../models/account_settings.dart';
import '../widgets/settings_primitives.dart';

/// Saved withdrawal accounts, the balance a payout draws on and the requests
/// that moved money out of it.
///
/// Three routes stand behind this tab. `GET`, `POST` and `DELETE
/// /api/account/withdrawals` own the list of up to five saved accounts, and the
/// answer carries the whole list every time, so the card follows it.
/// `GET /api/reports/overview` reports what the account can be paid and what is
/// already waiting on review, and `GET /api/reports/transactions` asked for its
/// `Withdrawal` type alone is the history. Nothing here is added up on the
/// device: a balance the server has not answered shows as a dash, and a request
/// names approved jobs by id so the route can price them itself.
class WithdrawalsTab extends StatefulWidget {
  const WithdrawalsTab({super.key});

  @override
  State<WithdrawalsTab> createState() => _WithdrawalsTabState();
}

class _WithdrawalsTabState extends State<WithdrawalsTab> {
  static const List<String> _schedules = [
    'Weekly (every Monday)',
    'Bi-weekly',
    'Monthly',
    'Manual',
  ];

  final AccountController _account = AccountController.instance;
  final OverviewController _overview = OverviewController.instance;
  final WalletController _wallet = WalletController.instance;
  final WithdrawalsController _withdrawals = WithdrawalsController.instance;

  String _schedule = _schedules.first;

  @override
  void initState() {
    super.initState();
    _account.loadMethods();
    _overview.load();
    _withdrawals.load();
    // The jobs a payout can be requested for are the wallet's own approved
    // rows, so the request sheet has something real to list.
    _wallet.load();
  }

  void _note(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _reportFailure(String fallback) =>
      _note(_account.errorMessage.isEmpty ? fallback : _account.errorMessage);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  Future<void> _addMethod() async {
    if (_account.isSaving) return;
    if (_account.withdrawals.length >= withdrawalMethodLimit) {
      _note('You can save up to $withdrawalMethodLimit withdrawal methods.');
      return;
    }
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (_) => _AddWithdrawalSheet(
        onAdd: (method, details, label) => _account.saveWithdrawal(
          method: method,
          accountDetails: details,
          label: label,
        ),
      ),
    );
    if (saved == true) _note('Withdrawal account saved.');
  }

  Future<void> _remove(SavedWithdrawalMethod row) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove this account?', style: AppTextStyles.heading4),
        content: Text(
          '${row.label} · ${row.accountDetails} will be taken off your saved '
          'accounts.',
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
    final removed = await _account.removeWithdrawal(row.id);
    if (!removed) _reportFailure('The account could not be removed.');
  }

  /// The jobs a payout can be asked for: the wallet's approved rows that have
  /// no request against them yet. Their amounts are the server's own.
  List<WalletEarning> get _payable =>
      _wallet.value.earnings.where((job) => !job.withdrawalRequested).toList();

  /// The route's cap on one request.
  static const int _requestMax = WithdrawalsController.requestMax;

  Future<void> _withdrawNow() async {
    final payable = _payable;
    if (payable.isEmpty) {
      _note('No approved job is waiting to be paid out.');
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (sheetContext) =>
          _PickWorkSheet(jobs: payable, max: _requestMax, money: _money),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final count = await _withdrawals.submit(chosen);
    if (!mounted) return;
    if (count == null) {
      _note(
        _withdrawals.writeError.isEmpty
            ? 'The withdrawal could not be requested.'
            : _withdrawals.writeError,
      );
      return;
    }
    _note('Withdrawal requested for $count job${count == 1 ? '' : 's'}.');
  }

  /// The accounts list, its own loading and error state so the balance card
  /// above it does not go blank while the two reads are in flight.
  Widget _accountsCard(List<SavedWithdrawalMethod> methods) {
    Widget body;
    if (_account.isLoading && !_account.hasLoadedMethods) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!_account.hasLoadedMethods) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _account.errorMessage.isEmpty
                ? 'These accounts are unread without a session.'
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
    } else if (methods.isEmpty) {
      body = Text(
        SettingsData.withdrawals.methodsNote,
        style: AppTextStyles.bodySmall.copyWith(height: 1.6),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in methods)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: AppDimensions.iconSm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.label, style: AppTextStyles.bodyMedium),
                        Text(
                          row.accountDetails,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GhostIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Remove ${row.label}',
                    onPressed: () => _remove(row),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return SectionCard(
      title: 'Withdrawal methods',
      icon: Icons.credit_card_outlined,
      trailing: PillButton(
        text: 'Add a Method',
        icon: Icons.add,
        onPressed: _account.hasLoadedMethods ? _addMethod : () {},
      ),
      children: [body],
    );
  }

  /// A figure the route has not answered is a dash, never a number the tab
  /// guessed at.
  String _moneyOrDash(double? value) => value == null ? '—' : _money(value);

  Widget _history() {
    if (_withdrawals.isBusy && !_withdrawals.hasValue) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_withdrawals.state == ReadState.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _withdrawals.error,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Align(
            alignment: Alignment.centerRight,
            child: PillButton(
              text: 'Retry',
              onPressed: () => _withdrawals.refresh(),
            ),
          ),
        ],
      );
    }
    final rows = _withdrawals.value;
    if (rows.isEmpty) {
      return Text(
        'No withdrawal has been requested on this account yet.',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
            child: _WithdrawalRow(entry: entry),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_account, _overview, _withdrawals]),
      builder: (context, child) {
        final methods = _account.withdrawals;
        final figures = _overview.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const IconBadge(Icons.attach_money),
                      Flexible(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            RouteNames.transactions,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.sm,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.open_in_new,
                            size: AppDimensions.iconSm,
                          ),
                          label: const Text(
                            'View my earning',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  const Text(
                    'Available balance',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    _moneyOrDash(figures.availableBalance),
                    style: AppTextStyles.heading2.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_overview.state == ReadState.failed)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _overview.error,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        PillButton(
                          text: 'Retry',
                          onPressed: () => _overview.refresh(),
                        ),
                      ],
                    )
                  else
                    Text(
                      figures.pendingWithdrawalsAmount == null
                          ? 'No pending total has been reported.'
                          : '+${_moneyOrDash(figures.pendingWithdrawalsAmount)} '
                                'pending',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  const SizedBox(height: AppDimensions.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PillButton(
                      text: 'Withdrawal now',
                      onPressed: _withdrawNow,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SectionCard(
              title: 'Withdrawal schedule',
              icon: Icons.schedule_outlined,
              children: [
                Text(
                  methods.isEmpty
                      ? SettingsData.withdrawals.scheduleNote
                      : 'Payouts follow the schedule below once they clear '
                            'review.',
                  style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                ),
                if (methods.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.md),
                  AppDropdown(
                    value: _schedule,
                    items: _schedules,
                    icon: null,
                    onChanged: (choice) => setState(() => _schedule = choice),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            _accountsCard(methods),
            const SizedBox(height: AppDimensions.lg),
            Text('Recent withdrawals', style: AppTextStyles.heading4),
            const SizedBox(height: AppDimensions.md),
            _history(),
          ],
        );
      },
    );
  }
}

/// The form behind "Add a Method": one of the three method types the route
/// accepts, the account it writes to, and a label the route names for the type
/// when this is left empty.
class _AddWithdrawalSheet extends StatefulWidget {
  const _AddWithdrawalSheet({required this.onAdd});

  final Future<bool> Function(String method, String details, String label)
  onAdd;

  @override
  State<_AddWithdrawalSheet> createState() => _AddWithdrawalSheetState();
}

class _AddWithdrawalSheetState extends State<_AddWithdrawalSheet> {
  final AccountController _account = AccountController.instance;
  final TextEditingController _details = TextEditingController();
  final TextEditingController _label = TextEditingController();

  String _method = withdrawalMethodTypes.keys.first;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _details.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _details.text.trim();
    if (details.length < 5) {
      setState(() => _error = 'Enter the account details first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final saved = await widget.onAdd(_method, details, _label.text.trim());
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    // The route gives its own reason, including the five-account cap.
    setState(() {
      _busy = false;
      _error = _account.errorMessage.isEmpty
          ? 'The account could not be saved.'
          : _account.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = withdrawalMethodTypes.entries.toList();
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.md,
        right: AppDimensions.md,
        top: AppDimensions.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Withdrawal method', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Up to $withdrawalMethodLimit accounts can be saved. A saved '
            'account is a listing only — a payout still follows the billing '
            'method on the account.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          for (int index = 0; index < entries.length; index++)
            _MethodRow(
              label: entries[index].value,
              selected: _method == entries[index].key,
              onTap: () => setState(() => _method = entries[index].key),
            ),
          const SizedBox(height: AppDimensions.sm),
          AppTextField(
            label: 'Account details',
            hint: 'Mobile number or account number',
            controller: _details,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.md),
          AppTextField(
            label: 'Label (optional)',
            hint: 'How you want this account listed',
            controller: _label,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              _error,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          SaveChangesButton(
            text: _busy ? 'Saving…' : 'Save',
            onPressed: _busy ? () {} : _submit,
          ),
        ],
      ),
    );
  }
}

/// One method choice inside the add sheet.
class _MethodRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        onTap: onTap,
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
}

/// One payout row, in the words the Transactions feed gives it: the day, what
/// it was for, the amount the server priced it at and the status it reports.
class _WithdrawalRow extends StatelessWidget {
  final TransactionRow entry;

  const _WithdrawalRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.dateLabel, style: AppTextStyles.labelMedium),
                Text(
                  entry.details.isEmpty ? 'Withdrawal' : entry.details,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.amountLabel,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              AppTag(
                status ?? 'Requested',
                highlight: status?.toUpperCase() == 'PAID',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The jobs a payout can be asked for, straight off the wallet's approved rows.
/// A device chooses which of them to name; the route decides what each is worth.
class _PickWorkSheet extends StatefulWidget {
  final List<WalletEarning> jobs;
  final int max;
  final String Function(double) money;

  const _PickWorkSheet({
    required this.jobs,
    required this.max,
    required this.money,
  });

  @override
  State<_PickWorkSheet> createState() => _PickWorkSheetState();
}

class _PickWorkSheetState extends State<_PickWorkSheet> {
  final WithdrawalsController _withdrawals = WithdrawalsController.instance;
  final Set<String> _chosen = {};

  void _toggle(WalletEarning job) {
    setState(() {
      if (_chosen.contains(job.id)) {
        _chosen.remove(job.id);
      } else if (_chosen.length < widget.max) {
        _chosen.add(job.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _withdrawals.isSubmitting;
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.md,
        right: AppDimensions.md,
        top: AppDimensions.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimensions.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Withdraw funds', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Choose the approved work you want paid out. Each job is priced '
            'from its own row by the server, which also moves the balance and '
            'records the request — up to ${widget.max} jobs at a time.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final job in widget.jobs)
                    _WorkPick(
                      job: job,
                      selected: _chosen.contains(job.id),
                      money: widget.money,
                      onTap: () => _toggle(job),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          AppButton(
            text: busy
                ? 'Requesting…'
                : 'Request Withdrawal (${_chosen.length})',
            borderRadius: AppDimensions.radiusXl,
            onPressed: _chosen.isEmpty || busy
                ? null
                : () => Navigator.pop(context, _chosen.toList()),
          ),
        ],
      ),
    );
  }
}

/// One payable job: the work, the client and the amount on its own row.
class _WorkPick extends StatelessWidget {
  final WalletEarning job;
  final bool selected;
  final String Function(double) money;
  final VoidCallback onTap;

  const _WorkPick({
    required this.job,
    required this.selected,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amount = job.amount;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.sm,
            horizontal: AppDimensions.xs,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: AppDimensions.iconSm + 4,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.taskTitle.isEmpty ? 'Approved work' : job.taskTitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (job.clientName.isNotEmpty)
                      Text(
                        job.clientName,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                amount == null ? '—' : money(amount),
                style: AppTextStyles.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
