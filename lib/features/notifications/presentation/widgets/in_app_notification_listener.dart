import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_notification.dart';
import '../controllers/notification_controller.dart';

class InAppNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const InAppNotificationListener({super.key, required this.child});

  @override
  ConsumerState<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState
    extends ConsumerState<InAppNotificationListener> {
  bool _initialized = false;
  Set<String> _knownNotificationIds = <String>{};
  ProviderSubscription<NotificationState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<NotificationState>(
      notificationControllerProvider,
      (previous, next) {
        final currentIds = next.notifications.map((item) => item.id).toSet();
        if (!_initialized) {
          _initialized = true;
          _knownNotificationIds = currentIds;
          return;
        }

        final newUnread = next.notifications.where(
          (item) => !item.isRead && !_knownNotificationIds.contains(item.id),
        );
        _knownNotificationIds = currentIds;

        if (newUnread.isEmpty || !mounted) {
          return;
        }

        final latest = newUnread.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _showBanner(context, ref, latest);
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _showBanner(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.title),
              const SizedBox(height: 4),
              Text(notification.body),
            ],
          ),
          action: notification.targetRoute.isEmpty
              ? null
              : SnackBarAction(
                  label: 'Открыть',
                  onPressed: () async {
                    await ref
                        .read(notificationControllerProvider.notifier)
                        .markAsRead(notification.id);
                    if (context.mounted) {
                      _openNotificationRoute(context, notification.targetRoute);
                    }
                  },
                ),
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
