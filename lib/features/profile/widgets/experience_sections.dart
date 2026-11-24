import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/file_selection_service.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/grid_section.dart';
import '../../../core/widgets/icon_badge.dart';
import '../controller/profile_controller.dart';
import '../models/profile_entries.dart';
import 'profile_form_dialog.dart';

typedef _CertificationProof = ({
  Uint8List bytes,
  String filename,
  String mimeType,
});

/// Certifications and Employment work. They share a card layout but are two
/// separate sections, each with its own add control and per-card remove.
class ExperienceSections extends StatefulWidget {
  final int columns;

  const ExperienceSections({super.key, required this.columns});

  @override
  State<ExperienceSections> createState() => _ExperienceSectionsState();
}

class _ExperienceSectionsState extends State<ExperienceSections> {
  final _certTitle = TextEditingController();
  final _certProvider = TextEditingController();
  final _certIssued = TextEditingController();
  final _certId = TextEditingController();
  final _certDescription = TextEditingController();

  final _role = TextEditingController();
  final _company = TextEditingController();
  final _jobDescription = TextEditingController();

  /// The period the employment form is holding. The route stores two dates, so
  /// these are picked from the calendar rather than typed.
  DateTime? _periodStart;
  DateTime? _periodEnd;

  @override
  void dispose() {
    for (final field in [
      _certTitle,
      _certProvider,
      _certIssued,
      _certId,
      _certDescription,
      _role,
      _company,
      _jobDescription,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _certificationForm([int index = -1]) async {
    final profile = ProfileController.instance;
    final entry = index < 0 ? null : profile.certifications[index];
    _CertificationProof? selectedProof;
    var removeExistingProof = false;
    _certTitle.text = entry?.title ?? '';
    _certProvider.text = entry?.provider ?? '';
    _certIssued.text = entry?.issued ?? '';
    _certId.text = entry?.credentialId ?? '';
    _certDescription.text = entry?.description ?? '';
    final result = await showProfileFormDialog(
      context,
      title: index < 0 ? 'Add certification' : 'Edit certification',
      fields: [
        AppTextField(
          hint: 'Certification title',
          controller: _certTitle,
          validator: requiredField,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          hint: 'Issuing organisation',
          controller: _certProvider,
          validator: requiredField,
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(hint: 'Issued', controller: _certIssued),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: AppTextField(hint: 'Credential ID', controller: _certId),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          hint: 'What the certification covers',
          controller: _certDescription,
          maxLines: 3,
        ),
        const SizedBox(height: AppDimensions.sm),
        _CertificationProofPicker(
          proofUrl: entry?.certificateUrl ?? '',
          onChanged: (proof, removeExisting) {
            selectedProof = proof;
            removeExistingProof = removeExisting;
          },
        ),
      ],
      removable: entry != null,
    );
    if (!mounted) return;
    if (result == ProfileFormResult.remove && entry != null) {
      _report(await profile.removeCertification(index));
      return;
    }
    if (result != ProfileFormResult.save) return;
    _report(
      await profile.saveCertification(
        (
          id: entry?.id ?? '',
          title: _certTitle.text.trim(),
          provider: _certProvider.text.trim(),
          issued: _certIssued.text.trim(),
          credentialId: _certId.text.trim(),
          certificateUrl: removeExistingProof
              ? ''
              : entry?.certificateUrl ?? '',
          description: _certDescription.text.trim(),
        ),
        index: index,
        proofBytes: selectedProof?.bytes,
        proofFilename: selectedProof?.filename ?? '',
        proofMimeType: selectedProof?.mimeType ?? '',
      ),
    );
  }

  Future<void> _employmentForm([int index = -1]) async {
    final profile = ProfileController.instance;
    final entry = index < 0 ? null : profile.employment[index];
    _role.text = entry?.role ?? '';
    _company.text = entry?.company ?? '';
    // Editing starts from the dates the route stored, not from the text the
    // card shows, so the pickers open on the job's own range.
    _periodStart = dateFromIso(entry?.startDate ?? '');
    _periodEnd = dateFromIso(entry?.endDate ?? '');
    final result = await showProfileFormDialog(
      context,
      title: index < 0 ? 'Add employment work' : 'Edit employment work',
      fields: [
        AppTextField(
          hint: 'Job title',
          controller: _role,
          validator: requiredField,
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          hint: 'Company',
          controller: _company,
          validator: requiredField,
        ),
        const SizedBox(height: AppDimensions.sm),
        _PeriodFields(
          start: _periodStart,
          end: _periodEnd,
          onChanged: (start, end) {
            _periodStart = start;
            _periodEnd = end;
          },
        ),
        const SizedBox(height: AppDimensions.sm),
        AppTextField(
          hint: 'What you were responsible for',
          controller: _jobDescription,
          maxLines: 3,
        ),
      ],
      removable: entry != null,
    );
    if (!mounted) return;
    if (result == ProfileFormResult.remove && entry != null) {
      _report(await profile.removeEmployment(index));
      return;
    }
    final start = _periodStart;
    // The field validator refuses an empty start date, so a save without one
    // never leaves this method.
    if (result != ProfileFormResult.save || start == null) return;
    final end = _periodEnd;
    _report(
      await profile.saveEmployment((
        id: entry?.id ?? '',
        role: _role.text.trim(),
        company: _company.text.trim(),
        period: periodLabel(start, end),
        startDate: isoDate(start),
        endDate: end == null ? '' : isoDate(end),
        description: _jobDescription.text.trim(),
      ), index: index),
    );
  }

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _removeCertification(int index) async {
    _report(await ProfileController.instance.removeCertification(index));
  }

  Future<void> _removeEmployment(int index) async {
    _report(await ProfileController.instance.removeEmployment(index));
  }

  Future<void> _openCertificationProof(String url) async {
    final failure = await LinkOpener.open(url);
    if (failure == null || !mounted) return;
    _note(failure);
  }

  /// A row the route refused never reaches the profile, so the only sign
  /// anything went wrong is the server's own wording.
  void _report(bool saved) {
    if (saved) return;
    final message = ProfileController.instance.errorMessage;
    if (message.isNotEmpty) _note(message);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridSection(
          title: 'Certifications',
          columns: widget.columns,
          action: _AddTag(
            tooltip: 'Add a certification',
            onPressed: () => _certificationForm(),
          ),
          children: [
            for (var index = 0; index < profile.certifications.length; index++)
              _ExperienceCard(
                badge: Icons.verified,
                title: profile.certifications[index].title,
                subtitle: profile.certifications[index].provider,
                meta:
                    'Issued ${profile.certifications[index].issued}'
                    '${profile.certifications[index].credentialId.isEmpty ? '' : ' • ID ${profile.certifications[index].credentialId}'}',
                description: profile.certifications[index].description,
                proofUrl: profile.certifications[index].certificateUrl,
                onProofTap: () => _openCertificationProof(
                  profile.certifications[index].certificateUrl,
                ),
                onEdit: () => _certificationForm(index),
                onRemove: () => _removeCertification(index),
              ),
            if (profile.certifications.isEmpty)
              const _EmptyCard('No certifications added yet.'),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        GridSection(
          title: 'Employment work',
          columns: widget.columns,
          action: _AddTag(
            tooltip: 'Add employment work',
            onPressed: () => _employmentForm(),
          ),
          children: [
            for (var index = 0; index < profile.employment.length; index++)
              _ExperienceCard(
                badge: Icons.work_outline,
                title: profile.employment[index].role,
                subtitle: profile.employment[index].company,
                meta: profile.employment[index].period,
                description: profile.employment[index].description,
                onEdit: () => _employmentForm(index),
                onRemove: () => _removeEmployment(index),
              ),
            if (profile.employment.isEmpty)
              const _EmptyCard('No employment added yet.'),
          ],
        ),
      ],
    );
  }
}

/// The start and end of an employment, read from the calendar.
///
/// The route wants real dates and treats an empty end as a job still running,
/// so neither value is typed: a picked date is the only one that can reach it in
/// a form `new Date()` reads.
class _PeriodFields extends StatefulWidget {
  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime? start, DateTime? end) onChanged;

  const _PeriodFields({
    required this.start,
    required this.end,
    required this.onChanged,
  });

  @override
  State<_PeriodFields> createState() => _PeriodFieldsState();
}

class _PeriodFieldsState extends State<_PeriodFields> {
  late final TextEditingController _startText = _textFor(widget.start);
  late final TextEditingController _endText = _textFor(widget.end);
  late DateTime? _start = widget.start;
  late DateTime? _end = widget.end;

  @override
  void dispose() {
    _startText.dispose();
    _endText.dispose();
    super.dispose();
  }

  static TextEditingController _textFor(DateTime? date) =>
      TextEditingController(text: date == null ? '' : dateLabel(date));

  Future<void> _pick({required bool ending}) async {
    final now = DateTime.now();
    final first = DateTime(1970);
    final last = DateTime(now.year + 1, 12, 31);
    // A range cannot end before it starts, so the end picker opens on the start
    // date instead of letting one be chosen.
    final lowerBound = ending ? (_start ?? first) : first;
    final picked = await showDatePicker(
      context: context,
      initialDate: _within(
        ending ? (_end ?? _start ?? now) : (_start ?? now),
        lowerBound,
        last,
      ),
      firstDate: lowerBound,
      lastDate: last,
      helpText: ending
          ? 'End date, or leave it blank if the job is current'
          : 'Start date',
    );
    if (picked == null) return;
    setState(() {
      if (ending) {
        _end = picked;
        _endText.text = dateLabel(picked);
      } else {
        _start = picked;
        _startText.text = dateLabel(picked);
        if (_end != null && _end!.isBefore(picked)) {
          _end = null;
          _endText.text = '';
        }
      }
      widget.onChanged(_start, _end);
    });
  }

  void _clearEnd() {
    setState(() {
      _end = null;
      _endText.text = '';
      widget.onChanged(_start, null);
    });
  }

  static DateTime _within(DateTime date, DateTime first, DateTime last) {
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  Widget _calendarIcon(void Function() onTap) => IconButton(
    tooltip: 'Choose from calendar',
    onPressed: onTap,
    icon: const Icon(
      Icons.calendar_month_outlined,
      size: AppDimensions.iconSm + 2,
      color: AppColors.primary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final start = AppTextField(
      label: 'Start date',
      hint: 'Select date',
      controller: _startText,
      readOnly: true,
      onTap: () => _pick(ending: false),
      suffixIcon: _calendarIcon(() => _pick(ending: false)),
      validator: requiredField,
    );
    final end = AppTextField(
      label: 'End date (leave blank if current)',
      hint: 'Select date',
      controller: _endText,
      readOnly: true,
      onTap: () => _pick(ending: true),
      suffixIcon: _end == null
          ? _calendarIcon(() => _pick(ending: true))
          : IconButton(
              tooltip: 'Clear end date',
              onPressed: _clearEnd,
              icon: const Icon(
                Icons.close,
                size: AppDimensions.iconSm + 2,
                color: AppColors.textHint,
              ),
            ),
    );
    // Two labelled dates do not fit side by side on a phone, and the dialog
    // measures its content with intrinsics, which a LayoutBuilder cannot take
    // part in, so the screen width decides.
    return MediaQuery.sizeOf(context).width >= 560
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: start),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: end),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              start,
              const SizedBox(height: AppDimensions.sm),
              end,
            ],
          );
  }
}

