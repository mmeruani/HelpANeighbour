import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/features/notifications/domain/entities/app_notification.dart';
import 'package:help_a_neighbour/features/notifications/domain/repositories/notification_repository.dart';
import 'package:help_a_neighbour/features/notifications/presentation/controllers/notification_controller.dart';

void main() {
  group('NotificationController', () {
    test('listens to notifications stream', () async {
      final repository = _FakeNotificationRepository();
      final controller = NotificationController(repository);
      addTearDown(controller.dispose);

      repository.emit([
        _notification(id: 'n1', isRead: false),
        _notification(id: 'n2', isRead: true),
      ]);
      await pumpEventQueue();

      expect(controller.state.notifications, hasLength(2));
      expect(controller.state.error, isNull);
      expect(controller.state.loading, isFalse);
    });

    test('markAllAsRead marks only unread notifications', () async {
      final repository = _FakeNotificationRepository();
      final controller = NotificationController(repository);
      addTearDown(controller.dispose);

      repository.emit([
        _notification(id: 'unread-1', isRead: false),
        _notification(id: 'read-1', isRead: true),
        _notification(id: 'unread-2', isRead: false),
      ]);
      await pumpEventQueue();

      await controller.markAllAsRead();

      expect(repository.markedAsReadIds, ['unread-1', 'unread-2']);
    });

    test('markAsRead maps repository failures into state error', () async {
      final repository = _FakeNotificationRepository(
        markAsReadError: Exception('permission-denied'),
      );
      final controller = NotificationController(repository);
      addTearDown(controller.dispose);

      await controller.markAsRead('n1');

      expect(
        controller.state.error,
        'Недостаточно прав для выполнения этого действия.',
      );
    });
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  final Object? markAsReadError;
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final markedAsReadIds = <String>[];

  _FakeNotificationRepository({this.markAsReadError});

  void emit(List<AppNotification> notifications) {
    _controller.add(notifications);
  }

  @override
  Stream<List<AppNotification>> watchNotifications() => _controller.stream;

  @override
  Future<void> markAsRead(String notificationId) async {
    final error = markAsReadError;
    if (error != null) {
      throw error;
    }
    markedAsReadIds.add(notificationId);
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
    body: 'Текст',
    targetRoute: '/profile',
    isRead: isRead,
    createdAt: DateTime(2026, 5, 6, 12),
  );
}
