import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/file_selection_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controller/profile_controller.dart';
import '../services/profile_photo_service.dart';
import '../widgets/profile_form_dialog.dart';

/// Content kinds the "Your Content" area accepts, in the order the design
/// shows them.
enum _BlockType { image, video, file, text, link, code, document }

const List<({IconData icon, _BlockType type, String label})> _blockTypes = [
  (icon: Icons.image_outlined, type: _BlockType.image, label: 'Image'),
  (icon: Icons.play_circle_outline, type: _BlockType.video, label: 'Video'),
  (icon: Icons.description_outlined, type: _BlockType.file, label: 'Document'),
  (icon: Icons.text_fields, type: _BlockType.text, label: 'Text'),
  (icon: Icons.link, type: _BlockType.link, label: 'Link'),
  (icon: Icons.code, type: _BlockType.code, label: 'Code'),
  (icon: Icons.graphic_eq, type: _BlockType.document, label: 'Audio'),
];

extension on _BlockType {
  IconData get icon =>
      _blockTypes.firstWhere((entry) => entry.type == this).icon;
  String get label =>
      _blockTypes.firstWhere((entry) => entry.type == this).label;
}

/// One content block. [upload] carries the bytes a picked file gave back, so
/// Image and document blocks can reach the media route.
typedef _Block = ({
  _BlockType type,
  String label,
  ({Uint8List bytes, String filename, String mimeType})? upload,
});

const int _titleLimit = 70;
const int _roleLimit = 100;
const int _descriptionLimit = 1000;
const int _skillLimit = 5;

/// The "Add A New Portfolio Project" form. Publishing uploads the picked file
/// to the media route, creates the project through the portfolio route and
/// joins it to the shared [ProfileController] grid.
class AddPortfolioScreen extends StatefulWidget {
  const AddPortfolioScreen({super.key});

  @override
  State<AddPortfolioScreen> createState() => _AddPortfolioScreenState();
}

