import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/notification_api.dart';
import '../../data/notification_repository_impl.dart';
import '../../data/push_notification_service.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationState {
  final bool loading;
  final String? error;
  final List<AppNotification> notifications;

  const NotificationState({
    this.loading = false,
    this.error,
    this.notifications = const [],
  });

  static const _errorSentinel = Object();

  NotificationState copyWith({
    bool? loading,
    Object? error = _errorSentinel,
    List<AppNotification>? notifications,
  }) {
    return NotificationState(
      loading: loading ?? this.loading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      notifications: notifications ?? this.notifications,
    );
  }
}

class NotificationController extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  StreamSubscription<List<AppNotification>>? _subscription;

  NotificationController(this._repository) : super(const NotificationState()) {
    _subscription = _repository.watchNotifications().listen(
      (items) {
        state = state.copyWith(
          notifications: items,
          loading: false,
          error: null,
        );
      },
      onError: (Object error) {
        state = state.copyWith(loading: false, error: mapAppError(error));
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
    } catch (error) {
      state = state.copyWith(error: mapAppError(error));
    }
  }

  Future<void> markAllAsRead() async {
    final unreadNotifications = state.notifications
        .where((notification) => !notification.isRead)
        .toList();
    if (unreadNotifications.isEmpty) {
      return;
    }

    try {
      await Future.wait(
        unreadNotifications.map(
          (notification) => _repository.markAsRead(notification.id),
        ),
      );
    } catch (error) {
      state = state.copyWith(error: mapAppError(error));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
  );
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
    ref.watch(firebaseMessagingProvider),
  );
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    ref.watch(notificationApiProvider),
    ref.watch(pushNotificationServiceProvider),
  );
});

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
      return NotificationController(ref.watch(notificationRepositoryProvider));
    });
