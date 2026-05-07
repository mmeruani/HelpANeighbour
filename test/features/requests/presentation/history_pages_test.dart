import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_enums.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_response.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/service_request.dart';
import 'package:help_a_neighbour/features/requests/domain/repositories/request_repository.dart';
import 'package:help_a_neighbour/features/requests/presentation/controllers/request_controller.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/customer_history_page.dart';
import 'package:help_a_neighbour/features/requests/presentation/pages/executor_history_page.dart';

void main() {
  group('CustomerHistoryPage', () {
    testWidgets('shows empty state with refresh hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(
              _FakeRequestRepository(),
            ),
          ],
          child: const MaterialApp(home: CustomerHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('История заказчика пока пуста'), findsOneWidget);
      expect(find.text('Попробуйте обновить страницу'), findsOneWidget);
    });

    testWidgets('shows customer request history card', (tester) async {
      final request = _request(id: 'r1', status: RequestStatus.completed);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(
              _FakeRequestRepository(myRequests: [request]),
            ),
          ],
          child: const MaterialApp(home: CustomerHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Купить хлеб'), findsOneWidget);
      expect(find.text('Выполнен'), findsOneWidget);
      expect(find.textContaining('Откликов: 1'), findsOneWidget);
    });
  });

  group('ExecutorHistoryPage', () {
    testWidgets('shows empty state with refresh hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(
              _FakeRequestRepository(),
            ),
          ],
          child: const MaterialApp(home: ExecutorHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('История исполнителя пока пуста'), findsOneWidget);
      expect(find.text('Попробуйте обновить страницу'), findsOneWidget);
    });

    testWidgets('shows executor history card', (tester) async {
      final request = _request(
        id: 'r2',
        status: RequestStatus.inProgress,
        executorId: 'executor-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(
              _FakeRequestRepository(executorHistory: [request]),
            ),
          ],
          child: const MaterialApp(home: ExecutorHistoryPage()),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Купить хлеб'), findsOneWidget);
      expect(find.text('В процессе'), findsOneWidget);
      expect(find.textContaining('Оплата: 500 ₽'), findsOneWidget);
    });
  });
}

class _FakeRequestRepository implements RequestRepository {
  final List<ServiceRequest> myRequests;
  final List<ServiceRequest> executorHistory;

  _FakeRequestRepository({
    this.myRequests = const [],
    this.executorHistory = const [],
  });

  @override
  Future<List<ServiceRequest>> getMyRequests() async => myRequests;

  @override
  Future<List<ServiceRequest>> getExecutorHistory() async => executorHistory;

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
    return _request(id: 'created');
  }

  @override
  Future<List<ServiceRequest>> getCommunityRequests(String communityId) async =>
      const [];

  @override
  Future<ServiceRequest> getRequestDetails(String requestId) async =>
      _request(id: requestId);

  @override
  Future<List<RequestResponse>> getRequestResponses(String requestId) async =>
      const [];

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
  Future<void> respondToRequest({
    required String requestId,
    required String comment,
  }) async {}

  @override
  Future<void> selectExecutor({
    required String requestId,
    required String executorId,
  }) async {}

  @override
  Future<void> updateRequest(ServiceRequest request) async {}
}

ServiceRequest _request({
  required String id,
  RequestStatus status = RequestStatus.active,
  String? executorId,
}) {
  final now = DateTime(2026, 5, 6, 12);
  return ServiceRequest(
    id: id,
    communityId: 'community-1',
    communityName: 'улица Народного Ополчения',
    customerId: 'customer-1',
    customerName: 'Мария',
    customerAvatarUrl: null,
    customerRating: 5,
    customerReviewsCount: 1,
    executorId: executorId,
    executorName: executorId == null ? null : 'Исполнитель',
    executorAvatarUrl: null,
    executorRating: executorId == null ? null : 5,
    executorReviewsCount: executorId == null ? 0 : 1,
    title: 'Купить хлеб',
    category: 'Покупки и доставка',
    description: 'Нужно сегодня',
    urgency: RequestUrgency.urgent,
    desiredExecutionAt: now.add(const Duration(hours: 1)),
    rewardType: RewardType.fixed,
    rewardAmount: 500,
    address: 'дом 13',
    contactDetails: 'телеграм',
    status: status,
    responsesCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}
