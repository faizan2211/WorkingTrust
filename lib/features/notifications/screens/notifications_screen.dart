import 'package:flutter/material.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_tag.dart';
import '../../../core/widgets/module_app_bar.dart';
import '../controller/notification_controller.dart';
import '../models/notification_model.dart';
import '../services/fcm_push_service.dart';

/// The real `GET /api/notifications` feed for the signed-in session.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationController _controller = NotificationController.instance;

  @override
  void initState() {
    super.initState();
    // Opening the screen always re-reads, so a row created seconds ago shows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refresh();
    });
  }

  void _showFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _controller.errorMessage.isEmpty
              ? 'Could not update this notification.'
              : _controller.errorMessage,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onTapNotification(NotificationModel item) async {
    final changed = await _controller.openNotification(item);
    if (!changed) _showFailure();
    if (!mounted) return;

    final destination = FcmPushService.destinationFor({
      'type': item.type ?? '',
      'href': item.href ?? '',
    });
    if (destination.route == RouteNames.notifications) return;
    await Navigator.of(context)
        .pushNamed(destination.route, arguments: destination.arguments);
  }

  Future<void> _onDismiss(NotificationModel item) async {
    final changed = await _controller.dismiss(item.id);
    if (!changed) _showFailure();
  }

  Future<void> _onMarkAllRead() async {
    final changed = await _controller.markAllRead();
    if (!changed) _showFailure();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModuleAppBar(
        title: 'Notifications',
        subtitle: 'Alerts & reminders',
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (_controller.status != NotificationStatus.ready ||
                  !_controller.hasUnread) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Mark all read',
                onPressed: _onMarkAllRead,
                icon: const Icon(Icons.done_all),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.status) {
      case NotificationStatus.loading:
        return const Center(child: AppLoader());
      case NotificationStatus.error:
        return AppErrorWidget(
          message: _controller.errorMessage.isEmpty
              ? 'Could not load your notifications.'
              : _controller.errorMessage,
          onRetry: () => _controller.refresh(),
        );
      case NotificationStatus.empty:
        return const AppEmptyState(
          message: 'No notifications yet.',
          icon: Icons.notifications_none,
        );
      case NotificationStatus.idle:
      case NotificationStatus.ready:
        final items = _controller.notifications;
        if (items.isEmpty) {
          // A lost session is worth stating plainly; retrying from here cannot
          // help, so this error carries no button.
          if (_controller.errorMessage.isNotEmpty) {
            return AppErrorWidget(message: _controller.errorMessage);
          }
          return const AppEmptyState(
            message: 'No notifications yet.',
            icon: Icons.notifications_none,
          );
        }
        return RefreshIndicator(
          onRefresh: () => _controller.refresh(silent: true),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.md),
            itemCount: items.length,
            separatorBuilder: (context, _) =>
                const SizedBox(height: AppDimensions.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _NotificationRow(
                    key: ValueKey('notification-${item.id}'),
                    notification: item,
                    onTap: () => _onTapNotification(item),
                    onDismiss: () => _onDismiss(item),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationRow({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // An unread row is marked by a dot in the accent colour plus a bolder
    // title; read rows settle back to the same surface as everything else.
    final unread = !notification.isRead;
    return AppCard(
      onTap: onTap,
      background: unread ? AppColors.surface : AppColors.surfaceVariant,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            height: 22,
            child: unread
                ? Container(
                    key: ValueKey('unread-dot-${notification.id}'),
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  notification.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    // The tag takes every leftover pixel so a long backend
                    // type ellipsizes instead of pushing the timestamp off a
                    // narrow phone's card.
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (notification.type != null)
                            Flexible(
                              child: AppTag(_prettyType(notification.type!)),
                            ),
                          if (notification.hasDestination) ...[
                            const SizedBox(width: AppDimensions.sm),
                            Icon(
                              Icons.open_in_new,
                              size: AppDimensions.iconSm,
                              color: AppColors.textHint,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      _timeAgo(notification.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            iconSize: AppDimensions.iconSm,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: const Icon(Icons.close, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  /// `BID_AWARDED` reads better as `Bid awarded`; the value itself is the
  /// backend's, only the separators change.
  static String _prettyType(String type) {
    final words = type.replaceAll('_', ' ').trim().toLowerCase();
    if (words.isEmpty) return type;
    return words[0].toUpperCase() + words.substring(1);
  }

  static String _timeAgo(DateTime moment, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final delta = reference.difference(moment);
    if (delta.isNegative) return 'just now';
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} h ago';
    if (delta.inDays < 7) return '${delta.inDays} d ago';
    final local = moment.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
