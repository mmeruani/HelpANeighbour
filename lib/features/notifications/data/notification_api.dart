import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/constants.dart';
import '../domain/entities/app_notification.dart';

enum NotificationPreference {
  newRequestsInCommunities,
  responsesToMyRequests,
  selectedAsExecutor,
  newReviews,
}

class NotificationApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  const NotificationApi(this._auth, this._db);

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    return user.uid;
  }

  AppNotification _mapNotification(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      recipientUserId: (data['recipientUserId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      targetRoute: (data['targetRoute'] as String?) ?? '',
      isRead: (data['isRead'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Future<void> createNotification({
    required String recipientUserId,
    required String title,
    required String body,
    required String targetRoute,
    NotificationPreference? preference,
  }) async {
    final allowed = await _notificationAllowed(
      recipientUserId: recipientUserId,
      preference: preference,
    );
    if (!allowed) {
      return;
    }
    try {
      await _createNotificationDirectly(
        recipientUserId: recipientUserId,
        title: title,
        body: body,
        targetRoute: targetRoute,
      );
    } catch (_) {}
  }

  Future<void> notifyCommunityMembersAboutNewRequest({
    required String communityId,
    required String title,
    required String body,
    required String targetRoute,
    required String category,
    required String urgencyLabel,
  }) async {
    try {
      await _notifyCommunityMembersDirectly(
        communityId: communityId,
        title: title,
        body: '$body · $urgencyLabel',
        targetRoute: targetRoute,
        category: category,
      );
    } catch (_) {}
  }

  Stream<List<AppNotification>> watchNotifications() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream<List<AppNotification>>.value(const []);
      }
      _ensureDerivedNotifications(user.uid);
      return _db
          .collection(AppCollections.notifications)
          .where('recipientUserId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            final items = snapshot.docs.map(_mapNotification).toList();
            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return items;
          });
    });
  }

  Future<void> _ensureDerivedNotifications(String userId) async {
    try {
      await _ensureCompletionNotifications(userId);
      await _ensureReviewNotification(userId);
    } catch (_) {}
  }

  Future<void> _ensureCompletionNotifications(String userId) async {
    final requests = await _db
        .collection(AppCollections.requests)
        .where('executorId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .get();
    for (final request in requests.docs) {
      final requestId = request.id;
      final data = request.data();
      final title = (data['title'] as String?) ?? 'Запрос';
      final exists = await _notificationExists(
        recipientUserId: userId,
        title: 'Услуга завершена заказчиком',
        targetRoute: '/requests/$requestId',
      );
      if (exists) {
        continue;
      }
      await _createNotificationDirectly(
        recipientUserId: userId,
        title: 'Услуга завершена заказчиком',
        body: title,
        targetRoute: '/requests/$requestId',
      );
    }
  }

  Future<void> _ensureReviewNotification(String userId) async {
    final reviews = await _db
        .collection(AppCollections.reviews)
        .where('executorId', isEqualTo: userId)
        .get();
    if (reviews.docs.isEmpty) {
      return;
    }
    final exists = await _notificationExists(
      recipientUserId: userId,
      title: 'Вы получили новый отзыв',
      targetRoute: '/profile/reviews/$userId',
    );
    if (exists) {
      return;
    }
    final latest =
        reviews.docs
            .map((doc) => doc.data())
            .where((data) => data['createdAt'] is Timestamp)
            .toList()
          ..sort(
            (a, b) => (b['createdAt'] as Timestamp).compareTo(
              a['createdAt'] as Timestamp,
            ),
          );
    final rating = latest.isEmpty
        ? (reviews.docs.first.data()['rating'] as num?)?.toInt()
        : (latest.first['rating'] as num?)?.toInt();
    await _createNotificationDirectly(
      recipientUserId: userId,
      title: 'Вы получили новый отзыв',
      body: rating == null ? 'Новый отзыв' : 'Оценка: $rating/5',
      targetRoute: '/profile/reviews/$userId',
    );
  }

  Future<bool> _notificationExists({
    required String recipientUserId,
    required String title,
    required String targetRoute,
  }) async {
    final existing = await _db
        .collection(AppCollections.notifications)
        .where('recipientUserId', isEqualTo: recipientUserId)
        .where('title', isEqualTo: title)
        .where('targetRoute', isEqualTo: targetRoute)
        .limit(1)
        .get();
    return existing.docs.isNotEmpty;
  }

  Future<void> markAsRead(String notificationId) {
    return _db
        .collection(AppCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> _createNotificationDirectly({
    required String recipientUserId,
    required String title,
    required String body,
    required String targetRoute,
  }) {
    return _db.collection(AppCollections.notifications).add({
      'recipientUserId': recipientUserId,
      'title': title,
      'body': body,
      'targetRoute': targetRoute,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _notifyCommunityMembersDirectly({
    required String communityId,
    required String title,
    required String body,
    required String targetRoute,
    required String category,
  }) async {
    final members = await _db
        .collection(AppCollections.communityMembers)
        .where('communityId', isEqualTo: communityId)
        .get();
    for (final member in members.docs) {
      final recipientUserId = member.data()['userId'] as String?;
      if (recipientUserId == null || recipientUserId == _userId) {
        continue;
      }
      final allowed = await _notificationAllowed(
        recipientUserId: recipientUserId,
        preference: NotificationPreference.newRequestsInCommunities,
        category: category,
      );
      if (!allowed) {
        continue;
      }
      await _createNotificationDirectly(
        recipientUserId: recipientUserId,
        title: title,
        body: body,
        targetRoute: targetRoute,
      );
    }
  }

  Future<bool> _notificationAllowed({
    required String recipientUserId,
    required NotificationPreference? preference,
    String? category,
  }) async {
    if (preference == null) {
      return true;
    }
    try {
      final snapshot = await _db
          .collection(AppCollections.users)
          .doc(recipientUserId)
          .collection('notification_settings')
          .doc('default')
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      switch (preference) {
        case NotificationPreference.newRequestsInCommunities:
          final enabled = (data['newRequestsInCommunities'] as bool?) ?? true;
          if (!enabled) {
            return false;
          }
          final subscribedCategories =
              ((data['subscribedCategoryIds'] as List<dynamic>?) ?? const [])
                  .map((id) => id.toString())
                  .where((id) => id.trim().isNotEmpty)
                  .toSet();
          return subscribedCategories.isEmpty ||
              category == null ||
              subscribedCategories.contains(category);
        case NotificationPreference.responsesToMyRequests:
          return (data['responsesToMyRequests'] as bool?) ?? true;
        case NotificationPreference.selectedAsExecutor:
          return (data['selectedAsExecutor'] as bool?) ?? true;
        case NotificationPreference.newReviews:
          return (data['newReviews'] as bool?) ?? true;
      }
    } catch (_) {
      return true;
    }
  }
}
