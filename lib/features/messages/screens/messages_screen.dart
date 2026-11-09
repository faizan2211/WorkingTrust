import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_tag.dart';
import '../../notifications/controller/notification_controller.dart';
import '../controller/messages_controller.dart';
import '../controller/project_chat_controller.dart';
import '../widgets/project_chat_view.dart';

/// The signed-in account's authorized project conversations.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessagesController _controller = MessagesController();
  final TextEditingController _search = TextEditingController();

  /// The thread on screen, with the row it belongs to. One controller per
  /// opened project, disposed as soon as another is chosen.
  ProjectChatController? _chat;
  ConversationRow? _opened;
  String _notificationSnapshot = '';

  @override
  void initState() {
    super.initState();
    _notificationSnapshot = _currentNotificationSnapshot();
    NotificationController.instance.addListener(_refreshAfterNotification);
    _controller.load();
  }

  @override
  void dispose() {
    NotificationController.instance.removeListener(_refreshAfterNotification);
    _search.dispose();
    _controller.dispose();
    _chat?.dispose();
    super.dispose();
  }

  void _refreshAfterNotification() {
    final snapshot = _currentNotificationSnapshot();
    if (snapshot == _notificationSnapshot) return;
    _notificationSnapshot = snapshot;
    _controller.load(silent: true);
  }

  String _currentNotificationSnapshot() => NotificationController
      .instance
      .notifications
      .map((notification) => '${notification.id}:${notification.readAt}')
      .join('|');

  void _open(ConversationRow conversation) {
    _chat?.dispose();
    final chat = ProjectChatController(conversation.taskId);
    setState(() {
      _opened = conversation;
      _chat = chat;
    });
    chat.open();
  }

  void _close() {
    _chat?.dispose();
    setState(() {
      _opened = null;
      _chat = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final conversations = _controller.conversations;
        final chat = _chat;
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A phone has no room for both panes, so the thread replaces the
              // list until it is closed again; a back control only makes sense
              // in that single-pane mode.
              final narrow = constraints.maxWidth < 640;
              final list = _ConversationList(
                controller: _controller,
                search: _search,
                conversations: conversations,
                selected: _opened,
                onOpen: _open,
                onRefresh: () => _controller.load(silent: true),
                status: _controller.status,
                errorMessage: _controller.errorMessage,
              );
              final padded = EdgeInsets.all(AppDimensions.md);
              if (narrow) {
                if (chat != null) {
                  return Padding(
                    padding: padded,
                    child: _Panel(
                      child: ProjectChatView(
                        key: ValueKey('chat-${chat.taskId}'),
                        controller: chat,
                        showBack: true,
                        onBack: _close,
                      ),
                    ),
                  );
                }
                return Padding(padding: padded, child: list);
              }
              return Padding(
                padding: padded,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 280, child: list),
                    const SizedBox(width: AppDimensions.md),
                    Expanded(
                      child: chat == null
                          ? const _PickAProject()
                          : _Panel(
                              child: ProjectChatView(
                                key: ValueKey('chat-${chat.taskId}'),
                                controller: chat,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  final MessagesController controller;
  final TextEditingController search;
  final List<ConversationRow> conversations;
  final ConversationRow? selected;
  final ValueChanged<ConversationRow> onOpen;
  final Future<void> Function() onRefresh;
  final ConversationListStatus status;
  final String errorMessage;

  const _ConversationList({
    required this.controller,
    required this.search,
    required this.conversations,
    required this.selected,
    required this.onOpen,
    required this.onRefresh,
    required this.status,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Messages', style: AppTextStyles.heading2),
        const SizedBox(height: AppDimensions.md),
        TextField(
          controller: search,
          onChanged: controller.setQuery,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search here...',
            hintStyle: const TextStyle(color: AppColors.textHint),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: [
            for (
              int index = 0;
              index < MessagesController.filters.length;
              index++
            )
              AppTag(
                MessagesController.filters[index],
                selected: controller.selectedFilter == index,
                onTap: () => controller.setFilter(index),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        Expanded(
          child: conversations.isEmpty
              ? switch (status) {
                  ConversationListStatus.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  ConversationListStatus.error => _ConversationLoadError(
                    message: errorMessage,
                    onRetry: onRefresh,
                  ),
                  _ => const _NoConversations(),
                }
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _ConversationTile(
                        conversation: conversation,
                        selected: conversation == selected,
                        onTap: () => onOpen(conversation),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ConversationLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ConversationLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: AppDimensions.sm),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _NoConversations extends StatelessWidget {
  const _NoConversations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.forum_outlined,
              size: AppDimensions.iconLg,
              color: AppColors.textHint,
            ),
            SizedBox(height: AppDimensions.sm),
            Text(
              'No project conversations yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge,
            ),
            SizedBox(height: AppDimensions.xs),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationRow conversation;
  final bool selected;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.35)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.sm + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radius),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                AppAvatar(name: conversation.name, radius: 20),
                const SizedBox(width: AppDimensions.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge,
                      ),
                      Text(
                        conversation.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(conversation.stamp, style: AppTextStyles.caption),
                    if (conversation.unread)
                      Container(
                        margin: const EdgeInsets.only(top: AppDimensions.xs),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
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

class _PickAProject extends StatelessWidget {
  const _PickAProject();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Choose a project to read its conversation.',
        style: AppTextStyles.bodySmall,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
