import '../entities/review.dart';

abstract class ReviewRepository {
  Future<void> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  });
  Future<List<Review>> getUserReviews(String userId);
  Future<double?> getUserRating(String userId);
}
