import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../finance/controller/wallet_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../../profile/models/profile_entries.dart';
import '../../profile/widgets/buy_bids_sheet.dart';
import '../controller/find_work_controller.dart';
import '../models/project_model.dart';
import '../services/find_work_service.dart';
import '../services/proposal_attachment_service.dart';

const double _serviceFee = 0.20;
const int _maxAttachments = FindWorkService.attachmentMax;
const int _maxPortfolio = FindWorkService.portfolioMax;
const List<String> _fontNames = ['Default', 'Serif', 'Monospace'];
const List<String?> _fontFamilies = [null, 'serif', 'monospace'];

String _money(double value) => '\$${value.toStringAsFixed(2)}';

/// The proposal form a freelancer fills before a job application goes out.
/// Opening it never marks the job as applied; only an accepted bid does, and
/// that is decided by `POST /api/tasks/{id}/bid`.
class SubmitProposalScreen extends StatefulWidget {
  final ProjectModel project;

  const SubmitProposalScreen({super.key, required this.project});

  @override
  State<SubmitProposalScreen> createState() => _SubmitProposalScreenState();
}

class _SubmitProposalScreenState extends State<SubmitProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cover = TextEditingController();
  late final TextEditingController _rate;
  final List<ProposalAttachment> _attachments = [];
  final List<String> _portfolio = [];
  int _font = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(text: _profileRate.toStringAsFixed(2));
    // The card under the form says what this proposal leaves on the account,
    // and only the wallet route knows what was on it before.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WalletController.instance.load();
    });
  }

  @override
  void dispose() {
    _rate.dispose();
    _cover.dispose();
    super.dispose();
  }

  /// The seeded profile rate pre-fills the bid so the form is never empty.
  double get _profileRate {
    final match = RegExp(r'\d+(\.\d+)?')
        .firstMatch(ProfileController.instance.hourlyRate);
    final rate = double.tryParse(match?.group(0) ?? '') ?? 0;
    // The backend refuses a rate under its minimum, so the form never starts
    // below it.
    return rate < FindWorkService.amountMin ? FindWorkService.amountMin : rate;
  }

  double get _bidRate => double.tryParse(_rate.text.trim()) ?? 0;

  int? get _remaining {
    final held = WalletController.instance.value.connects;
    return held == null ? null : held - widget.project.proposalCost;
  }

  /// Uploads what the form holds and asks the backend for the bid. The success
  /// message only appears when the route answers 201.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = FindWorkController.instance;
    setState(() => _submitting = true);
    final outcome = await controller.apply(
      widget.project,
      proposal: _cover.text,
      bidAmount: _bidRate,
      attachments: List<ProposalAttachment>.of(_attachments),
      portfolioItemIds: List<String>.of(_portfolio),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!outcome.sent) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(outcome.message),
          behavior: SnackBarBehavior.floating,
          action: outcome.message.contains('connects')
              ? SnackBarAction(
                  label: 'Buy Bids',
                  onPressed: () => showBuyBidsSheet(context),
                )
              : null,
        ),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _attachFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final slots = _maxAttachments - _attachments.length;
    if (slots <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('A proposal can carry up to $_maxAttachments files.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final picked = await ProposalAttachmentService.instance.pick(
        slots: slots,
      );
      if (picked.isEmpty) return;
      setState(() => _attachments.addAll(picked));
    } on FormatException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This device could not open the file picker.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickPortfolio() async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (context) =>
          _PortfolioSheet(initial: _portfolio, max: _maxPortfolio),
    );
    if (selected == null) return;
    setState(() {
      _portfolio
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Submit a proposal'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.md),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _JobDetailsCard(
                        project: project,
                        onViewJob: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      ListenableBuilder(
                        listenable: WalletController.instance,
                        builder: (context, _) => _ProposalDetailsCard(
                          project: project,
                          remaining: _remaining,
                          rate: _rate,
                          profileRate: _profileRate,
                          receive: '${_money(_bidRate * (1 - _serviceFee))}/hr',
                          onRateChanged: () => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _AdditionalDetailsCard(
                        cover: _cover,
                        attachments: _attachments,
                        font: _font,
                        onFont: (index) => setState(() => _font = index),
                        onAttach: _attachFiles,
                        onRemove: (index) =>
                            setState(() => _attachments.removeAt(index)),
                      ),
                      const SizedBox(height: AppDimensions.md),
                      _PortfolioCard(
                        selected: _portfolio,
                        onAdd: _pickPortfolio,
                        onRemove: (id) => setState(() => _portfolio.remove(id)),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          // A Column that shrink-wraps: Center would make the footer fill the
          // body height and squeeze the scrollable area to zero.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: AppButton(
                  text: _submitting ? 'Sending proposal...' : 'Submit Proposal',
                  backgroundColor: AppColors.primary,
                  textColor: Colors.white,
                  borderRadius: AppDimensions.radiusXl,
                  onPressed: _submitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetailsCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onViewJob;

  const _JobDetailsCard({required this.project, required this.onViewJob});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Job details', style: AppTextStyles.heading4),
              ),
              TextButton.icon(
                onPressed: onViewJob,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.open_in_new, size: AppDimensions.iconSm),
                label: const Text('View job', style: AppTextStyles.labelMedium),
              ),
            ],
          ),
          Text(
            project.title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppDimensions.xs + 2),
          Text(
            project.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(height: 1.6),
          ),
          const SizedBox(height: AppDimensions.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final cells = <Widget>[
                _MetaCell(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Level',
                  value: project.level,
                ),
                _MetaCell(
                  icon: Icons.schedule_outlined,
                  label: 'Duration',
                  value: project.duration,
                ),
                _MetaCell(
                  icon: Icons.attach_money_outlined,
                  label: 'Budget',
                  value: project.price,
                ),
              ];
              if (constraints.maxWidth < 420) {
                return Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: [
                    for (final cell in cells) SizedBox(width: 150, child: cell),
                  ],
                );
              }
              return Row(
                children: [
                  for (int index = 0; index < cells.length; index++) ...[
                    if (index > 0) const SizedBox(width: AppDimensions.sm),
                    Expanded(child: cells[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon, size: 32),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelMedium),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProposalDetailsCard extends StatelessWidget {
  final ProjectModel project;
  final int? remaining;
  final TextEditingController rate;
  final double profileRate;
  final String receive;
  final VoidCallback onRateChanged;

  const _ProposalDetailsCard({
    required this.project,
    required this.remaining,
    required this.rate,
    required this.profileRate,
    required this.receive,
    required this.onRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proposal Details', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          Text.rich(
            TextSpan(
              text: 'This proposal requires:  ',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: '${project.proposalCost} Bids',
                  style: AppTextStyles.labelLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xs + 2),
          Text(
            switch (remaining) {
              null => 'The wallet has not reported your Bids yet.',
              final left when left < 0 =>
                'You need ${-left} more Bids to send this proposal.',
              final left =>
                "When you submit this proposal, you'll have $left Bids remaining",
            },
            style: AppTextStyles.bodySmall.copyWith(
              color: (remaining ?? 0) < 0
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "What is the rate you'd like to bid for",
                  style: AppTextStyles.labelLarge,
                ),
              ),
              AppTag(
                'Service fee ${(_serviceFee * 100).round()}%',
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Your Profile rate is ${_money(profileRate)}/hr',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppDimensions.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                _RateField(
                  label: 'Hourly Rate',
                  child: AppTextField(
                    controller: rate,
                    hint: '0.00',
                    suffixText: '/hr',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    textInputAction: TextInputAction.done,
                    validator: _requiredRate,
                    onChanged: (_) => onRateChanged(),
                  ),
                ),
                _RateField(
                  label: "You'll Receive",
                  child: Container(
                    height: AppDimensions.textFieldHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.md,
                    ),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppDimensions.radius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(receive, style: AppTextStyles.labelLarge),
                  ),
                ),
              ];
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.md,
                        ),
                        child: field,
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(child: fields[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String? _requiredRate(String? value) {
  final rate = double.tryParse((value ?? '').trim());
  if (rate == null || rate <= 0) return 'Enter the rate you want to bid';
  if (rate < FindWorkService.amountMin || rate > FindWorkService.amountMax) {
    return 'The bid rate must be between \$${FindWorkService.amountMin.toInt()} '
        'and \$${FindWorkService.amountMax.toInt()}';
  }
  return null;
}

String? _requiredProposal(String? value) {
  final text = (value ?? '').trim();
  if (text.length < FindWorkService.proposalMin) {
    return 'Write a clear proposal (min '
        '${FindWorkService.proposalMin} characters).';
  }
  if (text.length > FindWorkService.proposalMax) {
    return 'A proposal can be up to ${FindWorkService.proposalMax} characters.';
  }
  return null;
}

class _RateField extends StatelessWidget {
  final String label;
  final Widget child;

  const _RateField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.xs),
        child,
      ],
    );
  }
}

class _AdditionalDetailsCard extends StatelessWidget {
  final TextEditingController cover;
  final List<ProposalAttachment> attachments;
  final int font;
  final ValueChanged<int> onFont;
  final VoidCallback onAttach;
  final ValueChanged<int> onRemove;

  const _AdditionalDetailsCard({
    required this.cover,
    required this.attachments,
    required this.font,
    required this.onFont,
    required this.onAttach,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final full = attachments.length >= _maxAttachments;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Additional Details', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          AppTextField(
            label: 'Cover Letter',
            controller: cover,
            hint: 'Tell the client why you are the right fit',
            maxLines: 5,
            style: AppTextStyles.bodyMedium.copyWith(
              fontFamily: _fontFamilies[font],
            ),
            // The same rule the bid route applies, so a proposal that would be
            // refused never leaves the device.
            validator: _requiredProposal,
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              const Expanded(
                child: Text('Attachments', style: AppTextStyles.labelLarge),
              ),
              PopupMenuButton<int>(
                tooltip: 'Font',
                initialValue: font,
                color: AppColors.surface,
                onSelected: onFont,
                itemBuilder: (context) => [
                  for (int index = 0; index < _fontNames.length; index++)
                    PopupMenuItem(
                      value: index,
                      child: Text(
                        _fontNames[index],
                        style: TextStyle(fontFamily: _fontFamilies[index]),
                      ),
                    ),
                ],
                child: const _ChipAction(
                  icon: Icons.text_fields,
                  label: 'Font',
                ),
              ),
            ],
          ),
          const Text(
            'Up to $_maxAttachments images or PDF/Word files, max 10 MB each',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppDimensions.sm),
          for (int index = 0; index < attachments.length; index++)
            _AttachmentRow(
              attachment: attachments[index],
              onRemove: () => onRemove(index),
            ),
          OutlinedButton.icon(
            onPressed: full ? null : onAttach,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.accent,
              disabledForegroundColor: AppColors.textHint,
              disabledBackgroundColor: AppColors.surfaceVariant,
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              ),
            ),
            icon: const Icon(Icons.attach_file, size: AppDimensions.iconSm),
            label: const Text('Attach files', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final ProposalAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentRow({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        children: [
          const IconBadge(Icons.insert_drive_file_outlined, size: 32),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium,
                ),
                Text(attachment.sizeLabel, style: AppTextStyles.caption),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove file',
            icon: const Icon(
              Icons.close,
              size: AppDimensions.iconSm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ChipAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSm,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppDimensions.xs),
          Text(label, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final List<String> selected;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _PortfolioCard({
    required this.selected,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Only rows this device published have a backend id, and the id is what a
    // bid stores, so the picker cannot offer the profile's sample content.
    final items = ProfileController.instance.portfolio;
    final chosen = [
      for (final item in items)
        if (selected.contains(item.id)) item,
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Portfolio Highlight', style: AppTextStyles.heading4),
          const SizedBox(height: AppDimensions.md),
          if (items.isEmpty)
            const Text(
              'Publish a project in your profile to highlight one here.',
              style: AppTextStyles.caption,
            ),
          Wrap(
            spacing: AppDimensions.md,
            runSpacing: AppDimensions.md,
            children: [
              for (final item in chosen)
                _PortfolioThumb(item: item, onRemove: () => onRemove(item.id)),
              if (chosen.length < _maxPortfolio && items.isNotEmpty)
                _AddPortfolio(
                  onAdd: onAdd,
                  remaining: _maxPortfolio - chosen.length,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortfolioThumb extends StatelessWidget {
  static const double width = 150;
  static const double height = 90;

  final PortfolioItem item;
  final VoidCallback onRemove;

  const _PortfolioThumb({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: Image.network(
                  item.image,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: width,
                    height: height,
                    color: AppColors.surfaceVariant,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppDimensions.xs,
                right: AppDimensions.xs,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(AppDimensions.xs),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs + 2),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPortfolio extends StatelessWidget {
  final VoidCallback onAdd;
  final int remaining;

  const _AddPortfolio({required this.onAdd, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PortfolioThumb.width,
      child: OutlinedButton(
        onPressed: onAdd,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
        ),
        child: SizedBox(
          height: _PortfolioThumb.height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add,
                size: AppDimensions.iconMd,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'Add Portfolio Project',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text('(Max $remaining)', style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioSheet extends StatefulWidget {
  final List<String> initial;
  final int max;

  const _PortfolioSheet({required this.initial, required this.max});

  @override
  State<_PortfolioSheet> createState() => _PortfolioSheetState();
}

class _PortfolioSheetState extends State<_PortfolioSheet> {
  late final List<String> _picked = [...widget.initial];

  void _toggle(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else if (_picked.length < widget.max) {
        _picked.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ProfileController.instance.portfolio;
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Portfolio projects', style: AppTextStyles.heading4),
              Text(
                'Choose up to ${widget.max} projects to highlight.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppDimensions.md),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final checked = _picked.contains(item.id);
                    final blocked = !checked && _picked.length >= widget.max;
                    return CheckboxListTile(
                      value: checked,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: blocked ? null : (_) => _toggle(item.id),
                      title: Text(item.title, style: AppTextStyles.bodyMedium),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              AppButton(
                text: 'Done',
                borderRadius: AppDimensions.radiusXl,
                onPressed: () => Navigator.pop(context, _picked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
