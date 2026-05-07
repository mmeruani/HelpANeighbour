import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/constants.dart';
import '../../../core/config/service_categories.dart';
import '../domain/entities/notification_settings.dart';
import '../domain/entities/profile.dart';

class ProfileApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  const ProfileApi(this._auth, this._db);

  Future<String> _currentUserId() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    return user.uid;
  }

  Future<void> _ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }

    final userRef = _db.collection(AppCollections.users).doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      await userRef.set({
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'name': '',
        'avatarUrl': null,
        'bio': '',
        'rating': 0.0,
        'completedServicesCount': 0,
        'reviewsCount': 0,
        'communityIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _syncPublicProfile(user.uid, {
        'name': '',
        'avatarUrl': null,
        'bio': '',
        'rating': 0.0,
        'completedServicesCount': 0,
        'reviewsCount': 0,
        'communityIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final notificationRef = userRef
        .collection('notification_settings')
        .doc('default');
    final notificationSnapshot = await notificationRef.get();
    if (!notificationSnapshot.exists) {
      await notificationRef.set({
        'newRequestsInCommunities': true,
        'responsesToMyRequests': true,
        'selectedAsExecutor': true,
        'newReviews': true,
        'subscribedCategoryIds': ServiceCategories.titles,
      });
    }
  }

  Future<Profile> getCurrentProfile() async {
    await _ensureProfileExists();
    final userId = await _currentUserId();
    await _recalculateOwnRating(userId);

    final userSnapshot = await _db
        .collection(AppCollections.users)
        .doc(userId)
        .get();
    final notificationSnapshot = await _db
        .collection(AppCollections.users)
        .doc(userId)
        .collection('notification_settings')
        .doc('default')
        .get();

    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final settingsData = notificationSnapshot.data() ?? <String, dynamic>{};
    final subscribedCategoryIds =
        ((settingsData['subscribedCategoryIds'] as List<dynamic>?) ?? const [])
            .map((id) => id.toString())
            .where((id) => id.trim().isNotEmpty)
            .toList();

    return Profile(
      userId: userId,
      email: (userData['email'] as String?) ?? '',
      phone: (userData['phone'] as String?) ?? '',
      name: (userData['name'] as String?) ?? '',
      avatarUrl: userData['avatarUrl'] as String?,
      bio: (userData['bio'] as String?) ?? '',
      rating: ((userData['rating'] as num?) ?? 0).toDouble(),
      completedServicesCount:
          ((userData['completedServicesCount'] as num?) ?? 0).toInt(),
      reviewsCount: ((userData['reviewsCount'] as num?) ?? 0).toInt(),
      communityIds: ((userData['communityIds'] as List<dynamic>?) ?? const [])
          .map((id) => id.toString())
          .toList(),
      notificationSettings: NotificationSettings(
        newRequestsInCommunities:
            (settingsData['newRequestsInCommunities'] as bool?) ?? true,
        responsesToMyRequests:
            (settingsData['responsesToMyRequests'] as bool?) ?? true,
        selectedAsExecutor:
            (settingsData['selectedAsExecutor'] as bool?) ?? true,
        newReviews: (settingsData['newReviews'] as bool?) ?? true,
        subscribedCategoryIds: subscribedCategoryIds.isEmpty
            ? ServiceCategories.titles
            : subscribedCategoryIds,
      ),
    );
  }

  Future<void> updateProfile({
    required String name,
    required String bio,
    String? avatarUrl,
  }) async {
    await _ensureProfileExists();
    final userId = await _currentUserId();
    final normalizedAvatarUrl = avatarUrl?.trim().isEmpty == true
        ? null
        : avatarUrl?.trim();
    await _db.collection(AppCollections.users).doc(userId).set({
      'name': name.trim(),
      'bio': bio.trim(),
      'avatarUrl': normalizedAvatarUrl,
    }, SetOptions(merge: true));
    await _syncPublicProfile(userId, {
      'name': name.trim(),
      'bio': bio.trim(),
      'avatarUrl': normalizedAvatarUrl,
    });
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _auth.currentUser?.updatePhotoURL(normalizedAvatarUrl);
  }

  Future<void> _syncPublicProfile(
    String userId,
    Map<String, Object?> data,
  ) async {
    try {
      await _db
          .collection(AppCollections.publicUsers)
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _recalculateOwnRating(String userId) async {
    try {
      final reviews = await _db
          .collection(AppCollections.reviews)
          .where('executorId', isEqualTo: userId)
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
      await _db
          .collection(AppCollections.users)
          .doc(userId)
          .set(aggregateData, SetOptions(merge: true));
      await _db
          .collection(AppCollections.publicUsers)
          .doc(userId)
          .set(aggregateData, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> updateNotificationSettings(NotificationSettings settings) async {
    final userId = await _currentUserId();
    await _db
        .collection(AppCollections.users)
        .doc(userId)
        .collection('notification_settings')
        .doc('default')
        .set({
          'newRequestsInCommunities': settings.newRequestsInCommunities,
          'responsesToMyRequests': settings.responsesToMyRequests,
          'selectedAsExecutor': settings.selectedAsExecutor,
          'newReviews': settings.newReviews,
          'subscribedCategoryIds': settings.subscribedCategoryIds,
        });
  }

  Future<List<String>> getActivityHistory() async {
    final userId = await _currentUserId();

    final activityEvents = await _db
        .collection(AppCollections.activityEvents)
        .where('userId', isEqualTo: userId)
        .get();
    final requests = await _db
        .collection(AppCollections.requests)
        .where('customerId', isEqualTo: userId)
        .get();
    final responses = await _db
        .collection(AppCollections.requestResponses)
        .where('executorId', isEqualTo: userId)
        .get();
    final reviews = await _db
        .collection(AppCollections.reviews)
        .where('customerId', isEqualTo: userId)
        .get();
    final executorRequests = await _db
        .collection(AppCollections.requests)
        .where('executorId', isEqualTo: userId)
        .get();

    final items = <({DateTime? date, String text})>[
      ...activityEvents.docs.map((doc) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        return (
          date: date,
          text: '[${_formatDate(date)}] ${_activityMessage(data)}',
        );
      }),
      ...requests.docs.map((doc) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        final status = _requestStatusLabel(
          (data['status'] as String?) ?? 'unknown',
        );
        return (
          date: date,
          text:
              '[${_formatDate(date)}] Создан запрос: ${(data['title'] as String?) ?? 'Без названия'} (статус: $status)',
        );
      }),
      ...responses.docs.map((doc) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        return (
          date: date,
          text:
              '[${_formatDate(date)}] Оставлен отклик на запрос ${data['requestId']} (статус: отклик отправлен)',
        );
      }),
      ...executorRequests.docs.map((doc) {
        final data = doc.data();
        final date = ((data['updatedAt'] ?? data['createdAt']) as Timestamp?)
            ?.toDate();
        final status = _requestStatusLabel(
          (data['status'] as String?) ?? 'unknown',
        );
        return (
          date: date,
          text:
              '[${_formatDate(date)}] Работа исполнителя по запросу: ${(data['title'] as String?) ?? 'Без названия'} (статус: $status)',
        );
      }),
      ...reviews.docs.map((doc) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        return (
          date: date,
          text:
              '[${_formatDate(date)}] Оставлен отзыв с оценкой ${(data['rating'] as num?) ?? 0} (статус: отзыв опубликован)',
        );
      }),
    ];

    items.sort((a, b) {
      final aDate = a.date;
      final bDate = b.date;
      if (aDate == null && bDate == null) {
        return 0;
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      return bDate.compareTo(aDate);
    });

    return items.map((item) => item.text).toList();
  }
}

String _activityMessage(Map<String, dynamic> data) {
  final message = (data['message'] as String?)?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }
  final communityName = (data['communityName'] as String?)?.trim();
  final suffix = communityName == null || communityName.isEmpty
      ? ''
      : ' в сообществе "$communityName"';
  return 'Действие в приложении$suffix';
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return 'дата неизвестна';
  }
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _requestStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Активен';
    case 'inProgress':
      return 'В процессе';
    case 'awaitingCustomerConfirmation':
      return 'Ожидает подтверждения';
    case 'completed':
      return 'Выполнен';
    case 'cancelled':
      return 'Отменён';
    default:
      return status;
  }
}
