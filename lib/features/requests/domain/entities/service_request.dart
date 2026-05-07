import 'request_enums.dart';

class ServiceRequest {
  final String id;
  final String communityId;
  final String communityName;
  final String customerId;
  final String customerName;
  final String? customerAvatarUrl;
  final double customerRating;
  final int customerReviewsCount;
  final String? executorId;
  final String? executorName;
  final String? executorAvatarUrl;
  final double? executorRating;
  final int executorReviewsCount;
  final String title;
  final String category;
  final String description;
  final RequestUrgency urgency;
  final DateTime? desiredExecutionAt;
  final RewardType rewardType;
  final int? rewardAmount;
  final String? address;
  final String contactDetails;
  final RequestStatus status;
  final int responsesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceRequest({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.customerId,
    required this.customerName,
    required this.customerAvatarUrl,
    required this.customerRating,
    required this.customerReviewsCount,
    required this.executorId,
    required this.executorName,
    required this.executorAvatarUrl,
    required this.executorRating,
    required this.executorReviewsCount,
    required this.title,
    required this.category,
    required this.description,
    required this.urgency,
    required this.desiredExecutionAt,
    required this.rewardType,
    required this.rewardAmount,
    required this.address,
    required this.contactDetails,
    required this.status,
    required this.responsesCount,
    required this.createdAt,
    required this.updatedAt,
  });
}
