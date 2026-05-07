import '../entities/request_response.dart';
import '../entities/request_enums.dart';
import '../entities/service_request.dart';

abstract class RequestRepository {
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
  });
  Future<List<ServiceRequest>> getCommunityRequests(String communityId);
  Future<List<ServiceRequest>> getMyRequests();
  Future<List<ServiceRequest>> getExecutorHistory();
  Future<ServiceRequest> getRequestDetails(String requestId);
  Future<void> updateRequest(ServiceRequest request);
  Future<void> cancelRequest(String requestId);
  Future<void> deleteRequestFromHistory(String requestId);
  Future<List<RequestResponse>> getRequestResponses(String requestId);
  Future<void> respondToRequest({
    required String requestId,
    required String comment,
  });
  Future<void> cancelResponse(String requestId);
  Future<void> selectExecutor({
    required String requestId,
    required String executorId,
  });
  Future<void> markAsCompletedByExecutor(String requestId);
  Future<void> confirmCompletionByCustomer(String requestId);
  Future<void> refuseExecution({required String requestId, String? reason});
}
