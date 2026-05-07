import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/features/reviews/domain/entities/review.dart';
import 'package:help_a_neighbour/features/reviews/domain/repositories/review_repository.dart';
import 'package:help_a_neighbour/features/reviews/presentation/controllers/review_controller.dart';

void main() {
  group('ReviewController', () {
    test('loads user reviews into state', () async {
      final review = _review(id: 'review-1');
      final repository = _FakeReviewRepository(reviews: [review]);
      final controller = ReviewController(repository);

      await controller.loadUserReviews('executor-1');

      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.reviews, [review]);
      expect(repository.loadedUserId, 'executor-1');
    });

    test('leaveReview forwards review data and clears loading', () async {
      final repository = _FakeReviewRepository();
      final controller = ReviewController(repository);

      final success = await controller.leaveReview(
        requestId: 'request-1',
        executorId: 'executor-1',
        rating: 5,
        text: 'отлично помог',
      );

      expect(success, isTrue);
      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      expect(repository.leftRequestId, 'request-1');
      expect(repository.leftExecutorId, 'executor-1');
      expect(repository.leftRating, 5);
      expect(repository.leftText, 'отлично помог');
    });

    test('leaveReview maps duplicate review error', () async {
      final repository = _FakeReviewRepository(
        leaveError: StateError(
          'За одну услугу может быть оставлен только один отзыв',
        ),
      );
      final controller = ReviewController(repository);

      final success = await controller.leaveReview(
        requestId: 'request-1',
        executorId: 'executor-1',
        rating: 5,
        text: 'отлично',
      );

      expect(success, isFalse);
      expect(controller.state.loading, isFalse);
      expect(
        controller.state.error,
        'За одну услугу может быть оставлен только один отзыв',
      );
    });
  });
}

class _FakeReviewRepository implements ReviewRepository {
  final List<Review> reviews;
  final Object? leaveError;
  String? loadedUserId;
  String? leftRequestId;
  String? leftExecutorId;
  int? leftRating;
  String? leftText;

  _FakeReviewRepository({this.reviews = const [], this.leaveError});

  @override
  Future<List<Review>> getUserReviews(String userId) async {
    loadedUserId = userId;
    return reviews;
  }

  @override
  Future<double?> getUserRating(String userId) async {
    if (reviews.isEmpty) {
      return null;
    }
    return reviews.map((review) => review.rating).reduce((a, b) => a + b) /
        reviews.length;
  }

  @override
  Future<void> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  }) async {
    final error = leaveError;
    if (error != null) {
      throw error;
    }
    leftRequestId = requestId;
    leftExecutorId = executorId;
    leftRating = rating;
    leftText = text;
  }
}

Review _review({required String id, int rating = 5}) {
  return Review(
    id: id,
    requestId: 'request-1',
    customerId: 'customer-1',
    customerName: 'Мария',
    customerAvatarUrl: null,
    executorId: 'executor-1',
    rating: rating,
    text: 'отлично помог',
    createdAt: DateTime(2026, 5, 6),
  );
}