class _AddPortfolioScreenState extends State<AddPortfolioScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _role = TextEditingController();
  final _skill = TextEditingController();
  final _description = TextEditingController();
  final _blockInput = TextEditingController();

  final List<String> _skills = [];
  final List<_Block> _blocks = [];

  @override
  void dispose() {
    _title.dispose();
    _role.dispose();
    _skill.dispose();
    _description.dispose();
    _blockInput.dispose();
    super.dispose();
  }

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _remaining(TextEditingController field, int limit) {
    final left = limit - field.text.trim().length;
    return '$left ${limit == _skillLimit ? 'skills' : 'characters'} left';
  }

  void _addSkill() {
    final skill = _skill.text.replaceAll(',', '').trim();
    if (skill.isEmpty) return;
    if (_skills.length >= _skillLimit) {
      _note('$_skillLimit skills is the maximum for one project.');
      return;
    }
    setState(() {
      if (!_skills.contains(skill)) _skills.add(skill);
      _skill.clear();
    });
  }

  Future<void> _addBlock(_BlockType type) async {
    if (type == _BlockType.link &&
        _blocks.any((block) => block.type == _BlockType.link)) {
      _note('Each project can have one link. Remove it before adding another.');
      return;
    }
    switch (type) {
      case _BlockType.image:
        final photo = await ProfilePhotoService.instance.pickFile(
          ImageSource.gallery,
        );
        if (photo == null) return;
        setState(
          () => _blocks.add((type: type, label: type.label, upload: photo)),
        );
      case _BlockType.video:
        final file = await ProfilePhotoService.instance.pickVideo();
        if (file == null) return;
        setState(
          () => _blocks.add((type: type, label: file.name, upload: null)),
        );
      case _BlockType.file:
        try {
          final files = await FileSelectionService.pick(
            extensions: const ['pdf', 'doc', 'docx'],
          );
          if (files.isEmpty) return;
          final file = files.single;
          if (file.bytes.length > 60 * 1024 * 1024) {
            _note('Documents must be 60 MB or smaller.');
            return;
          }
          setState(
            () => _blocks.add((
              type: type,
              label: file.name,
              upload: (
                bytes: file.bytes,
                filename: file.name,
                mimeType: file.mimeType,
              ),
            )),
          );
        } on PlatformException {
          _note('This device could not open the file picker.');
        } on FormatException catch (error) {
          _note(error.message);
        }
      case _BlockType.text:
      case _BlockType.link:
      case _BlockType.code:
      case _BlockType.document:
        _blockInput.clear();
        final hint = switch (type) {
          _BlockType.link => 'Paste a full URL (https://...)',
          _BlockType.code => 'Paste the snippet',
          _BlockType.document => 'Name the audio recording',
          _ => 'Write a short paragraph',
        };
        final result = await showProfileFormDialog(
          context,
          title: 'Add ${type.label}',
          fields: [
            AppTextField(
              hint: hint,
              controller: _blockInput,
              maxLines: type == _BlockType.text || type == _BlockType.code
                  ? 4
                  : 1,
              validator: type == _BlockType.link
                  ? _portfolioLinkValidator
                  : requiredField,
            ),
          ],
        );
        if (result != ProfileFormResult.save) return;
        setState(
          () => _blocks.add((
            type: type,
            label: _blockInput.text.trim(),
            upload: null,
          )),
        );
    }
  }

  String? _portfolioLinkValidator(String? value) {
    final missing = requiredField(value);
    if (missing != null) return missing;
    return Validators.isWebAddress(value!)
        ? null
        : 'Enter a valid website URL starting with http:// or https://.';
  }

  /// The backend's own `mediaType` name for a content block.
  String _mediaType(_BlockType type) => switch (type) {
    _BlockType.image => 'image',
    _BlockType.video => 'video',
    _BlockType.text => 'text',
    _BlockType.link => 'link',
    _BlockType.code => 'text',
    _BlockType.document => 'music',
    _BlockType.file => 'file',
  };

  /// Uploads an optional cover file, then creates the project through the
  /// portfolio route. A project may instead consist of a validated link.
  Future<void> _publish(String status) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_blocks.isEmpty) {
      _note('Content is required.');
      return;
    }
    final title = _title.text.trim();
    if (title.length < 2) {
      // The route's own check is a trimmed length of at least 2.
      _note('The project title needs at least 2 characters.');
      return;
    }
    _Block? linkBlock;
    for (final block in _blocks) {
      if (block.type == _BlockType.link) {
        linkBlock = block;
        break;
      }
    }
    final cover = _blocks.firstWhere(
      (block) => block.upload != null,
      orElse: () => linkBlock ?? _blocks.first,
    );
    final upload = cover.upload;
    final link = linkBlock?.label.trim() ?? '';
    if (upload == null && link.isEmpty) {
      _note('Add a project link or upload an image or document.');
      return;
    }
    final profile = ProfileController.instance;
    final stored = await profile.publishPortfolio((
      title: title,
      role: _role.text.trim(),
      skills: List<String>.unmodifiable(_skills),
      description: _description.text.trim(),
      link: link,
      status: status,
      kind: upload == null ? 'link' : _mediaType(cover.type),
      bytes: upload?.bytes,
      filename: upload?.filename ?? '',
      mimeType: upload?.mimeType ?? '',
    ));
    if (!mounted) return;
    if (!stored) {
      _note(
        profile.errorMessage.isEmpty
            ? 'The project could not be saved.'
            : profile.errorMessage,
      );
      return;
    }
    final storedBlocks = (upload == null ? 0 : 1) + (link.isEmpty ? 0 : 1);
    final dropped = _blocks.length - storedBlocks;
    _note(
      (status == 'DRAFT' ? '$title saved as draft.' : '$title published.') +
          (dropped <= 0 ? '' : ' $dropped content block(s) had nowhere to go.'),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final bodyWidth = width > 980 ? 980.0 : width;
            final pairWide = width >= 640;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bodyWidth),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          pairWide: pairWide,
                          onBack: () => Navigator.of(context).pop(),
                          onDraft: () => _publish('DRAFT'),
                          onPublish: () => _publish('PUBLISHED'),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        _CounterField(
                          label: 'Project Title',
                          hint: 'Enter a brief but descriptive title.',
                          controller: _title,
                          counter: _remaining(_title, _titleLimit),
                          validator: requiredField,
                        ),
                        const SizedBox(height: AppDimensions.md),
                        if (pairWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CounterField(
                                  label: 'Your role (optional)',
                                  hint: 'Enter a brief but descriptive role.',
                                  controller: _role,
                                  counter: _remaining(_role, _roleLimit),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.lg),
                              Expanded(
                                child: _CounterField(
                                  label: 'Skills and deliverables',
                                  hint: 'Type to add skills relevant to this project',
                                  controller: _skill,
                                  counter: _remaining(_skill, _skillLimit),
                                  onSubmit: _addSkill,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CounterField(
                                label: 'Your role (optional)',
                                hint: 'Enter a brief but descriptive role.',
                                controller: _role,
                                counter: _remaining(_role, _roleLimit),
                              ),
                              const SizedBox(height: AppDimensions.md),
                              _CounterField(
                                label: 'Skills and deliverables',
                                hint: 'Type to add skills relevant to this project',
                                controller: _skill,
                                counter: _remaining(_skill, _skillLimit),
                                onSubmit: _addSkill,
                              ),
                            ],
                          ),
                        if (_skills.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.sm),
                          Wrap(
                            spacing: AppDimensions.sm,
                            runSpacing: AppDimensions.sm,
                            children: [
                              for (final skill in _skills)
                                _SkillPill(
                                  skill: skill,
                                  onRemove: () =>
                                      setState(() => _skills.remove(skill)),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppDimensions.md),
                        _CounterField(
                          label: 'Project description',
                          hint: "Briefly describe the project's goals, your solution and the impact.",
                          controller: _description,
                          counter: _remaining(_description, _descriptionLimit),
                          maxLines: 5,
                          validator: requiredField,
                        ),
                        const SizedBox(height: AppDimensions.lg),
                        _ContentBoard(
                          blocks: _blocks,
                          onAdd: _addBlock,
                          onRemove: (block) =>
                              setState(() => _blocks.remove(block)),
                        ),
                        const SizedBox(height: AppDimensions.xl),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool pairWide;
  final VoidCallback onBack;
  final VoidCallback onDraft;
  final VoidCallback onPublish;

  const _Header({
    required this.pairWide,
    required this.onBack,
    required this.onDraft,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add A New Portfolio Project', style: AppTextStyles.heading3),
        const SizedBox(height: 2),
        Text(
          'All fields are required unless otherwise indicated.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    final back = TextButton.icon(
      onPressed: onBack,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(
        Icons.arrow_back_ios_new,
        size: AppDimensions.iconSm,
        color: AppColors.primary,
      ),
      label: const Text('Back'),
    );
    final draft = TextButton(
      onPressed: onDraft,
      child: const Text('Save as Draft'),
    );
    final publish = Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        onTap: onPublish,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.sm,
          ),
          child: Text(
            'Publish',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
          ),
        ),
      ),
    );
    if (!pairWide) {
      // Two controls side by side need more room than a phone gives, so they
      // wrap onto their own lines instead of running off the edge.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: Alignment.centerLeft, child: back),
          const SizedBox(height: AppDimensions.sm),
          heading,
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.sm,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [draft, publish],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        back,
        const SizedBox(width: AppDimensions.sm),
        Expanded(child: heading),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            draft,
            const SizedBox(width: AppDimensions.sm),
            publish,
          ],
        ),
      ],
    );
  }
}

