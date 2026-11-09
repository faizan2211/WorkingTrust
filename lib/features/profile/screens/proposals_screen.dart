import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/proposals_controller.dart';
import '../../finance/models/my_proposals.dart';
import '../../finance/widgets/read_view.dart';

/// Active, Referrals and Archived proposals, read from `GET /api/bids/my`.
///
/// The tabs are the backend panel's own split of one read: the assignments
/// still open, the bids still `PENDING` and the bids `REJECTED`. `counts` comes
/// back whole with every answer, so each header carries the account's real
/// total while a list shows only as far as the pages read — and says so when
/// the two differ. The screen reads once when it opens and again when it is
/// pulled, never on a timer, and a read that fails is shown as an error with a
/// retry rather than as rows the app cannot confirm.
class ProposalsScreen extends StatefulWidget {
  const ProposalsScreen({super.key});

  @override
  State<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends State<ProposalsScreen> {
  /// The bids route takes no date parameter, so the archived window filters the
  /// proposals already read instead of asking the server for a smaller set.
  static const List<String> _ranges = [
    'Last 7 Days',
    'Last 15 Days',
    'Last 30 Days',
  ];

  String _archivedRange = _ranges.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ProposalsController.instance.load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProposalsController.instance,
      builder: (context, _) {
        final controller = ProposalsController.instance;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: const ModuleAppBar(
              title: 'My proposals',
              subtitle: 'Sent proposals and their status',
              bottom: TabBar(
                labelColor: ModuleAppBar.tabBarLabel,
                unselectedLabelColor: ModuleAppBar.tabBarUnselected,
                indicatorColor: ModuleAppBar.tabBarIndicator,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Active'),
                  Tab(text: 'Referrals'),
                  Tab(text: 'Archived'),
                ],
              ),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bodyWidth = constraints.maxWidth > 1100
                      ? 1100.0
                      : constraints.maxWidth;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: bodyWidth),
                      child: TabBarView(
                        children: [
                          _tab(controller, _activePanels(controller)),
                          // The backend holds no referral data at all, so the
                          // panel keeps its nothing-yet state rather than
                          // relabelling a bid status as a referral.
                          _ListPage(
                            onRefresh: controller.refresh,
                            panels: const [_CountPanel(title: 'Referrals')],
                          ),
                          _tab(controller, [_archivedPanel(controller)]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// One shared read, one page per tab. An account that has sent nothing still
  /// gets its panels, which say so themselves.
  Widget _tab(ProposalsController controller, List<Widget> panels) {
    return ReadView(
      state: controller.state,
      error: controller.error,
      onRetry: () => controller.load(force: true),
      empty: _ListPage(onRefresh: controller.refresh, panels: panels),
      builder: (context) =>
          _ListPage(onRefresh: controller.refresh, panels: panels),
    );
  }

  List<Widget> _activePanels(ProposalsController controller) {
    final submitted = _withStatus(controller, BidStatus.pending);
    final pendingCount = controller.counts.pending;

    return [
      _CountPanel(
        title: 'Active Proposals',
        // `activeWork` always arrives whole, so here the rows are the count.
        count: controller.activeWork.length,
        rows: [for (final row in controller.activeWork) _ActiveRow(row: row)],
      ),
      _CountPanel(
        title: 'Submitted Proposals',
        count: pendingCount,
        rows: [for (final row in submitted) _SubmittedRow(row: row)],
        emptyMessage: pendingCount == 0
            ? 'Nothing here yet.'
            : 'No pending proposal among the '
                  '${controller.proposals.length} proposals read.',
        note: submitted.length < pendingCount
            ? 'Showing ${submitted.length} of the $pendingCount pending '
                  'proposals the server counts.'
            : null,
        footer: _pagination(controller),
      ),
    ];
  }

  Widget _archivedPanel(ProposalsController controller) {
    final rejected = _withStatus(controller, BidStatus.rejected);
    final shown = [
      for (final row in rejected)
        if (_inRange(row)) row,
    ];
    final footer = _pagination(controller);
    final rejectedCount = controller.counts.rejected;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Archived proposals ($rejectedCount)',
            dropdown: AppDropdown(
              value: _archivedRange,
              items: _ranges,
              onChanged: (value) => setState(() => _archivedRange = value),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          if (shown.isEmpty)
            _NothingHere(
              message: rejectedCount == 0
                  ? 'Nothing here yet.'
                  : 'No $_archivedRange rejected proposal among the '
                        '${controller.proposals.length} proposals read.',
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              _ArchivedRow(proposal: shown[i]),
              if (i < shown.length - 1)
                const Divider(color: AppColors.divider, height: 1),
            ],
          if (shown.isNotEmpty && shown.length != rejectedCount) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              '$_archivedRange narrows the proposals loaded, not the '
              '$rejectedCount the server counts as rejected.',
              style: AppTextStyles.bodySmall,
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppDimensions.md),
            footer,
          ],
        ],
      ),
    );
  }

