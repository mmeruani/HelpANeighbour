class RequestResponse {
  final String id;
  final String requestId;
  final String executorId;
  final String executorName;
  final String? executorAvatarUrl;
  final double executorRating;
  final int executorReviewsCount;
  final String comment;
  final DateTime createdAt;

  const RequestResponse({
    required this.id,
    required this.requestId,
    required this.executorId,
    required this.executorName,
    required this.executorAvatarUrl,
    required this.executorRating,
    required this.executorReviewsCount,
    required this.comment,
    required this.createdAt,
  });
}
