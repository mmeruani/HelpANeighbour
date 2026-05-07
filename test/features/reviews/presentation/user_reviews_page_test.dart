import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:help_a_neighbour/features/reviews/domain/entities/review.dart';
import 'package:help_a_neighbour/features/reviews/domain/repositories/review_repository.dart';
import 'package:help_a_neighbour/features/reviews/presentation/controllers/review_controller.dart';
import 'package:help_a_neighbour/features/reviews/presentation/pages/user_reviews_page.dart';

void main() {
  testWidgets('UserReviewsPage shows average rating and reviews', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(
            _FakeReviewRepository(
              reviews: [
                _review(id: 'r1', rating: 5),
                _review(id: 'r2', rating: 3),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: UserReviewsPage(userId: 'executor-1')),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Общий рейтинг'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('Отзывов'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Оценка: 5/5'), findsOneWidget);
    expect(find.text('Оценка: 3/5'), findsOneWidget);
  });

  testWidgets('UserReviewsPage shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
        ],
        child: const MaterialApp(home: UserReviewsPage(userId: 'executor-1')),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Нет рейтинга'), findsOneWidget);
    expect(find.text('Отзывов пока нет'), findsOneWidget);
  });
}

class _FakeReviewRepository implements ReviewRepository {
  final List<Review> reviews;

  _FakeReviewRepository({this.reviews = const []});

  @override
  Future<List<Review>> getUserReviews(String userId) async => reviews;

  @override
  Future<double?> getUserRating(String userId) async => null;

  @override
  Future<void> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  }) async {}
}

Review _review({required String id, required int rating}) {
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
