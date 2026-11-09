import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../finance/models/wallet_data.dart';
import '../../profile/widgets/buy_bids_sheet.dart';
import '../controller/find_work_controller.dart';
import '../models/project_model.dart';
import '../widgets/project_card.dart';

class FindWorkScreen extends StatefulWidget {
  const FindWorkScreen({super.key});

  @override
  State<FindWorkScreen> createState() => _FindWorkScreenState();
}

class _FindWorkScreenState extends State<FindWorkScreen>
    with WidgetsBindingObserver {
  final FindWorkController _controller = FindWorkController.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The board is read when the tab is opened and when the app comes back to
    // the foreground — never on a timer.
    _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  /// A project posted while the app was away shows up on the way back in.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.refresh();
  }

  void _openFilters() {
    // The category list is only needed by this sheet, so it is read here
    // rather than with the board.
    _controller.loadCategories();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      // The sheet holds the whole category list plus the switches, which on a
      // phone is taller than the default half-screen sheet, so it is allowed to
      // grow and scrolls instead of overflowing.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters', style: AppTextStyles.heading3),
                  const SizedBox(height: AppDimensions.lg),
                  Text('Category', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppDimensions.sm),
                  if (_controller.loadingCategories)
                    const Padding(
                      padding: EdgeInsets.all(AppDimensions.sm),
                      child: AppLoader(size: 22),
                    )
                  else if (_controller.categories.isEmpty)
                    Text(
                      'The server returned no categories.',
                      style: AppTextStyles.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: AppDimensions.sm,
                      runSpacing: AppDimensions.sm,
                      children: [
                        AppTag(
                          'All categories',
                          selected: _controller.categorySlug.isEmpty,
                          onTap: () => _controller.setCategory(''),
                        ),
                        for (final category in _controller.categories)
                          AppTag(
                            category.name,
                            selected: _controller.categorySlug == category.slug,
                            onTap: () => _controller.setCategory(category.slug),
                          ),
                      ],
                    ),
                  const SizedBox(height: AppDimensions.md),
                  Text('Experience level', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppDimensions.sm),
                  Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: [
                      for (final level in FindWorkController.levelOptions)
                        AppTag(
                          level,
                          selected: _controller.levels.contains(level),
                          onTap: () => _controller.toggleLevel(level),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _controller.verifiedOnly,
                    activeThumbColor: AppColors.primary,
                    title: const Text('Payment verified clients only'),
                    subtitle: const Text(
                      'Hide projects from unverified clients',
                    ),
                    onChanged: _controller.setVerifiedOnly,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _controller.clearFilters,
                        child: const Text('Clear all'),
                      ),
                      // A fixed-width button plus 'Clear all' is wider than a
                      // narrow phone's sheet, so the button keeps its 170 but
                      // gives up width to the row before it overflows.
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 170),
                            child: AppButton(
                              text:
                                  'Show ${_controller.results.length} results',
                              borderRadius: AppDimensions.radiusXl,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // The board is one scroll view of slivers: the chrome above and a
        // lazily built row of cards below, so a response that carries the whole
        // open set still only builds the rows this frame can show.
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppDimensions.md),
                sliver: SliverToBoxAdapter(
                  child: _Hero(
                    search: _searchController,
                    onChanged: _controller.setQuery,
                    onSearch: _controller.searchNow,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: _FilterRow(
                    controller: _controller,
                    onFilters: _openFilters,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.xl,
                  AppDimensions.md,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _BoardHeader(
                    controller: _controller,
                    count: _controller.results.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.md,
                  AppDimensions.md,
                  AppDimensions.xxl,
                ),
                sliver: _Board(
                  status: _controller.status,
                  results: _controller.results,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The board's own header: what the tab is for, the search field, and the bid
/// balance the whole flow spends from.
class _Hero extends StatelessWidget {
  final TextEditingController search;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSearch;

  const _Hero({
    required this.search,
    required this.onChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Projects',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'Search the board, open a project, and send a proposal.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              const _BidsChip(),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          _SearchRow(
            controller: search,
            onChanged: onChanged,
            onSearch: onSearch,
          ),
        ],
      ),
    );
  }
}

/// The board's count and the filters currently applied to it.
class _BoardHeader extends StatelessWidget {
  final FindWorkController controller;
  final int count;

  const _BoardHeader({required this.controller, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            controller.tab == 2
                ? 'Saved projects'
                : controller.tab == 1
                ? 'Best matches'
                : 'Most recent',
            style: AppTextStyles.heading4,
          ),
        ),
        if (controller.category != null)
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.sm),
            child: AppTag(controller.category!.name, selected: true),
          ),
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
            '$count',
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// The area under the filters: one read of the board, in whichever state it is
/// in. Pull-to-refresh and the retry button are the only ways to ask again.
/// It answers with a sliver, so the rows it holds are built as they are
/// scrolled to rather than all when the response lands.
class _Board extends StatelessWidget {
  final FindWorkStatus status;
  final List<ProjectModel> results;

  const _Board({required this.status, required this.results});

  @override
  Widget build(BuildContext context) {
    final controller = FindWorkController.instance;
    return switch (status) {
      FindWorkStatus.loading => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.xl),
          child: AppLoader(),
        ),
      ),
      FindWorkStatus.error => SliverToBoxAdapter(
        child: AppErrorWidget(
          message: controller.errorMessage,
          onRetry: controller.refresh,
        ),
      ),
      FindWorkStatus.empty || FindWorkStatus.idle || FindWorkStatus.ready =>
        results.isEmpty
            ? SliverToBoxAdapter(
                child: _NoResults(message: controller.emptyMessage),
              )
            : _ProjectRows(
                projects: results,
                onOpen: (project) => _open(context, project),
                onSave: (project) => controller.toggleSave(project.id),
              ),
    };
  }

  Future<void> _open(BuildContext context, ProjectModel project) async {
    await Navigator.pushNamed(
      context,
      RouteNames.projectDetail,
      arguments: project,
    );
    // A proposal sent deeper in the flow reloads the board itself; a bookmark
    // made there only needs this list to repaint.
    FindWorkController.instance.notify();
  }
}