/// A labelled field with the "N characters left" counter under it, right
/// aligned as in the design.
class _CounterField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String counter;
  final int maxLines;
  final VoidCallback? onSubmit;
  final String? Function(String?)? validator;

  const _CounterField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.counter,
    this.maxLines = 1,
    this.onSubmit,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: label,
          hint: hint,
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          onFieldSubmitted: onSubmit == null ? null : (_) => onSubmit!.call(),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.xs),
          child: Text(
            counter,
            textAlign: TextAlign.end,
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
        ),
      ],
    );
  }
}

class _SkillPill extends StatelessWidget {
  final String skill;
  final VoidCallback onRemove;

  const _SkillPill({required this.skill, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      padding: const EdgeInsets.only(
        left: AppDimensions.md,
        right: AppDimensions.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              skill,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
            ),
          ),
          IconButton(
            tooltip: 'Remove $skill',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.close,
              size: AppDimensions.iconSm,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed "Your Content" board: added blocks plus one circular control per
/// content type.
class _ContentBoard extends StatelessWidget {
  final List<_Block> blocks;
  final ValueChanged<_BlockType> onAdd;
  final ValueChanged<_Block> onRemove;

  const _ContentBoard({
    required this.blocks,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    const radius = AppDimensions.radiusLg;
    return CustomPaint(
      // The outline is painted rather than drawn with a border so the dashes
      // stay even at every width.
      foregroundPainter: const _DashedBorderPainter(radius: radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (blocks.isNotEmpty) ...[
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: [
                  for (final block in blocks)
                    _BlockTile(block: block, onRemove: () => onRemove(block)),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
            ],
            Center(
              child: Text(
                'Your Content',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in _blockTypes)
                  _TypeButton(
                    icon: entry.icon,
                    label: entry.label,
                    onTap: () => onAdd(entry.type),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;

  const _DashedBorderPainter({this.radius = AppDimensions.radiusLg});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 7, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

class _TypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TypeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add $label',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.accent)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Icon(
                icon,
                size: AppDimensions.iconSm,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  final _Block block;
  final VoidCallback onRemove;

  const _BlockTile({required this.block, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final remove = Positioned(
      top: 0,
      right: 0,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onRemove,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: Icon(Icons.close, size: 14, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
    final upload = block.upload;
    if (upload != null && block.type != _BlockType.file) {
      // A picture preview spans the board so the project cover reads clearly.
      return SizedBox(
        width: double.infinity,
        height: 190,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radius),
              child: Image.memory(
                upload.bytes,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
              ),
            ),
            remove,
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
      ),
      child: Row(
        children: [
          Icon(
            block.type.icon,
            size: AppDimensions.iconSm,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              block.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ),
          IconButton(
            tooltip: 'Remove ${block.label}',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
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