class _AddTag extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _AddTag({required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppTag('Add', icon: Icons.add, highlight: true, onTap: onPressed),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  final IconData badge;
  final String title;
  final String subtitle;
  final String meta;
  final String description;
  final String proofUrl;
  final VoidCallback? onProofTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ExperienceCard({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.description,
    this.proofUrl = '',
    this.onProofTap,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(badge),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit $title',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: AppDimensions.iconSm,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                tooltip: 'Remove $title',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline,
                  size: AppDimensions.iconSm,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (proofUrl.isNotEmpty && onProofTap != null) ...[
            const SizedBox(height: AppDimensions.sm),
            InkWell(
              onTap: onProofTap,
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: AppColors.primary,
                    size: AppDimensions.iconSm,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Expanded(
                    child: Text(
                      'View certification proof',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    color: AppColors.primary,
                    size: AppDimensions.iconSm,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CertificationProofPicker extends StatefulWidget {
  final String proofUrl;
  final void Function(_CertificationProof? proof, bool removeExisting)
  onChanged;

  const _CertificationProofPicker({
    required this.proofUrl,
    required this.onChanged,
  });

  @override
  State<_CertificationProofPicker> createState() =>
      _CertificationProofPickerState();
}

class _CertificationProofPickerState extends State<_CertificationProofPicker> {
  _CertificationProof? _selected;
  bool _removeExisting = false;

  Future<void> _pickProof() async {
    try {
      final files = await FileSelectionService.pick(
        extensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (files.isEmpty) return;
      final file = files.single;
      if (file.bytes.length > 10 * 1024 * 1024) {
        _note('Proof images must be 10 MB or smaller.');
        return;
      }
      setState(() {
        _selected = (
          bytes: file.bytes,
          filename: file.name,
          mimeType: file.mimeType,
        );
        _removeExisting = false;
      });
      widget.onChanged(_selected, false);
    } on PlatformException {
      _note('This device could not open the file picker.');
    } on FormatException catch (error) {
      _note(error.message);
    }
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _removeExisting = false;
    });
    widget.onChanged(null, false);
  }

  void _removeProof() {
    setState(() {
      _selected = null;
      _removeExisting = true;
    });
    widget.onChanged(null, true);
  }

  void _note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final hasExisting = widget.proofUrl.isNotEmpty && !_removeExisting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Certification proof image', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.xs),
        if (selected != null)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: Image.memory(
                  selected.bytes,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  selected.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Remove selected proof image',
                onPressed: _clearSelection,
                icon: const Icon(Icons.close),
              ),
            ],
          )
        else if (hasExisting)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: Image.network(
                  widget.proofUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final failure = await LinkOpener.open(widget.proofUrl);
                    if (failure != null && context.mounted) _note(failure);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View current proof'),
                ),
              ),
              IconButton(
                tooltip: 'Remove certification proof',
                onPressed: _removeProof,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          )
        else
          Row(
            children: [
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: _pickProof,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text(
                    'Upload proof image',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_removeExisting)
                TextButton(
                  onPressed: () {
                    setState(() => _removeExisting = false);
                    widget.onChanged(null, false);
                  },
                  child: const Text('Undo'),
                ),
            ],
          ),
        if (hasExisting || selected != null)
          TextButton.icon(
            onPressed: _pickProof,
            icon: const Icon(Icons.change_circle_outlined),
            label: const Text('Replace image'),
          ),
        Text(
          'JPG, PNG or WEBP, up to 10 MB.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard(this.text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.md,
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
      ),
    );
  }
}
