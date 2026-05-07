import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_enums.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/request_response.dart';
import 'package:help_a_neighbour/features/requests/domain/entities/service_request.dart';
import 'package:help_a_neighbour/features/requests/domain/repositories/request_repository.dart';
import 'package:help_a_neighbour/features/requests/presentation/controllers/request_controller.dart';

void main() {
  group('RequestController', () {
    test('loads community requests into state', () async {
      final request = _request(id: 'r1', communityId: 'c1');
      final repository = _FakeRequestRepository(communityRequests: [request]);
      final controller = RequestController(repository);

      await controller.loadCommunityRequests('c1');

      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.communityRequests, [request]);
    });

    test(
      'loadUserHistory keeps successful half when another call fails',
      () async {
        final executorRequest = _request(
          id: 'r2',
          communityId: 'c1',
          executorId: 'executor-1',
        );
        final repository = _FakeRequestRepository(
          myRequests: [_request(id: 'customer-r1', communityId: 'c1')],
          myRequestsError: Exception('permission-denied'),
          executorHistory: [executorRequest],
        );
        final controller = RequestController(repository);

        await controller.loadUserHistory();

        expect(controller.state.loading, isFalse);
        expect(controller.state.error, isNull);
        expect(controller.state.myRequests, isEmpty);
        expect(controller.state.executorHistory, [executorRequest]);
      },
    );

    test('respondToRequest reloads request details after success', () async {
      final request = _request(id: 'r1', communityId: 'c1', responsesCount: 1);
      final response = _response(requestId: 'r1');
      final repository = _FakeRequestRepository(
        selectedRequest: request,
        responses: [response],
      );
      final controller = RequestController(repository);

      final success = await controller.respondToRequest(
        requestId: 'r1',
        comment: 'готова помочь',
      );

      expect(success, isTrue);
      expect(repository.respondedRequestId, 'r1');
      expect(repository.respondedComment, 'готова помочь');
      expect(controller.state.selectedRequest, request);
      expect(controller.state.responses, [response]);
      expect(controller.state.error, isNull);
    });

    test(
      'respondToRequest maps repository errors without changing details',
      () async {
        final request = _request(id: 'r1', communityId: 'c1');
        final repository = _FakeRequestRepository(
          selectedRequest: request,
          respondError: Exception('permission-denied'),
        );
        final controller = RequestController(repository);

        final success = await controller.respondToRequest(
          requestId: 'r1',
          comment: 'готова помочь',
        );

        expect(success, isFalse);
        expect(
          controller.state.error,
          'Недостаточно прав для выполнения этого действия.',
        );
        expect(controller.state.selectedRequest, isNull);
      },
    );

    test(
      'selectExecutor reloads request details and stores responses',
      () async {
        final request = _request(
          id: 'r1',
          communityId: 'c1',
          status: RequestStatus.inProgress,
          executorId: 'executor-1',
        );
        final repository = _FakeRequestRepository(selectedRequest: request);
        final controller = RequestController(repository);

        final success = await controller.selectExecutor(
          requestId: 'r1',
          executorId: 'executor-1',
        );

        expect(success, isTrue);
        expect(repository.selectedExecutorId, 'executor-1');
        expect(controller.state.selectedRequest, request);
        expect(controller.state.error, isNull);
      },
    );

    test('createRequest reloads community list after creation', () async {
      final created = _request(id: 'created', communityId: 'c1');
      final repository = _FakeRequestRepository(
        createdRequest: created,
        communityRequests: [created],
      );
      final controller = RequestController(repository);

      final success = await controller.createRequest(
        communityId: 'c1',
        title: 'Купить хлеб',
        category: 'Покупки и доставка',
        description: 'Нужно сегодня',
        urgency: RequestUrgency.urgent,
        rewardType: RewardType.fixed,
        rewardAmount: 500,
        address: 'дом 13',
        contactDetails: 'телеграм',
      );

      expect(success, isTrue);
      expect(repository.createdTitle, 'Купить хлеб');
      expect(repository.loadedCommunityId, 'c1');
      expect(controller.state.communityRequests, [created]);
    });
  });
}

class _FakeRequestRepository implements RequestRepository {
  final List<ServiceRequest> communityRequests;
  final List<ServiceRequest> myRequests;
  final List<ServiceRequest> executorHistory;
  final List<RequestResponse> responses;
  final ServiceRequest? selectedRequest;
  final ServiceRequest? createdRequest;
  final Object? myRequestsError;
  final Object? respondError;

  String? loadedCommunityId;
  String? respondedRequestId;
  String? respondedComment;
  String? selectedExecutorId;
  String? createdTitle;

  _FakeRequestRepository({
    this.communityRequests = const [],
    this.myRequests = const [],
    this.executorHistory = const [],
    this.responses = const [],
    this.selectedRequest,
    this.createdRequest,
    this.myRequestsError,
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
    createdTitle = title;
    return createdRequest ?? _request(id: 'created', communityId: communityId);
  }

  @override
  Future<List<ServiceRequest>> getCommunityRequests(String communityId) async {
    loadedCommunityId = communityId;
    return communityRequests
        .where((request) => request.communityId == communityId)
        .toList();
  }

  @override
  Future<List<ServiceRequest>> getMyRequests() async {
    final error = myRequestsError;
    if (error != null) {
      throw error;
    }
    return myRequests;
  }

  @override
  Future<List<ServiceRequest>> getExecutorHistory() async => executorHistory;

  @override
  Future<ServiceRequest> getRequestDetails(String requestId) async {
    return selectedRequest ?? _request(id: requestId, communityId: 'c1');
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
  required String communityId,
  String? executorId,
  int responsesCount = 0,
  RequestStatus status = RequestStatus.active,
}) {
  final now = DateTime(2026, 5, 6, 12);
  return ServiceRequest(
    id: id,
    communityId: communityId,
    communityName: 'Сообщество',
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
    responsesCount: responsesCount,
    createdAt: now,
    updatedAt: now,
  );
}

RequestResponse _response({required String requestId}) {
  return RequestResponse(
    id: 'response-1',
    requestId: requestId,
    executorId: 'executor-1',
    executorName: 'Исполнитель',
    executorAvatarUrl: null,
    executorRating: 5,
    executorReviewsCount: 1,
    comment: 'готова помочь',
    createdAt: DateTime(2026, 5, 6, 12),
  );
}
