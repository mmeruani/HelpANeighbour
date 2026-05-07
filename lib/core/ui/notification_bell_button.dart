import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/controllers/notification_controller.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref
        .watch(notificationControllerProvider)
        .notifications
        .where((notification) => !notification.isRead)
        .length;

    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
