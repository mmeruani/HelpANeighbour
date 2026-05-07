import '../domain/entities/review.dart';
import '../domain/repositories/review_repository.dart';
import 'review_api.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewApi _api;

  const ReviewRepositoryImpl(this._api);

  @override
  Future<double?> getUserRating(String userId) => _api.getUserRating(userId);

  @override
  Future<List<Review>> getUserReviews(String userId) => _api.getUserReviews(userId);

  @override
  Future<void> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  }) {
    return _api.leaveReview(
      requestId: requestId,
      executorId: executorId,
      rating: rating,
      text: text,
    );
  }
}
