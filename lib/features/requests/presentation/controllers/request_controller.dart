import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import '../../data/request_api.dart';
import '../../data/request_repository_impl.dart';
import '../../domain/entities/request_enums.dart';
import '../../domain/entities/request_response.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/repositories/request_repository.dart';

class RequestState {
  final bool loading;
  final String? error;
  final List<ServiceRequest> communityRequests;
  final List<ServiceRequest> myRequests;
  final List<ServiceRequest> executorHistory;
  final ServiceRequest? selectedRequest;
  final List<RequestResponse> responses;

  const RequestState({
    this.loading = false,
    this.error,
    this.communityRequests = const [],
    this.myRequests = const [],
    this.executorHistory = const [],
    this.selectedRequest,
    this.responses = const [],
  });

  static const _errorSentinel = Object();
  static const _selectedRequestSentinel = Object();
  static const _responsesSentinel = Object();

  RequestState copyWith({
    bool? loading,
    Object? error = _errorSentinel,
    List<ServiceRequest>? communityRequests,
    List<ServiceRequest>? myRequests,
    List<ServiceRequest>? executorHistory,
    Object? selectedRequest = _selectedRequestSentinel,
    Object? responses = _responsesSentinel,
  }) {
    return RequestState(
      loading: loading ?? this.loading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      communityRequests: communityRequests ?? this.communityRequests,
      myRequests: myRequests ?? this.myRequests,
      executorHistory: executorHistory ?? this.executorHistory,
      selectedRequest: identical(selectedRequest, _selectedRequestSentinel)
          ? this.selectedRequest
          : selectedRequest as ServiceRequest?,
      responses: identical(responses, _responsesSentinel)
          ? this.responses
          : responses as List<RequestResponse>,
    );
  }
}

class RequestController extends StateNotifier<RequestState> {
  final RequestRepository _repository;

  RequestController(this._repository) : super(const RequestState());

  Future<void> loadCommunityRequests(String communityId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final communityRequests = await _repository.getCommunityRequests(
        communityId,
      );
      state = state.copyWith(
        loading: false,
        communityRequests: communityRequests,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
    }
  }

  Future<void> loadUserHistory() async {
    state = state.copyWith(loading: true, error: null);
    List<ServiceRequest>? myRequests;
    List<ServiceRequest>? executorHistory;
    Object? firstError;
    try {
      myRequests = await _repository.getMyRequests();
    } catch (e) {
      firstError = e;
    }
    try {
      executorHistory = await _repository.getExecutorHistory();
    } catch (e) {
      firstError ??= e;
    }
    state = state.copyWith(
      loading: false,
      error: myRequests == null && executorHistory == null && firstError != null
          ? mapAppError(firstError)
          : null,
      myRequests: myRequests ?? state.myRequests,
      executorHistory: executorHistory ?? state.executorHistory,
    );
  }

  Future<bool> createRequest({
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
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.createRequest(
        communityId: communityId,
        title: title,
        category: category,
        description: description,
        urgency: urgency,
        desiredExecutionAt: desiredExecutionAt,
        rewardType: rewardType,
        rewardAmount: rewardAmount,
        address: address,
        contactDetails: contactDetails,
      );
      await loadCommunityRequests(communityId);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<void> loadRequestDetails(String requestId) async {
    state = state.copyWith(
      loading: true,
      error: null,
      selectedRequest: null,
      responses: const <RequestResponse>[],
    );
    try {
      final request = await _repository.getRequestDetails(requestId);
      final responses = await _repository.getRequestResponses(requestId);
      state = state.copyWith(
        loading: false,
        selectedRequest: request,
        responses: responses,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
    }
  }

  Future<bool> respondToRequest({
    required String requestId,
    required String comment,
  }) async {
    state = state.copyWith(error: null);
    try {
      await _repository.respondToRequest(
        requestId: requestId,
        comment: comment,
      );
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> selectExecutor({
    required String requestId,
    required String executorId,
  }) async {
    state = state.copyWith(error: null);
    try {
      await _repository.selectExecutor(
        requestId: requestId,
        executorId: executorId,
      );
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> cancelResponse(String requestId) async {
    try {
      await _repository.cancelResponse(requestId);
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    try {
      await _repository.cancelRequest(requestId);
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> markAsCompletedByExecutor(String requestId) async {
    try {
      await _repository.markAsCompletedByExecutor(requestId);
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> confirmCompletionByCustomer(String requestId) async {
    try {
      await _repository.confirmCompletionByCustomer(requestId);
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> refuseExecution({
    required String requestId,
    String? reason,
  }) async {
    try {
      await _repository.refuseExecution(requestId: requestId, reason: reason);
      await loadRequestDetails(requestId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> deleteRequestFromHistory({
    required String requestId,
    required String communityId,
  }) async {
    try {
      await _repository.deleteRequestFromHistory(requestId);
      await loadCommunityRequests(communityId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }

  Future<bool> updateRequest(ServiceRequest request) async {
    try {
      await _repository.updateRequest(request);
      await loadRequestDetails(request.id);
      await loadCommunityRequests(request.communityId);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    }
  }
}

final requestApiProvider = Provider<RequestApi>((ref) {
  return RequestApi(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
    ref.watch(notificationApiProvider),
  );
});

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  return RequestRepositoryImpl(ref.watch(requestApiProvider));
});

final requestControllerProvider =
    StateNotifierProvider<RequestController, RequestState>((ref) {
      return RequestController(ref.watch(requestRepositoryProvider));
    });
