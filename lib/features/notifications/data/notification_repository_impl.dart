import '../domain/entities/app_notification.dart';
import '../domain/repositories/notification_repository.dart';
import 'notification_api.dart';
import 'push_notification_service.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationApi _api;
  final PushNotificationService _pushService;

  const NotificationRepositoryImpl(this._api, this._pushService);

  @override
  Future<void> markAsRead(String notificationId) => _api.markAsRead(notificationId);

  @override
  Future<void> requestPermissions() => _pushService.requestPermissions();

  @override
  Future<void> syncPushToken() => _pushService.syncCurrentToken();

  @override
  Stream<List<AppNotification>> watchNotifications() => _api.watchNotifications();
}
