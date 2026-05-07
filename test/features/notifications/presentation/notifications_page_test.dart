import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:help_a_neighbour/core/ui/notification_bell_button.dart';
import 'package:help_a_neighbour/features/notifications/domain/entities/app_notification.dart';
import 'package:help_a_neighbour/features/notifications/domain/repositories/notification_repository.dart';
import 'package:help_a_neighbour/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:help_a_neighbour/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  group('NotificationsPage', () {
    testWidgets('marks unread notifications as read after opening page', (
      tester,
    ) async {
      final repository = _FakeNotificationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NotificationsPage()),
        ),
      );

      repository.emit([
        _notification(id: 'n1', isRead: false),
        _notification(id: 'n2', isRead: true),
      ]);
      await tester.pumpAndSettle();

      expect(repository.markedAsReadIds, ['n1']);
    });

    testWidgets('shows empty state when there are no notifications', (
      tester,
    ) async {
      final repository = _FakeNotificationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: NotificationsPage()),
        ),
      );

      repository.emit([]);
      await tester.pumpAndSettle();

      expect(find.text('Уведомлений пока нет'), findsOneWidget);
    });
  });

  group('NotificationBellButton', () {
    testWidgets('shows badge with unread notifications count', (tester) async {
      final repository = _FakeNotificationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: const [NotificationBellButton()]),
            ),
          ),
        ),
      );

      repository.emit([
        _notification(id: 'n1', isRead: false),
        _notification(id: 'n2', isRead: false),
        _notification(id: 'n3', isRead: true),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('hides badge when all notifications are read', (tester) async {
      final repository = _FakeNotificationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: const [NotificationBellButton()]),
            ),
          ),
        ),
      );

      repository.emit([
        _notification(id: 'n1', isRead: true),
        _notification(id: 'n2', isRead: true),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
    });
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final markedAsReadIds = <String>[];
  List<AppNotification> _notifications = const [];

  void emit(List<AppNotification> notifications) {
    _notifications = notifications;
    _controller.add(_notifications);
  }

  @override
  Stream<List<AppNotification>> watchNotifications() => _controller.stream;

  @override
  Future<void> markAsRead(String notificationId) async {
    markedAsReadIds.add(notificationId);
    _notifications = _notifications.map((notification) {
      if (notification.id != notificationId) {
        return notification;
      }
      return AppNotification(
        id: notification.id,
        recipientUserId: notification.recipientUserId,
        title: notification.title,
        body: notification.body,
        targetRoute: notification.targetRoute,
        isRead: true,
        createdAt: notification.createdAt,
      );
    }).toList();
    _controller.add(_notifications);
  }

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> syncPushToken() async {}
}

AppNotification _notification({required String id, required bool isRead}) {
  return AppNotification(
    id: id,
    recipientUserId: 'user-1',
    title: 'Уведомление',
    body: 'Текст уведомления',
    targetRoute: '/profile',
    isRead: isRead,
    createdAt: DateTime(2026, 5, 6, 13),
  );
}
