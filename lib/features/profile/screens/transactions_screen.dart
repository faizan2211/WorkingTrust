import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/transactions_controller.dart';
import '../../finance/controller/weekly_controller.dart';
import '../../finance/models/json_read.dart';
import '../../finance/models/transaction_feed.dart';
import '../../finance/models/weekly_report.dart';
import '../../finance/widgets/read_view.dart';
import '../../settings/data/settings_data.dart';

/// Balance, withdrawal options and the transaction history read from
/// `GET /api/reports/transactions`.
///
/// The route owns the feed, and only two of this screen's filters reach it:
/// `type` and `client` are query parameters, and changing either re-reads page
/// one for the whole account. The date window is a pair of calendars over the
/// rows already on the device — the route takes no dates — and the screen says
/// so. One read when the screen opens and one when it is pulled, never a timer.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  /// Settings opens straight onto the tab that holds a payout method.
  static int get withdrawalsTab => SettingsData.tabs.indexOf('Withdrawals');

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  /// An action menu rather than a choice that stays selected: nothing is
  /// queued and no file is kept, so there is no selection worth remembering.
  static const List<String> _downloads = [
    'Select Download',
    'Weekly summary',
    'Monthly statement',
    'All transactions',
  ];

  static const List<String> _quickFilters = [
    'Earning',
    'Withdrawals',
    'Last year',
    'This year',
  ];

  /// The tags that narrow a category. What the site calls an earning is the
  /// server's `Client` row.
  static const Map<String, String> _tagType = {
    'Earning': 'Client',
    'Withdrawals': 'Withdrawal',
  };

  /// The year tags, as an offset from this one. They set the very window the
  /// two calendars would, so the tags and the fields can never disagree.
  static const Map<String, int> _tagYear = {'Last year': -1, 'This year': 0};

  DateTime? _from;
  DateTime? _to;
  String? _kindTag;
  bool _downloadInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TransactionsController.instance.load(),
    );
  }

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openWithdrawals(BuildContext context) => Navigator.pushNamed(
    context,
    RouteNames.settings,
    arguments: TransactionsScreen.withdrawalsTab,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModuleAppBar(
        title: 'Transactions',
        subtitle: 'Balance, withdrawals & history',
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TransactionsController.instance,
          builder: (context, _) => _read(TransactionsController.instance),
        ),
      ),
    );
  }

  Widget _read(TransactionsController controller) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final bodyWidth = width > 760 ? 760.0 : width;
          final content = _content(
            controller,
            sideBySide: width >= 480,
            filterColumns: width >= 620 ? 4 : 2,
            fieldArea: bodyWidth - AppDimensions.md * 2,
          );

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
                  // A filtered query comes back empty too, so the balances and
                  // the filters have to survive the blank state or the account
                  // is stranded on the filter that produced it.
                  empty: content,
                  builder: (context) => content,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(
    TransactionsController controller, {
    required bool sideBySide,
    required int filterColumns,
    required double fieldArea,
  }) {
    final loaded = controller.rows;
    final shown = _narrow(loaded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _balanceRow(controller, sideBySide),
        const SizedBox(height: AppDimensions.md),
        _ScheduleCard(
          hasPaymentMethod: controller.hasPaymentMethod,
          onMethod: () => _openWithdrawals(context),
        ),
        const SizedBox(height: AppDimensions.lg),
        _filterGrid(controller, filterColumns, fieldArea),
        const SizedBox(height: AppDimensions.md),
        _quickFilterRow(),
        const SizedBox(height: AppDimensions.xs + 2),
        Text(
          'The two dates and Quick Filters only narrow the ${loaded.length} '
          'rows this device has read — they do not change the '
          '${controller.total} the server holds for the filters above them.',
          style: AppTextStyles.caption.copyWith(height: 1.5),
        ),
        const SizedBox(height: AppDimensions.md),
        if (shown.isEmpty)
          AppEmptyState(message: _blankMessage(controller, loaded))
        else
          for (final row in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: _TransactionRow(row: row),
            ),
        if (loaded.isNotEmpty) _pagination(controller),
        const SizedBox(height: AppDimensions.sm),
      ],
    );
  }

  /// An empty list means two different things depending on who filtered it,
  /// and only one of those is an account with no history at all.
  String _blankMessage(
    TransactionsController controller,
    List<TransactionRow> loaded,
  ) {
    if (loaded.isNotEmpty) return 'No transactions in this range.';
    final filtered =
        controller.type != TransactionFilter.all || controller.client != 'all';
    if (filtered) {
      return 'The server found nothing for these filters. '
          'Try All Types or All Clients.';
    }
    return 'No transactions on this account yet.';
  }

  List<TransactionRow> _narrow(List<TransactionRow> rows) {
    final tag = _kindTag;
    final type = tag == null ? null : _tagType[tag];
    return [
      for (final row in rows)
        if ((type == null || row.type == type) && _inRange(row.at)) row,
    ];
  }

  bool _inRange(DateTime? at) {
    // A row the server did not date cannot be placed in a window.
    final from = _from;
    final to = _to;
    if (from == null && to == null) return true;
    if (at == null) return false;
    final when = at.toLocal();
    if (from != null && when.isBefore(from)) return false;
    if (to == null) return true;
    // The last day counts whole, the way a stated end date is meant to read.
    final lastDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return !when.isAfter(lastDay);
  }

  /// The calendar for one end of the window. Each picker is bounded by the
  /// other end, so the two can never cross.
  Future<void> _pickDate({required bool ending}) async {
    final now = DateTime.now();
    final floor = DateTime(now.year - 30);
    final ceiling = DateTime(now.year + 1, 12, 31);
    final firstDate = ending ? (_from ?? floor) : floor;
    final lastDate = ending ? ceiling : (_to ?? ceiling);
    final current = ending ? _to : _from;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clamp(current ?? now, firstDate, lastDate),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: ending ? 'Last day of the window' : 'First day of the window',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (ending) {
        _to = picked;
      } else {
        _from = picked;
      }
    });
  }

  static DateTime _clamp(DateTime date, DateTime first, DateTime last) {
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  Widget _pagination(TransactionsController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing ${controller.rows.length} of ${controller.total}.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.sm),
          if (controller.hasMore)
            AppButton(
              text: 'Load more',
              isOutlined: true,
              isLoading: controller.isLoadingMore,
              onPressed: controller.loadMore,
            )
          else
            Text(
              'All ${controller.total} transactions loaded.',
              style: AppTextStyles.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _balanceRow(TransactionsController controller, bool sideBySide) {
    final cards = [
      _ValueCard(
        icon: Icons.payments_outlined,
        value: _money(controller.availableBalance),
        label: 'Available balance',
      ),
      _ValueCard(
        icon: Icons.schedule,
        value: _money(controller.pendingEarnings),
        label: 'Pending earnings',
        link: 'Withdrawal now',
        onLink: () => _openWithdrawals(context),
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
          Expanded(child: cards.first),
          const SizedBox(width: AppDimensions.sm),
          Expanded(child: cards.last),
        ],
      ),
    );
  }

  Widget _filterGrid(
    TransactionsController controller,
    int columns,
    double available,
  ) {
    final gap = AppDimensions.sm;
    final fieldWidth = (available - gap * (columns - 1)) / columns;
    // Both of these are a server request, so they wait for the answer instead
    // of queueing a second one behind it.
    final busy = controller.isBusy;

    final fields = [
      _labelled(
        'From date',
        _DateField(
          value: _from,
          onTap: () => _pickDate(ending: false),
          onClear: _from == null ? null : () => setState(() => _from = null),
        ),
      ),
      _labelled(
        'To date',
        _DateField(
          value: _to,
          onTap: () => _pickDate(ending: true),
          onClear: _to == null ? null : () => setState(() => _to = null),
        ),
      ),
      _labelled(
        'Transaction type',
        AppDropdown(
          value: controller.type.label,
          items: TransactionFilter.labels,
          onChanged: busy
              ? null
              : (value) =>
                    controller.setType(TransactionFilter.fromLabel(value)),
          icon: null,
          filled: true,
        ),
      ),
      _labelled(
        'Client',
        AppDropdown(
          value: _clientValue(controller),
          items: controller.clientOptions,
          onChanged: busy ? null : controller.setClient,
          icon: null,
          filled: true,
        ),
      ),
      _labelled(
        'Select Download',
        AppDropdown(
          value: _downloads.first,
          items: _downloads,
          onChanged: _onDownload,
          icon: null,
          filled: true,
        ),
      ),
    ];

    return Wrap(
      spacing: gap,
      runSpacing: AppDimensions.md,
      children: [
        for (final field in fields) SizedBox(width: fieldWidth, child: field),
      ],
    );
  }

  /// A dropdown can only show one of its own items, and the server's client
  /// list can shrink with the type filter, so the neutral entry answers for a
  /// name that is no longer offered.
  String _clientValue(TransactionsController controller) {
    final options = controller.clientOptions;
    return options.contains(controller.client)
        ? controller.client
        : options.first;
  }

  Future<void> _onDownload(String value) async {
    if (value == _downloads.first || _downloadInFlight) return;
    if (value != 'Weekly summary') {
      _note('The server has no file endpoint for $value.');
      return;
    }

    _downloadInFlight = true;
    final text = await WeeklyController.instance.download(WeeklyScope.summary);
    _downloadInFlight = false;
    if (!mounted) return;

    final body = text?.trim();
    if (body == null || body.isEmpty) {
      final error = WeeklyController.instance.downloadError;
      _note(error.isEmpty ? 'The server sent no weekly summary.' : error);
      return;
    }
    await _showText(value, body);
  }

  /// The website's own text file, shown as the server wrote it rather than
  /// claimed as a download this device cannot hand back.
  Future<void> _showText(String title, String text) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final available = MediaQuery.sizeOf(context).width - AppDimensions.lg;
        return AlertDialog(
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge,
          ),
          content: SizedBox(
            width: available > 420 ? 420.0 : available,
            child: SingleChildScrollView(
              child: SelectableText(text, style: AppTextStyles.bodySmall),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _labelled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.xs + 2),
        SizedBox(width: double.infinity, child: field),
      ],
    );
  }

  Widget _quickFilterRow() {
    return Row(
      children: [
        Text('Quick Filters:', style: AppTextStyles.labelLarge),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _quickFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: AppDimensions.sm),
                    child: AppTag(
                      filter,
                      selected: _isQuickSelected(filter),
                      onTap: () => _tapQuick(filter),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isQuickSelected(String filter) {
    if (_tagType.containsKey(filter)) return _kindTag == filter;
    final year = _yearOf(filter);
    if (year == null) return false;
    final from = _from;
    final to = _to;
    return from != null &&
        to != null &&
        from.year == year &&
        to.year == year &&
        from.month == 1 &&
        from.day == 1 &&
        to.month == 12 &&
        to.day == 31;
  }

  void _tapQuick(String filter) {
    setState(() {
      if (_tagType.containsKey(filter)) {
        _kindTag = _kindTag == filter ? null : filter;
        return;
      }
      final year = _yearOf(filter);
      if (year == null) return;
      if (_isQuickSelected(filter)) {
        _from = null;
        _to = null;
      } else {
        _from = DateTime(year, 1, 1);
        _to = DateTime(year, 12, 31);
      }
    });
  }

  /// The tag's calendar year, or null for a tag that is not a year.
  int? _yearOf(String filter) {
    final offset = _tagYear[filter];
    return offset == null ? null : DateTime.now().year + offset;
  }
}

/// One end of the date window, picked on the same calendar the rest of the app
/// uses. The field only ever holds a day the server's own rows can fall on.
class _DateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({required this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radius),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radius),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: AppDimensions.iconSm,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                value == null ? 'Any date' : shortDate(value!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium,
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  size: AppDimensions.iconSm,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Clear this date',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? link;
  final VoidCallback? onLink;

  const _ValueCard({
    required this.icon,
    required this.value,
    required this.label,
    this.link,
    this.onLink,
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
              IconBadge(icon),
              if (link != null) ...[
                const Spacer(),
                _ArrowLink(text: link!, onPressed: onLink),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.md),
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
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final bool hasPaymentMethod;
  final VoidCallback onMethod;

  const _ScheduleCard({required this.hasPaymentMethod, required this.onMethod});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(Icons.account_balance_wallet_outlined),
              const Spacer(),
              _ArrowLink(
                text: hasPaymentMethod ? 'Change method' : 'Add a method',
                onPressed: onMethod,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Text('Withdrawal schedule', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.xs),
          // The route reports only whether a method exists and publishes no
          // schedule, so neither half of this line may promise one.
          Text(
            hasPaymentMethod
                ? 'A payout method is already on file for this account. A '
                      'withdrawal is requested from Settings → Withdrawals.'
                : "You will be able to set up a withdrawal schedule once "
                      "you've added a withdrawal method.",
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ArrowLink extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _ArrowLink({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed ?? () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.xs),
          const Icon(Icons.arrow_outward, size: 14, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final TransactionRow row;

  const _TransactionRow({required this.row});

  static String _word(String value) => value.trim().isEmpty ? '—' : value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.dateLabel, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  _word(row.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                Text(
                  _word(row.details),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
                if (row.client != null)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.client!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (row.status != null) ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppTag(row.status!, highlight: true),
                ),
                const SizedBox(height: AppDimensions.xs),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  row.amountLabel,
                  style: AppTextStyles.heading4.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              _RowActions(type: _word(row.type)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The feed sends the row's own text and nothing else — no invoice, no
/// attachment — so these two buttons name what is missing instead of
/// promising a file that cannot arrive.
class _RowActions extends StatelessWidget {
  final String type;

  const _RowActions({required this.type});

  void _note(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  IconButton _button(
    BuildContext context,
    String tooltip,
    IconData icon,
    String message,
  ) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => _note(context, message),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.all(AppDimensions.sm),
        minimumSize: const Size(34, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          context,
          'Preview',
          Icons.visibility_outlined,
          'The server stores no document behind this $type entry, '
              'so there is nothing to preview.',
        ),
        const SizedBox(width: AppDimensions.sm),
        _button(
          context,
          'Download',
          Icons.download_outlined,
          'There is no file to download for this $type entry — '
              'the feed sends its text only.',
        ),
      ],
    );
  }
}

/// A figure the route did not send stays a dash rather than reading as zero.
String _money(double? value) => value == null ? '—' : usd(value);
