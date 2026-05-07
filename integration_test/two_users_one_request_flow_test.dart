import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:help_a_neighbour/app/theme.dart';
import 'package:help_a_neighbour/features/auth/presentation/controllers/auth_controller.dart';
import 'package:help_a_neighbour/features/notifications/domain/entities/app_notification.dart';
import 'package:help_a_neighbour/features/notifications/domain/repositories/notification_repository.dart';
import 'package:help_a_neighbour/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:help_a_neighbour/features/notifications/presentation/pages/notifications_page.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_enums.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_response.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/service_request.dart';
import 'package:help_a_neighbour/features/requests/domain/repositories/request_repository.dart';
import 'package:help_a_neighbour/features/requests/presentation/controllers/request_controller.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/community_requests_page.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/create_request_page.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/request_details_page.dart';
import 'package:help_a_neighbour/features/reviews/domain/entities/review.dart';
import 'package:help_a_neighbour/features/reviews/domain/repositories/review_repository.dart';
import 'package:help_a_neighbour/features/reviews/presentation/controllers/review_controller.dart';
import 'package:help_a_neighbour/features/reviews/presentation/pages/leave_review_page.dart';
import 'package:help_a_neighbour/features/reviews/presentation/pages/user_reviews_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'two users complete one request with response, notifications and review',
    (tester) async {
      final backend = _FlowBackend();

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.customerId,
        initialLocation: '/communities/community-1/requests',
      );

      await tester.tap(find.text('Создать запрос'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название запроса'),
        'съездить в магазин',
      );
      await tester.tap(find.text('Выберите категорию из списка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Покупки и доставка').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Описание'),
        'купить хлеб',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Контактные данные для связи'),
        '89166187077',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Адрес выполнения (необязательно)'),
        'дом 13',
      );
      await _dismissKeyboard(tester);
      await _tapButton(tester, 'Создать');
      await tester.pumpAndSettle();

      expect(find.text('съездить в магазин'), findsOneWidget);
      expect(find.text('Откликов: 0'), findsOneWidget);

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.executorId,
        initialLocation: '/communities/community-1/requests',
      );

      await tester.tap(find.text('съездить в магазин'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Откликнуться');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'готов выполнить сегодня');
      await _dismissKeyboard(tester);
      await _tapButton(tester, 'Отправить');
      await tester.pumpAndSettle();

      expect(find.text('Отклик отправлен'), findsOneWidget);
      expect(backend.request.responsesCount, 1);

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.customerId,
        initialLocation: '/notifications',
      );

      expect(find.text('Новый отклик на ваш запрос'), findsOneWidget);
      expect(find.textContaining('съездить в магазин'), findsOneWidget);

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.customerId,
        initialLocation: '/requests/request-1',
      );

      await _tapButton(tester, 'Выбрать');
      await tester.pumpAndSettle();

      expect(find.text('Исполнитель выбран'), findsOneWidget);
      expect(backend.request.status, RequestStatus.inProgress);
      expect(backend.request.executorId, _FlowBackend.executorId);

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.executorId,
        initialLocation: '/requests/request-1',
      );

      await _tapButton(tester, 'Отметить как выполненный');
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Подтвердить');
      await tester.pumpAndSettle();

      expect(
        backend.request.status,
        RequestStatus.awaitingCustomerConfirmation,
      );

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.customerId,
        initialLocation: '/requests/request-1',
      );

      await _tapButton(tester, 'Подтвердить выполнение');
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Завершить');
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Текст отзыва'),
        'отлично помог',
      );
      await _dismissKeyboard(tester);
      await _tapButton(tester, 'Сохранить отзыв');
      await tester.pumpAndSettle();

      expect(backend.request.status, RequestStatus.completed);
      expect(backend.executorRating, 5);
      expect(backend.executorReviewsCount, 1);

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.executorId,
        initialLocation: '/notifications',
      );

      expect(find.text('Вас выбрали исполнителем'), findsOneWidget);
      expect(find.text('Услуга завершена заказчиком'), findsOneWidget);
      expect(find.text('Вы получили новый отзыв'), findsOneWidget);

      await _pumpFlowApp(
        tester,
        backend: backend,
        currentUserId: _FlowBackend.customerId,
        initialLocation: '/profile/reviews/${_FlowBackend.executorId}',
      );

      expect(find.text('Общий рейтинг'), findsOneWidget);
      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('Отзывов'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('отлично помог'), findsOneWidget);
    },
  );
}