/// The projects in rows of one, two or three columns, built a row at a time.
class _ProjectRows extends StatelessWidget {
  final List<ProjectModel> projects;
  final ValueChanged<ProjectModel> onOpen;
  final ValueChanged<ProjectModel> onSave;

  const _ProjectRows({
    required this.projects,
    required this.onOpen,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    // The scroll view is padded by md on each side, which is the width the old
    // Column was laid out in and therefore what decides the column count.
    final width = MediaQuery.sizeOf(context).width - AppDimensions.md * 2;
    final columns = width >= 1100 ? 3 : (width >= 640 ? 2 : 1);
    return SliverList.builder(
      itemCount: (projects.length / columns).ceil(),
      itemBuilder: (context, row) => _ProjectRow(
        projects: projects,
        start: row * columns,
        columns: columns,
        onOpen: onOpen,
        onSave: onSave,
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final List<ProjectModel> projects;
  final int start;
  final int columns;
  final ValueChanged<ProjectModel> onOpen;
  final ValueChanged<ProjectModel> onSave;

  const _ProjectRow({
    required this.projects,
    required this.start,
    required this.columns,
    required this.onOpen,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final slice = projects.skip(start).take(columns).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < columns; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : AppDimensions.md),
                  child: i < slice.length
                      ? ProjectCard(
                          project: slice[i],
                          onTap: () => onOpen(slice[i]),
                          onSave: () => onSave(slice[i]),
                        )
                      : const SizedBox(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSearch;

  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final field = AppTextField(
      controller: controller,
      hint: 'Search Projects here...',
      borderRadius: 30,
      onChanged: onChanged,
      prefixIcon: const Icon(
        Icons.search_rounded,
        size: 20,
        color: AppColors.textHint,
      ),
    );
    final button = AppButton(
      text: 'Search Projects',
      width: 170,
      borderRadius: 30,
      backgroundColor: AppColors.accent,
      textColor: AppColors.primary,
      onPressed: () {
        FocusScope.of(context).unfocus();
        onSearch();
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            children: [
              field,
              const SizedBox(height: AppDimensions.sm),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: button,
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: AppDimensions.md),
            button,
          ],
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  final FindWorkController controller;
  final VoidCallback onFilters;

  const _FilterRow({required this.controller, required this.onFilters});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A segmented pill bar reads as one control with three choices, which
        // the underline tabs did not.
        Container(
          padding: const EdgeInsets.all(AppDimensions.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              for (
                int index = 0;
                index < FindWorkController.tabs.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: AppDimensions.xs),
                Expanded(
                  child: _PillTab(
                    label: index == 2
                        ? 'Save Jobs (${controller.savedCount})'
                        : FindWorkController.tabs[index],
                    active: controller.tab == index,
                    onTap: () => controller.setTab(index),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            AppTag(
              'Filters',
              icon: Icons.tune,
              selected: controller.hasFilters,
              onTap: onFilters,
            ),
            const Spacer(),
            if (controller.hasFilters)
              TextButton(
                onPressed: controller.clearFilters,
                child: const Text('Clear filters'),
              ),
          ],
        ),
      ],
    );
  }
}

/// The bid balance, on the hero panel where a proposal is about to spend it.
///
/// The number is the connects `GET /api/wallet` counted for this account. The
/// board itself has no connects column, so this chip asks that route when the
/// panel opens and shows a dash until it answers.
class _BidsChip extends StatefulWidget {
  const _BidsChip();

  @override
  State<_BidsChip> createState() => _BidsChipState();
}

class _BidsChipState extends State<_BidsChip> {
  final WalletController _wallet = WalletController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _wallet.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _wallet,
      builder: (context, _) => Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          onTap: () => showBuyBidsSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bids: ${_wallet.value.bidsLabel}',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Buy Bids',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    const Icon(
                      Icons.arrow_outward,
                      size: 12,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: AppDimensions.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
            ),
          ),
          // Three labels share one row, and the longest of them is wider than a
          // third of a narrow phone, so the text gives up size rather than
          // pushing the row out of the card.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String message;

  const _NoResults({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.xl),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off,
              size: AppDimensions.iconXl,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading4,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Pull down to read the board again, or clear the filters.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
