import '../domain/entities/request_enums.dart';
import '../domain/entities/request_response.dart';
import '../domain/entities/service_request.dart';
import '../domain/repositories/request_repository.dart';
import 'request_api.dart';

class RequestRepositoryImpl implements RequestRepository {
  final RequestApi _api;

  const RequestRepositoryImpl(this._api);

  @override
  Future<void> cancelRequest(String requestId) => _api.cancelRequest(requestId);

  @override
  Future<void> cancelResponse(String requestId) =>
      _api.cancelResponse(requestId);

  @override
  Future<void> confirmCompletionByCustomer(String requestId) =>
      _api.confirmCompletionByCustomer(requestId);

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
  }) {
    return _api.createRequest(
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
  }

  @override
  Future<void> deleteRequestFromHistory(String requestId) =>
      _api.deleteRequestFromHistory(requestId);

  @override
  Future<List<ServiceRequest>> getCommunityRequests(String communityId) =>
      _api.getCommunityRequests(communityId);

  @override
  Future<List<ServiceRequest>> getExecutorHistory() =>
      _api.getExecutorHistory();

  @override
  Future<List<ServiceRequest>> getMyRequests() => _api.getMyRequests();

  @override
  Future<ServiceRequest> getRequestDetails(String requestId) =>
      _api.getRequestDetails(requestId);

  @override
  Future<List<RequestResponse>> getRequestResponses(String requestId) =>
      _api.getRequestResponses(requestId);

  @override
  Future<void> markAsCompletedByExecutor(String requestId) =>
      _api.markAsCompletedByExecutor(requestId);

  @override
  Future<void> refuseExecution({required String requestId, String? reason}) {
    return _api.refuseExecution(requestId: requestId, reason: reason);
  }

  @override
  Future<void> respondToRequest({
    required String requestId,
    required String comment,
  }) {
    return _api.respondToRequest(requestId: requestId, comment: comment);
  }

  @override
  Future<void> selectExecutor({
    required String requestId,
    required String executorId,
  }) {
    return _api.selectExecutor(requestId: requestId, executorId: executorId);
  }

  @override
  Future<void> updateRequest(ServiceRequest request) =>
      _api.updateRequest(request);
}
