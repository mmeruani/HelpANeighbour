import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/constants.dart';
import '../../../core/utils/validators.dart';
import '../../notifications/data/notification_api.dart';
import '../domain/entities/review.dart';

class ReviewApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final NotificationApi _notifications;

  const ReviewApi(this._auth, this._db, this._notifications);

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    return user.uid;
  }

  Review _mapReview(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Review(
      id: doc.id,
      requestId: (data['requestId'] as String?) ?? '',
      customerId: (data['customerId'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      customerAvatarUrl: data['customerAvatarUrl'] as String?,
      executorId: (data['executorId'] as String?) ?? '',
      rating: ((data['rating'] as num?) ?? 0).toInt(),
      text: (data['text'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Future<void> leaveReview({
    required String requestId,
    required String executorId,
    required int rating,
    required String text,
  }) async {
    if (rating < AppLimits.minRating || rating > AppLimits.maxRating) {
      throw StateError('Некорректная оценка');
    }
    final textError = Validators.reviewText(text);
    if (textError != null) {
      throw StateError(textError);
    }

    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};

    if (requestData['customerId'] != _userId) {
      throw StateError('Оставить отзыв может только заказчик');
    }
    if (requestData['status'] != 'completed') {
      throw StateError('Нельзя оставить отзыв до завершения услуги');
    }

    final existing = await _db
        .collection(AppCollections.reviews)
        .where('requestId', isEqualTo: requestId)
        .where('customerId', isEqualTo: _userId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('За одну услугу может быть оставлен только один отзыв');
    }

    final customerDoc = await _db
        .collection(AppCollections.users)
        .doc(_userId)
        .get();
    final customerData = customerDoc.data() ?? <String, dynamic>{};

    await _db.collection(AppCollections.reviews).add({
      'requestId': requestId,
      'customerId': _userId,
      'customerName': customerData['name'] ?? '',
      'customerAvatarUrl': customerData['avatarUrl'],
      'executorId': executorId,
      'rating': rating,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _recalculateExecutorRating(executorId);
    } catch (_) {}

    try {
      await _notifications.createNotification(
        recipientUserId: executorId,
        title: 'Вы получили новый отзыв',
        body: 'Оценка: $rating/5',
        targetRoute: '/profile/reviews/$executorId',
        preference: NotificationPreference.newReviews,
      );
    } catch (_) {}
  }

  Future<List<Review>> getUserReviews(String userId) async {
    final query = await _db
        .collection(AppCollections.reviews)
        .where('executorId', isEqualTo: userId)
        .get();
    final items = query.docs.map(_mapReview).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    try {
      await _recalculateExecutorRating(userId);
    } catch (_) {}
    return items;
  }

  Future<double?> getUserRating(String userId) async {
    try {
      final userDoc = await _db
          .collection(AppCollections.publicUsers)
          .doc(userId)
          .get();
      final rating = (userDoc.data()?['rating'] as num?)?.toDouble();
      return rating;
    } catch (_) {
      return null;
    }
  }

  Future<void> _recalculateExecutorRating(String executorId) async {
    final reviews = await _db
        .collection(AppCollections.reviews)
        .where('executorId', isEqualTo: executorId)
        .get();
    final ratings = reviews.docs
        .map((doc) => (doc.data()['rating'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final reviewsCount = ratings.length;
    final rating = reviewsCount == 0
        ? 0.0
        : ratings.reduce((a, b) => a + b) / reviewsCount;

    final aggregateData = {'rating': rating, 'reviewsCount': reviewsCount};
    Object? firstError;
    try {
      await _db
          .collection(AppCollections.publicUsers)
          .doc(executorId)
          .set(aggregateData, SetOptions(merge: true));
    } catch (e) {
      firstError = e;
    }
    try {
      await _db
          .collection(AppCollections.users)
          .doc(executorId)
          .set(aggregateData, SetOptions(merge: true));
    } catch (e) {
      firstError ??= e;
    }
    if (firstError != null) {
      throw firstError;
    }
  }
}