  /// The tab split stays local: filtering on the server would drop the other
  /// tabs' rows out of the same answer, so the read is kept on `all`.
  List<ProposalRow> _withStatus(
    ProposalsController controller,
    BidStatus status,
  ) => [
    for (final row in controller.proposals)
      if (row.status.toUpperCase() == status.query) row,
  ];

  int get _rangeDays => switch (_archivedRange) {
    'Last 7 Days' => 7,
    'Last 15 Days' => 15,
    _ => 30,
  };

  /// A bid the server never dated cannot be proved outside the window, so it
  /// stays listed rather than vanishing from a tab the count still credits.
  bool _inRange(ProposalRow row) {
    final at = row.at;
    if (at == null) return true;
    return at.isAfter(DateTime.now().subtract(Duration(days: _rangeDays)));
  }

  /// How far the paged read has come, and the only way past the page open.
  Widget? _pagination(ProposalsController controller) {
    if (controller.total == 0) return null;
    if (!controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: AppDimensions.sm),
        child: Text(
          'All ${controller.total} proposals loaded.',
          style: AppTextStyles.bodySmall,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing ${controller.proposals.length} of ${controller.total}.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.sm),
          AppButton(
            text: 'Load more',
            isOutlined: true,
            isLoading: controller.isLoadingMore,
            onPressed: controller.isBusy ? null : controller.loadMore,
          ),
        ],
      ),
    );
  }
}

/// One tab page: a single pull-to-refresh over the panels it holds.
class _ListPage extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> panels;

  const _ListPage({required this.onRefresh, required this.panels});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final panel in panels) ...[
              panel,
              const SizedBox(height: AppDimensions.md),
            ],
          ],
        ),
      ),
    );
  }
}

/// A panel: the server's number in the header, the rows read underneath, and
/// the nothing-yet state when the account has none.
class _CountPanel extends StatelessWidget {
  final String title;
  final int? count;
  final List<Widget> rows;
  final String emptyMessage;
  final String? note;
  final Widget? footer;

  const _CountPanel({
    required this.title,
    this.count,
    this.rows = const [],
    this.emptyMessage = 'Nothing here yet.',
    this.note,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == null ? title : '$title ($count)',
            style: AppTextStyles.heading4,
          ),
          const SizedBox(height: AppDimensions.lg),
          if (rows.isEmpty)
            _NothingHere(message: emptyMessage)
          else
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                const Divider(color: AppColors.divider, height: 1),
            ],
          if (note != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(note!, style: AppTextStyles.bodySmall),
          ],
          ?footer,
          const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }
}

class _NothingHere extends StatelessWidget {
  final String message;

  const _NothingHere({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: AppDimensions.iconLg,
            color: AppColors.textHint,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(message, style: AppTextStyles.bodySmall),
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
        if (constraints.maxWidth < dropdownWidth + 160) {
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

/// An assignment the client has given out: where the work stands and what it
/// pays, both in the server's own words.
class _ActiveRow extends StatelessWidget {
  final ActiveWorkRow row;

  const _ActiveRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title.isEmpty ? 'Assignment' : row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                if (row.subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    row.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.xs,
                  children: [
                    if (row.statusLabel.isNotEmpty)
                      AppTag(row.statusLabel, highlight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              row.payoutLabel,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bid still waiting on the client, with what the project pays if it lands.
class _SubmittedRow extends StatelessWidget {
  final ProposalRow row;

  const _SubmittedRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (row.subtitle.isNotEmpty) row.subtitle,
      'Sent ${row.sentLabel}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title.isEmpty ? 'Proposal' : row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              row.earningLabel,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bid the client closed: its stored status and the category it was sent
/// under, with no wording the app invented for why it was turned down.
class _ArchivedRow extends StatelessWidget {
  final ProposalRow proposal;

  const _ArchivedRow({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal.title.isEmpty ? 'Proposal' : proposal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(proposal.sentLabel, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.xs,
            children: [
              AppTag(proposal.statusLabel, highlight: true),
              if (proposal.category.isNotEmpty) AppTag(proposal.category),
            ],
          ),
        ],
      ),
    );
  }
}
