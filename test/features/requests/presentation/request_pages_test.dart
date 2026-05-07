import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/features/auth/presentation/controllers/auth_controller.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_enums.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_response.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/service_request.dart';
import 'package:help_a_neighbour/features/requests/domain/repositories/request_repository.dart';
import 'package:help_a_neighbour/features/requests/presentation/controllers/request_controller.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/completed_services_page.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/create_request_page.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/request_details_page.dart';

void main() {
  group('CreateRequestPage', () {
    testWidgets('shows validation errors before creating request', (
      tester,
    ) async {
      _useTallTestScreen(tester);
      await tester.pumpWidget(
        _testApp(
          repository: _FakeRequestRepository(),
          child: const CreateRequestPage(communityId: 'community-1'),
        ),
      );

      await tester.ensureVisible(find.text('Создать'));
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();

      expect(find.text('Некорректное название запроса'), findsOneWidget);
      expect(
        find.text('Категория услуги не выбрана или некорректна'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Некорректные контактные данные. Укажите телефон, ссылку или другой способ связи.',
        ),
        findsOneWidget,
      );
    });
  });

  group('RequestDetailsPage', () {
    testWidgets('hides contacts from executor before response', (tester) async {
      final repository = _FakeRequestRepository(
        selectedRequest: _request(
          id: 'request-1',
          customerId: 'customer-1',
          contactDetails: 'телеграм customer',
        ),
      );

      await tester.pumpWidget(
        _testApp(
          currentUserId: 'executor-1',
          repository: repository,
          child: const RequestDetailsPage(requestId: 'request-1'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('погулять с собакой'), findsWidgets);
      expect(
        find.text('Контакты станут доступны после отклика на запрос'),
        findsOneWidget,
      );
      expect(find.text('Откликнуться'), findsOneWidget);
      expect(find.textContaining('телеграм customer'), findsNothing);
    });

    testWidgets('sends response and shows confirmation snackbar', (
      tester,
    ) async {
      final repository = _FakeRequestRepository(
        selectedRequest: _request(id: 'request-1', customerId: 'customer-1'),
      );

      await tester.pumpWidget(
        _testApp(
          currentUserId: 'executor-1',
          repository: repository,
          child: const RequestDetailsPage(requestId: 'request-1'),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Откликнуться'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'готов помочь');
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(repository.respondedRequestId, 'request-1');
      expect(repository.respondedComment, 'готов помочь');
      expect(find.text('Отклик отправлен'), findsOneWidget);
    });

    testWidgets('shows response error inside response dialog', (tester) async {
      final repository = _FakeRequestRepository(
        selectedRequest: _request(id: 'request-1', customerId: 'customer-1'),
        respondError: Exception('permission-denied'),
      );

      await tester.pumpWidget(
        _testApp(
          currentUserId: 'executor-1',
          repository: repository,
          child: const RequestDetailsPage(requestId: 'request-1'),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Откликнуться'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'готов помочь');
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(find.text('Отклик на запрос'), findsOneWidget);
      expect(
        find.text('Недостаточно прав для выполнения этого действия.'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('lets customer choose executor from responses', (tester) async {
      final repository = _FakeRequestRepository(
        selectedRequest: _request(id: 'request-1', customerId: 'customer-1'),
        responses: [_response(requestId: 'request-1')],
      );

      await tester.pumpWidget(
        _testApp(
          currentUserId: 'customer-1',
          repository: repository,
          child: const RequestDetailsPage(requestId: 'request-1'),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Отклики исполнителей'), 400);

      expect(find.text('Отклики исполнителей'), findsOneWidget);
      expect(find.text('Исполнитель'), findsOneWidget);

      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();

      expect(repository.selectedExecutorId, 'executor-1');
      expect(find.text('Исполнитель выбран'), findsOneWidget);
    });
  });

  group('CompletedServicesPage', () {
    testWidgets('shows completed and cancelled requests by role', (
      tester,
    ) async {
      final repository = _FakeRequestRepository(
        myRequests: [
          _request(
            id: 'customer-completed',
            title: 'купить хлеб',
            customerId: 'user-1',
            executorId: 'executor-1',
            status: RequestStatus.completed,
          ),
          _request(
            id: 'customer-active',
            title: 'активный запрос',
            customerId: 'user-1',
            status: RequestStatus.active,
          ),
        ],
        executorHistory: [
          _request(
            id: 'executor-cancelled',
            title: 'помочь с документами',
            customerId: 'customer-2',
            executorId: 'user-1',
            status: RequestStatus.cancelled,
          ),
        ],
      );

      await tester.pumpWidget(
        _testApp(
          currentUserId: 'user-1',
          repository: repository,
          child: const CompletedServicesPage(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Как заказчик'), findsOneWidget);
      expect(find.text('купить хлеб'), findsOneWidget);
      expect(find.text('Выполнен'), findsOneWidget);
      expect(find.text('активный запрос'), findsNothing);
      expect(find.text('Как исполнитель'), findsOneWidget);
      expect(find.text('помочь с документами'), findsOneWidget);
      expect(find.text('Отменён'), findsOneWidget);
    });
  });
}

Widget _testApp({
  required RequestRepository repository,
  required Widget child,
  String? currentUserId,
}) {
  return ProviderScope(
    overrides: [
      requestRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue(currentUserId),
    ],
    child: MaterialApp(home: child),
  );
}

void _useTallTestScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeRequestRepository implements RequestRepository {
  final List<ServiceRequest> myRequests;
  final List<ServiceRequest> executorHistory;
  final List<RequestResponse> responses;
  final ServiceRequest? selectedRequest;
  final Object? respondError;

  String? respondedRequestId;
  String? respondedComment;
  String? selectedExecutorId;

  _FakeRequestRepository({
    this.myRequests = const [],
    this.executorHistory = const [],
    this.responses = const [],
    this.selectedRequest,
    this.respondError,
  });

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
    return _request(id: 'created', communityId: communityId, title: title);
  }

  @override
  Future<List<ServiceRequest>> getCommunityRequests(String communityId) async {
    return const [];
  }

  @override
  Future<List<ServiceRequest>> getMyRequests() async => myRequests;

  @override
  Future<List<ServiceRequest>> getExecutorHistory() async => executorHistory;

  @override
  Future<ServiceRequest> getRequestDetails(String requestId) async {
    return selectedRequest ?? _request(id: requestId);
  }

  @override
  Future<List<RequestResponse>> getRequestResponses(String requestId) async {
    return responses
        .where((response) => response.requestId == requestId)
        .toList();
  }

  @override
  Future<void> respondToRequest({
    required String requestId,
    required String comment,
  }) async {
    final error = respondError;
    if (error != null) {
      throw error;
    }
    respondedRequestId = requestId;
    respondedComment = comment;
  }

  @override
  Future<void> selectExecutor({
    required String requestId,
    required String executorId,
  }) async {
    selectedExecutorId = executorId;
  }

  @override
  Future<void> cancelRequest(String requestId) async {}

  @override
  Future<void> cancelResponse(String requestId) async {}

  @override
  Future<void> confirmCompletionByCustomer(String requestId) async {}

  @override
  Future<void> deleteRequestFromHistory(String requestId) async {}

  @override
  Future<void> markAsCompletedByExecutor(String requestId) async {}

  @override
  Future<void> refuseExecution({
    required String requestId,
    String? reason,
  }) async {}

  @override
  Future<void> updateRequest(ServiceRequest request) async {}
}

ServiceRequest _request({
  required String id,
  String communityId = 'community-1',
  String communityName = 'улица Народного Ополчения',
  String customerId = 'customer-1',
  String customerName = 'Мария',
  String? customerAvatarUrl,
  double customerRating = 5,
  int customerReviewsCount = 1,
  String? executorId,
  String? executorName,
  String? executorAvatarUrl,
  double? executorRating,
  int executorReviewsCount = 0,
  String title = 'погулять с собакой',
  String category = 'Выгул и уход за животными',
  String description = 'нужно сегодня',
  RequestUrgency urgency = RequestUrgency.urgent,
  DateTime? desiredExecutionAt,
  RewardType rewardType = RewardType.fixed,
  int? rewardAmount = 500,
  String? address = 'дом 13',
  String contactDetails = 'телеграм customer',
  RequestStatus status = RequestStatus.active,
  int responsesCount = 0,
}) {
  final now = DateTime(2026, 5, 6, 12, 30);
  return ServiceRequest(
    id: id,
    communityId: communityId,
    communityName: communityName,
    customerId: customerId,
    customerName: customerName,
    customerAvatarUrl: customerAvatarUrl,
    customerRating: customerRating,
    customerReviewsCount: customerReviewsCount,
    executorId: executorId,
    executorName: executorName,
    executorAvatarUrl: executorAvatarUrl,
    executorRating: executorRating,
    executorReviewsCount: executorReviewsCount,
    title: title,
    category: category,
    description: description,
    urgency: urgency,
    desiredExecutionAt: desiredExecutionAt ?? DateTime(2026, 5, 6, 18, 0),
    rewardType: rewardType,
    rewardAmount: rewardAmount,
    address: address,
    contactDetails: contactDetails,
    status: status,
    responsesCount: responsesCount,
    createdAt: now,
    updatedAt: now,
  );
}

RequestResponse _response({
  required String requestId,
  String id = 'response-1',
  String executorId = 'executor-1',
  String executorName = 'Исполнитель',
  String? executorAvatarUrl,
  double executorRating = 4.8,
  int executorReviewsCount = 3,
  String comment = 'готов помочь',
}) {
  return RequestResponse(
    id: id,
    requestId: requestId,
    executorId: executorId,
    executorName: executorName,
    executorAvatarUrl: executorAvatarUrl,
    executorRating: executorRating,
    executorReviewsCount: executorReviewsCount,
    comment: comment,
    createdAt: DateTime(2026, 5, 6, 12, 35),
  );
}
