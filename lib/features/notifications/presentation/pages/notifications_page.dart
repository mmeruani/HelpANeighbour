import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_sections.dart';
import '../controllers/notification_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _markingAllRead = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final hasUnread = state.notifications.any(
      (notification) => !notification.isRead,
    );

    if (hasUnread && !_markingAllRead) {
      _markingAllRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(notificationControllerProvider.notifier).markAllAsRead();
        if (mounted) {
          setState(() => _markingAllRead = false);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppPageHeader(
            title: 'Уведомления',
            subtitle:
                'Все важные события по вашим запросам, отзывам и другим действиям собраны в одном месте.',
          ),
          const SizedBox(height: 18),
          if (state.error != null) ...[
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (state.notifications.isEmpty)
            const AppSectionCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Уведомлений пока нет')),
              ),
            )
          else
            ...state.notifications.map(
              (notification) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      await ref
                          .read(notificationControllerProvider.notifier)
                          .markAsRead(notification.id);
                      if (context.mounted &&
                          notification.targetRoute.isNotEmpty) {
                        _openNotificationRoute(
                          context,
                          notification.targetRoute,
                        );
                      }
                    },
                    leading: Icon(
                      notification.isRead
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    title: Text(notification.title),
                    subtitle: Text(
                      '${notification.body}\n${_formatNotificationDate(notification.createdAt)}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _openNotificationRoute(BuildContext context, String route) {
  try {
    context.push(route);
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Этот раздел уведомления больше недоступен'),
      ),
    );
  }
}

String _formatNotificationDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}
