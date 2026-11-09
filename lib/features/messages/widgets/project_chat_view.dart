import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_tag.dart';
import '../controller/project_chat_controller.dart';
import '../models/chat_stamps.dart';
import '../models/project_chat.dart';

/// One project conversation: the server's rows, a composer, and nothing local.
///
/// The backend answers oldest-first, and that order is what renders — the list
/// is built upside down so the newest row sits at the bottom edge and the view
/// never has to scroll to it after a send.
class ProjectChatView extends StatefulWidget {
  final ProjectChatController controller;

  /// The narrow Messages pane swaps this view in over the list, so it carries
  /// its own back button instead of an app bar.
  final bool showBack;
  final VoidCallback? onBack;

  const ProjectChatView({
    super.key,
    required this.controller,
    this.showBack = false,
    this.onBack,
  });

  @override
  State<ProjectChatView> createState() => _ProjectChatViewState();
}

class _ProjectChatViewState extends State<ProjectChatView> {
  final TextEditingController _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _draft.text;
    // Only the server's 201 empties the field. A refusal leaves the words where
    // the user can still fix them.
    if (await widget.controller.send(text)) _draft.clear();
  }

  Future<void> _openAttachment(String url) async {
    final failure = await LinkOpener.open(url);
    if (failure == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              controller: controller,
              showBack: widget.showBack,
              onBack: widget.onBack,
            ),
            const Divider(height: 1, color: AppColors.divider),
            if (controller.isFlagged)
              const _Notice(
                icon: Icons.flag_outlined,
                text: 'This conversation is flagged for review.',
              ),
            if (controller.isClosed)
              const _Notice(
                icon: Icons.lock_outline,
                text: 'This conversation is closed.',
              ),
            Expanded(
              child: _Body(controller: controller, onOpen: _openAttachment),
            ),
            _Composer(controller: controller, draft: _draft, onSend: _send),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ProjectChatController controller;
  final bool showBack;
  final VoidCallback? onBack;

  const _Header({
    required this.controller,
    required this.showBack,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_back),
            ),
          AppAvatar(
            name: controller.otherName,
            imageUrl: controller.otherAvatarUrl,
            radius: 20,
          ),
          const SizedBox(width: AppDimensions.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.otherName, style: AppTextStyles.labelLarge),
                // The old pane showed presence here; the backend reports no
                // presence, so the project the thread belongs to is the truth.
                Text(
                  controller.projectTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ProjectChatController controller;
  final Future<void> Function(String url) onOpen;

  const _Body({required this.controller, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ChatStatus.loading:
        return const AppLoader();
      case ChatStatus.error:
        return AppErrorWidget(
          message: controller.errorMessage.isEmpty
              ? 'Could not load this conversation.'
              : controller.errorMessage,
          onRetry: () => controller.load(),
        );
      case ChatStatus.idle:
      case ChatStatus.ready:
      case ChatStatus.empty:
        if (controller.messages.isEmpty) {
          // A thread the server opened that nobody has written in is a real
          // state, so it says so plainly rather than showing an empty column.
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.lg),
              child: Text(
                'No messages yet on this project.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => controller.load(silent: true),
          child: ListView(
            reverse: true,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.md),
            children: _rows(controller, onOpen),
          ),
        );
    }
  }

  /// Newest first in the list's own order, which rendered upside down puts the
  /// newest bubble at the bottom and each day divider above that day's rows.
  static List<Widget> _rows(
    ProjectChatController controller,
    Future<void> Function(String url) onOpen,
  ) {
    final children = <Widget>[];
    String? day;
    for (final message in controller.messages.reversed) {
      final messageDay = chatDayLabel(message.createdAt);
      if (day != null && messageDay != day) {
        children.add(_DayDivider(day: day));
      }
      children.add(
        _Bubble(
          message: message,
          mine: controller.isMine(message),
          onOpen: onOpen,
        ),
      );
      day = messageDay;
    }
    if (day != null) children.add(_DayDivider(day: day));
    return children;
  }
}

class _DayDivider extends StatelessWidget {
  final String day;

  const _DayDivider({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
      child: Center(child: AppTag(day, highlight: true)),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final Future<void> Function(String url) onOpen;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachmentUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // The other side is named: a task's client has no login, so several
          // people can write from it and the backend labels each row.
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppDimensions.xs,
                right: AppDimensions.sm,
              ),
              child: Text(message.displayName, style: AppTextStyles.caption),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: mine ? AppColors.accent : AppColors.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppDimensions.radius),
                topRight: const Radius.circular(AppDimensions.radius),
                bottomLeft: Radius.circular(mine ? AppDimensions.radius : 4),
                bottomRight: Radius.circular(mine ? 4 : AppDimensions.radius),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.body.isNotEmpty)
                  Text(message.body, style: AppTextStyles.bodyMedium),
                if (attachment != null)
                  Padding(
                    padding: EdgeInsets.only(
                      top: message.body.isEmpty ? 0 : AppDimensions.sm,
                    ),
                    child: GestureDetector(
                      onTap: () => onOpen(attachment),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.attach_file,
                            size: AppDimensions.iconSm,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              attachment,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(chatTimeLabel(message.createdAt), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final ProjectChatController controller;
  final TextEditingController draft;
  final Future<void> Function() onSend;

  const _Composer({
    required this.controller,
    required this.draft,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // Until the server has answered for this thread there is nothing to write
    // into, and a thread that failed to load gets its retry from the body.
    if (!controller.isLoaded) return const SizedBox.shrink();

    final error = controller.errorMessage;
    return Column(
      children: [
        if (error.isNotEmpty && !controller.isSending)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.xs,
              AppDimensions.md,
              0,
            ),
            child: Text(
              error,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft,
                  enabled: controller.canReply,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(controller.bodyLimit),
                  ],
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    // Only a closed thread loses the hint: a send in flight
                    // disables the field without changing what it asks for.
                    hintText: controller.isClosed
                        ? 'This conversation is closed'
                        : 'Write a message',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.md,
                      vertical: AppDimensions.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXl,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXl,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXl,
                      ),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Send',
                  // Disabled while a send is outstanding, so a keen thumb
                  // cannot post the same line twice.
                  onPressed: controller.canReply ? onSend : null,
                  icon: Icon(
                    Icons.send_rounded,
                    color: AppColors.textOnPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        0,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppDimensions.iconSm, color: AppColors.warning),
          const SizedBox(width: AppDimensions.xs),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