Future<void> _dismissKeyboard(WidgetTester tester) async {
  tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String text) async {
  final button = find
      .ancestor(
        of: find.text(text),
        matching: find.bySubtype<ButtonStyleButton>(),
      )
      .last;
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

Future<void> _pumpFlowApp(
  WidgetTester tester, {
  required _FlowBackend backend,
  required String currentUserId,
  required String initialLocation,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/communities/:communityId/requests',
        builder: (context, state) => CommunityRequestsPage(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/communities/:communityId/requests/create',
        builder: (context, state) => CreateRequestPage(
          communityId: state.pathParameters['communityId']!,
        ),
      ),
      GoRoute(
        path: '/requests/:requestId',
        builder: (context, state) =>
            RequestDetailsPage(requestId: state.pathParameters['requestId']!),
      ),
      GoRoute(
        path: '/requests/:requestId/review/:executorId',
        builder: (context, state) => LeaveReviewPage(
          requestId: state.pathParameters['requestId']!,
          executorId: state.pathParameters['executorId']!,
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/profile/reviews/:userId',
        builder: (context, state) =>
            UserReviewsPage(userId: state.pathParameters['userId']!),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(currentUserId),
        requestRepositoryProvider.overrideWithValue(
          _FlowRequestRepository(backend, currentUserId),
        ),
        notificationRepositoryProvider.overrideWithValue(
          _FlowNotificationRepository(backend, currentUserId),
        ),
        reviewRepositoryProvider.overrideWithValue(
          _FlowReviewRepository(backend, currentUserId),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FlowBackend {
  static const customerId = 'customer-1';
  static const executorId = 'executor-1';

  final Map<String, List<AppNotification>> notificationsByUser = {
    customerId: [],
    executorId: [],
  };
  final List<RequestResponse> responses = [];
  final List<Review> reviews = [];

  ServiceRequest? _request;
  double executorRating = 0;
  int executorReviewsCount = 0;
  int _requestSequence = 0;
  int _notificationSequence = 0;

  ServiceRequest get request => _request!;

  ServiceRequest createRequest({
    required String communityId,
    required String title,
    required String category,
    required String description,
    required RequestUrgency urgency,
    required RewardType rewardType,
    int? rewardAmount,
    String? address,
    required String contactDetails,
  }) {
    _requestSequence += 1;
    final now = DateTime(2026, 5, 6, 12, _requestSequence);
    _request = ServiceRequest(
      id: 'request-1',
      communityId: communityId,
      communityName: 'улица Народного Ополчения',
      customerId: customerId,
      customerName: 'Мария Медведская',
      customerAvatarUrl: null,
      customerRating: 0,
      customerReviewsCount: 0,
      executorId: null,
      executorName: null,
      executorAvatarUrl: null,
      executorRating: null,
      executorReviewsCount: 0,
      title: title,
      category: category,
      description: description,
      urgency: urgency,
      desiredExecutionAt: DateTime(2026, 5, 6, 18),
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      address: address,
      contactDetails: contactDetails,
      status: RequestStatus.active,
      responsesCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    return request;
  }

  void addResponse(String comment) {
    if (responses.any((response) => response.executorId == executorId)) {
      throw StateError('already-responded');
    }
    responses.add(
      RequestResponse(
        id: 'response-1',
        requestId: request.id,
        executorId: executorId,
        executorName: 'Исполнитель',
        executorAvatarUrl: null,
        executorRating: executorRating,
        executorReviewsCount: executorReviewsCount,
        comment: comment,
        createdAt: DateTime(2026, 5, 6, 12, 10),
      ),
    );
    _request = _copyRequest(responsesCount: responses.length);
    addNotification(
      recipientUserId: customerId,
      title: 'Новый отклик на ваш запрос',
      body: request.title,
      targetRoute: '/requests/${request.id}',
    );
  }

  void selectExecutor(String executorId) {
    _request = _copyRequest(
      executorId: executorId,
      executorName: 'Исполнитель',
      executorRating: executorRating,
      executorReviewsCount: executorReviewsCount,
      status: RequestStatus.inProgress,
    );
    addNotification(
      recipientUserId: executorId,
      title: 'Вас выбрали исполнителем',
      body: request.title,
      targetRoute: '/requests/${request.id}',
    );
  }

  void markCompletedByExecutor() {
    _request = _copyRequest(status: RequestStatus.awaitingCustomerConfirmation);
    addNotification(
      recipientUserId: customerId,
      title: 'Исполнитель отметил услугу как выполненную',
      body: request.title,
      targetRoute: '/requests/${request.id}',
    );
  }

  void confirmCompletionByCustomer() {
    _request = _copyRequest(status: RequestStatus.completed);
    addNotification(
      recipientUserId: executorId,
      title: 'Услуга завершена заказчиком',
      body: request.title,
      targetRoute: '/requests/${request.id}',
    );
  }

  void leaveReview({
    required String customerId,
    required String executorId,
    required int rating,
    required String text,
  }) {
    reviews.add(
      Review(
        id: 'review-1',
        requestId: request.id,
        customerId: customerId,
        customerName: 'Мария Медведская',
        customerAvatarUrl: null,
        executorId: executorId,
        rating: rating,
        text: text,
        createdAt: DateTime(2026, 5, 6, 12, 30),
      ),
    );
    executorRating = rating.toDouble();
    executorReviewsCount = reviews.length;
    _request = _copyRequest(
      executorRating: executorRating,
      executorReviewsCount: executorReviewsCount,
    );
    addNotification(
      recipientUserId: executorId,
      title: 'Вы получили новый отзыв',
      body: 'Оценка: $rating/5',
      targetRoute: '/profile/reviews/$executorId',
    );
  }

  void addNotification({
    required String recipientUserId,
    required String title,
    required String body,
    required String targetRoute,
  }) {
    _notificationSequence += 1;
    notificationsByUser
        .putIfAbsent(recipientUserId, () => [])
        .add(
          AppNotification(
            id: 'notification-$_notificationSequence',
            recipientUserId: recipientUserId,
            title: title,
            body: body,
            targetRoute: targetRoute,
            isRead: false,
            createdAt: DateTime(2026, 5, 6, 13, _notificationSequence),
          ),
        );
  }

  ServiceRequest _copyRequest({
    String? executorId,
    String? executorName,
    double? executorRating,
    int? executorReviewsCount,
    RequestStatus? status,
    int? responsesCount,
  }) {
    final previous = request;
    return ServiceRequest(
      id: previous.id,
      communityId: previous.communityId,
      communityName: previous.communityName,
      customerId: previous.customerId,
      customerName: previous.customerName,
      customerAvatarUrl: previous.customerAvatarUrl,
      customerRating: previous.customerRating,
      customerReviewsCount: previous.customerReviewsCount,
      executorId: executorId ?? previous.executorId,
      executorName: executorName ?? previous.executorName,
      executorAvatarUrl: previous.executorAvatarUrl,
      executorRating: executorRating ?? previous.executorRating,
      executorReviewsCount:
          executorReviewsCount ?? previous.executorReviewsCount,
      title: previous.title,
      category: previous.category,
      description: previous.description,
      urgency: previous.urgency,
      desiredExecutionAt: previous.desiredExecutionAt,
      rewardType: previous.rewardType,
      rewardAmount: previous.rewardAmount,
      address: previous.address,
      contactDetails: previous.contactDetails,
      status: status ?? previous.status,
      responsesCount: responsesCount ?? previous.responsesCount,
      createdAt: previous.createdAt,
      updatedAt: DateTime(2026, 5, 6, 14, 0),
    );
  }
}

class _FlowRequestRepository implements RequestRepository {
  final _FlowBackend backend;
  final String currentUserId;

  _FlowRequestRepository(this.backend, this.currentUserId);

  @override
  Future<ServiceRequest> createRequest({
    required String communityId,
    required String title,
    required String category,
    required String description,
    required RequestUrgency urgency,
    DateTime? desiredExecutionAt,
    required RewardType rewardType,
    int? rewardAmount,
    String? address,
    required String contactDetails,
  }) async {
    return backend.createRequest(
      communityId: communityId,
      title: title,
      category: category,
      description: description,
      urgency: urgency,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      address: address,
      contactDetails: contactDetails,
    );
  }

  @override
  Future<List<ServiceRequest>> getCommunityRequests(String communityId) async {
    final request = backend._request;
    if (request == null || request.communityId != communityId) {
      return const [];
    }
    return [request];
  }

  @override
  Future<ServiceRequest> getRequestDetails(String requestId) async {
    return backend.request;
  }

  @override
  Future<List<RequestResponse>> getRequestResponses(String requestId) async {
    return backend.responses
        .where((response) => response.requestId == requestId)
        .toList();
  }

  @override
  Future<void> respondToRequest({
    required String requestId,
    required String comment,
  }) async {
    backend.addResponse(comment);
  }

  @override
  Future<void> selectExecutor({
    required String requestId,
    required String executorId,
  }) async {
    backend.selectExecutor(executorId);
  }

  @override
  Future<void> markAsCompletedByExecutor(String requestId) async {
    backend.markCompletedByExecutor();
  }

  @override
  Future<void> confirmCompletionByCustomer(String requestId) async {
    backend.confirmCompletionByCustomer();
  }

  @override
  Future<List<ServiceRequest>> getMyRequests() async => [backend.request];

  @override
  Future<List<ServiceRequest>> getExecutorHistory() async => [backend.request];

  @override
  Future<void> cancelRequest(String requestId) async {}

  @override
  Future<void> cancelResponse(String requestId) async {}

  @override
  Future<void> deleteRequestFromHistory(String requestId) async {}

  @override
  Future<void> refuseExecution({
    required String requestId,
    String? reason,
  }) async {}

  @override
  Future<void> updateRequest(ServiceRequest request) async {}
}

class _FlowNotificationRepository implements NotificationRepository {
  final _FlowBackend backend;
  final String currentUserId;

  _FlowNotificationRepository(this.backend, this.currentUserId);

  @override
  Stream<List<AppNotification>> watchNotifications() {
    return Stream.value(
      List<AppNotification>.from(
        backend.notificationsByUser[currentUserId] ?? const [],
      ).reversed.toList(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final items = backend.notificationsByUser[currentUserId] ?? [];
    final index = items.indexWhere((item) => item.id == notificationId);
    if (index == -1) {
      return;
    }
    final previous = items[index];
    items[index] = AppNotification(
      id: previous.id,
      recipientUserId: previous.recipientUserId,
      title: previous.title,
      body: previous.body,
      targetRoute: previous.targetRoute,
      isRead: true,
      createdAt: previous.createdAt,
    );
  }

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> syncPushToken() async {}
}

class _FlowReviewRepository implements ReviewRepository {
  final _FlowBackend backend;
  final String currentUserId;

  _FlowReviewRepository(this.backend, this.currentUserId);

  @override
  Future<void> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  }) async {
    backend.leaveReview(
      customerId: currentUserId,
      executorId: executorId,
      rating: rating,
      text: text,
    );
  }

  @override
  Future<List<Review>> getUserReviews(String userId) async {
    return backend.reviews
        .where((review) => review.executorId == userId)
        .toList();
  }

  @override
  Future<double?> getUserRating(String userId) async {
    if (backend.executorReviewsCount == 0) {
      return null;
    }
    return backend.executorRating;
  }
}
