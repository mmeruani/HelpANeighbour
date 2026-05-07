import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import '../../data/review_api.dart';
import '../../data/review_repository_impl.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewState {
  final bool loading;
  final String? error;
  final List<Review> reviews;

  const ReviewState({
    this.loading = false,
    this.error,
    this.reviews = const [],
  });

  static const _errorSentinel = Object();

  ReviewState copyWith({
    bool? loading,
    Object? error = _errorSentinel,
    List<Review>? reviews,
  }) {
    return ReviewState(
      loading: loading ?? this.loading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      reviews: reviews ?? this.reviews,
    );
  }
}

class ReviewController extends StateNotifier<ReviewState> {
  final ReviewRepository _repository;

  ReviewController(this._repository) : super(const ReviewState());

  Future<void> loadUserReviews(String userId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final reviews = await _repository.getUserReviews(userId);
      state = state.copyWith(loading: false, reviews: reviews);
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
    }
  }

  Future<bool> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.leaveReview(
        requestId: requestId,
        executorId: executorId,
        rating: rating,
        text: text,
      );
      state = state.copyWith(loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }
}

final reviewApiProvider = Provider<ReviewApi>((ref) {
  return ReviewApi(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
    ref.watch(notificationApiProvider),
  );
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepositoryImpl(ref.watch(reviewApiProvider));
});

final reviewControllerProvider =
    StateNotifierProvider<ReviewController, ReviewState>((ref) {
      return ReviewController(ref.watch(reviewRepositoryProvider));
    });
