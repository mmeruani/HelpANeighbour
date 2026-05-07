class Review {
  final String id;
  final String requestId;
  final String customerId;
  final String customerName;
  final String? customerAvatarUrl;
  final String executorId;
  final int rating;
  final String text;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.customerName,
    required this.customerAvatarUrl,
    required this.executorId,
    required this.rating,
    required this.text,
    required this.createdAt,
  });
}
