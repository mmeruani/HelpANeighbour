import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications();
  Future<void> markAsRead(String notificationId);
  Future<void> requestPermissions();
  Future<void> syncPushToken();
}
