import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../../finance/controller/read_state.dart';
import '../../finance/controller/weekly_controller.dart';
import '../../finance/models/weekly_report.dart';
import '../../finance/widgets/read_view.dart';

/// Downloadable weekly reports.
///
/// Both cards read the website's own `GET /api/reports/weekly`: the summary
/// scope answers for any signed-in freelancer, and the client scope is the
/// Pro-only half of the same route, so a membership refusal is what moves a
/// card to the upgrade tag rather than a rule the app assumes. Previewing shows
/// the numbers the route returned and downloading shows the text file the route
/// wrote — the device adds no figures of its own.
class YourReportsScreen extends StatefulWidget {
  const YourReportsScreen({super.key});

  @override
  State<YourReportsScreen> createState() => _YourReportsScreenState();
}

class _YourReportsScreenState extends State<YourReportsScreen> {
  final WeeklyController _controller = WeeklyController.instance;

  @override
  void initState() {
    super.initState();
    for (final scope in WeeklyScope.values) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.load(scope);
      });
    }
  }

  Future<void> _refresh() => Future.wait([
    for (final scope in WeeklyScope.values)
      _controller.load(scope, force: true),
  ]);

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _preview(WeeklyScope scope) {
    if (_controller.isLocked(scope)) {
      _note('Upgrade to Pro to preview this report.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => _PreviewDialog(
        controller: _controller,
        scope: scope,
        onDownload: () {
          Navigator.of(context).pop();
          _download(scope);
        },
      ),
    );
  }

  Future<void> _download(WeeklyScope scope) async {
    if (_controller.isDownloading) return;
    final text = await _controller.download(scope);
    if (!mounted) return;
    if (text == null) {
      _note(
        _controller.isLocked(scope)
            ? 'Upgrade to Pro to download this report.'
            : _controller.downloadError.isEmpty
            ? 'The report could not be read. Please try again.'
            : _controller.downloadError,
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => _ReportTextDialog(title: scope.title, text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModuleAppBar(
        title: 'My Reports',
        subtitle: 'Downloadable account reports',
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final sideBySide = width >= 900;
                  final bodyWidth = width > 1100 ? 1100.0 : width;
                  final cards = [
                    for (final scope in WeeklyScope.values)
                      _ReportCard(
                        scope: scope,
                        controller: _controller,
                        onPreview: () => _preview(scope),
                        onDownload: () => _download(scope),
                        onUpgrade: () => Navigator.pushNamed(
                          context,
                          RouteNames.membershipPlan,
                        ),
                      ),
                  ];

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: bodyWidth),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppDimensions.md),
                        child: sideBySide
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: cards.first),
                                    const SizedBox(width: AppDimensions.md),
                                    Expanded(child: cards.last),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  for (final card in cards)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppDimensions.md,
                                      ),
                                      child: card,
                                    ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final WeeklyScope scope;
  final WeeklyController controller;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onUpgrade;

  const _ReportCard({
    required this.scope,
    required this.controller,
    required this.onPreview,
    required this.onDownload,
    required this.onUpgrade,
  });

  bool get _locked => controller.isLocked(scope);

  @override
  Widget build(BuildContext context) {
    final report = controller.reportFor(scope);
    final failed = controller.stateOf(scope) == ReadState.failed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_locked) ...[
          Center(
            child: AppTag(
              'Upgrade to Pro',
              icon: Icons.workspace_premium,
              highlight: true,
              onTap: onUpgrade,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
        ],
        AppCard(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scope.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading4,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  if (controller.isLoading(scope))
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: AppLoader(size: 18),
                    )
                  else
                    IconButton(
                      tooltip: _locked
                          ? 'Locked'
                          : failed
                          ? 'Try again'
                          : 'Preview',
                      onPressed: onPreview,
                      icon: Icon(
                        _locked
                            ? Icons.lock_outline
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  IconButton(
                    tooltip: _locked ? 'Locked' : 'Download',
                    onPressed: controller.isDownloading ? null : onDownload,
                    icon: Icon(
                      _locked ? Icons.lock_outline : Icons.download_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                _description(scope),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (report != null) ...[
                const SizedBox(height: AppDimensions.md),
                Text(
                  report.rangeLabel,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.lg,
                  runSpacing: AppDimensions.sm,
                  children: [
                    for (final line in report.summaryLines)
                      _Figure(label: line.label, value: line.value),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The two cards' copy. No number appears here — every figure comes from the
/// route the card reads.
String _description(WeeklyScope scope) => switch (scope) {
  WeeklyScope.summary =>
    'A snapshot of everything that happened on your account this week: '
        'proposals you sent, jobs that moved forward and the earnings that '
        'cleared escrow. Share it with your accountant or keep it for your '
        'own records.',
  WeeklyScope.client =>
    'The same week broken down per client, so you can see who paid, who '
        'is still reviewing a milestone and where your time really went.',
};

class _Figure extends StatelessWidget {
  final String label;
  final String value;

  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.labelLarge),
      ],
    );
  }
}

class _PreviewDialog extends StatelessWidget {
  final WeeklyController controller;
  final WeeklyScope scope;
  final VoidCallback onDownload;

  const _PreviewDialog({
    required this.controller,
    required this.scope,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final report = controller.reportFor(scope);

        return AlertDialog(
          title: Text(scope.title),
          content: SizedBox(
            width: width > 620 ? 460 : width - 120,
            child: ReadView(
              state: controller.stateOf(scope),
              error: controller.errorFor(scope),
              onRetry: () => controller.load(scope, force: true),
              empty: Text(
                controller.isLocked(scope)
                    ? 'This report needs an active Pro membership.'
                    : 'The report came back with nothing in it.',
                style: AppTextStyles.bodyMedium,
              ),
              builder: (context) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report!.rangeLabel,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    for (final line in report.summaryLines)
                      _PreviewRow(label: line.label, value: line.value),
                    if (report.clients.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        'By client',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      for (final row in report.clients)
                        _PreviewRow(
                          label: row.name,
                          value:
                              '${row.jobs} jobs · ${row.submitted} submitted · '
                              '${row.earnedLabel}',
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            AppButton(
              text: 'Download',
              icon: Icons.download_outlined,
              isLoading: controller.isDownloading,
              onPressed: controller.isLocked(scope) ? null : onDownload,
            ),
          ],
        );
      },
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The server's own text file, shown rather than written somewhere a phone
/// cannot hand it back to the user.
class _ReportTextDialog extends StatelessWidget {
  final String title;
  final String text;

  const _ReportTextDialog({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: width > 620 ? 560 : width - 80,
        height: 360,
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
