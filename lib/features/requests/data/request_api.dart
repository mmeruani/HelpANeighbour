import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/constants.dart';
import '../../../core/utils/validators.dart';
import '../../notifications/data/notification_api.dart';
import '../domain/entities/request_enums.dart';
import '../domain/entities/request_response.dart';
import '../domain/entities/service_request.dart';

class RequestApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final NotificationApi _notifications;

  const RequestApi(this._auth, this._db, this._notifications);

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    return user.uid;
  }

  Future<void> _logActivity({
    required String userId,
    required String scope,
    required String message,
    String? communityId,
    String? requestId,
  }) async {
    try {
      await _db.collection(AppCollections.activityEvents).add({
        'userId': userId,
        'scope': scope,
        'message': message,
        'communityId': communityId,
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<bool> _isCommunityMember(String communityId) async {
    final query = await _db
        .collection(AppCollections.communityMembers)
        .where('communityId', isEqualTo: communityId)
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> _ensureCommunityMember(String communityId) async {
    final isMember = await _isCommunityMember(communityId);
    if (!isMember) {
      throw StateError(
        'Доступ к запросам сообщества разрешён только участникам',
      );
    }
  }

  void _validateRequestFields({
    required String title,
    required String category,
    required String description,
    required DateTime? desiredExecutionAt,
    required RewardType rewardType,
    required int? rewardAmount,
    required String? address,
    required String contactDetails,
  }) {
    if (title.trim().isEmpty || title.trim().length > 100) {
      throw StateError('Некорректное название запроса');
    }
    final categoryError = Validators.customCategory(category);
    if (categoryError != null) {
      throw StateError(categoryError);
    }
    if (description.trim().length > 1000) {
      throw StateError('Описание запроса слишком длинное');
    }
    final addressError = Validators.requestAddress(address);
    if (addressError != null) {
      throw StateError(addressError);
    }
    if (desiredExecutionAt != null &&
        desiredExecutionAt.isBefore(DateTime.now())) {
      throw StateError('Некорректное время выполнения');
    }
    if (rewardType == RewardType.fixed) {
      if (rewardAmount == null ||
          rewardAmount < AppLimits.rewardMinAmount ||
          rewardAmount > AppLimits.rewardMaxAmount) {
        throw StateError('Некорректная сумма вознаграждения');
      }
    }
    final trimmedContact = contactDetails.trim();
    if (trimmedContact.length < AppLimits.contactDetailsMinLength ||
        trimmedContact.length > AppLimits.contactDetailsMaxLength) {
      throw StateError(
        'Некорректные контактные данные. Укажите телефон, ссылку или другой способ связи.',
      );
    }
  }

  Future<ServiceRequest> _mapRequest(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? <String, dynamic>{};
    final customerId = (data['customerId'] as String?) ?? '';
    final executorId = data['executorId'] as String?;
    final communityId = (data['communityId'] as String?) ?? '';
    final customerData = await _publicUserData(customerId);
    final communityDoc = communityId.isEmpty
        ? null
        : await _db
              .collection(AppCollections.communities)
              .doc(communityId)
              .get();
    final executorData = executorId == null
        ? <String, dynamic>{}
        : await _publicUserData(executorId);
    final responsesCount = await _responsesCountForRequest(
      doc.id,
      fallback: ((data['responsesCount'] as num?) ?? 0).toInt(),
    );
    return ServiceRequest(
      id: doc.id,
      communityId: communityId,
      communityName: (communityDoc?.data()?['name'] as String?) ?? '',
      customerId: customerId,
      customerName: (customerData['name'] as String?) ?? '',
      customerAvatarUrl: customerData['avatarUrl'] as String?,
      customerRating: ((customerData['rating'] as num?) ?? 0).toDouble(),
      customerReviewsCount: ((customerData['reviewsCount'] as num?) ?? 0)
          .toInt(),
      executorId: executorId,
      executorName: executorId == null
          ? null
          : (executorData['name'] as String?) ?? '',
      executorAvatarUrl: executorData['avatarUrl'] as String?,
      executorRating: executorId == null
          ? null
          : ((executorData['rating'] as num?) ?? 0).toDouble(),
      executorReviewsCount: executorId == null
          ? 0
          : ((executorData['reviewsCount'] as num?) ?? 0).toInt(),
      title: (data['title'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      urgency: RequestUrgency.values.firstWhere(
        (value) => value.name == data['urgency'],
        orElse: () => RequestUrgency.flexible,
      ),
      desiredExecutionAt: (data['desiredExecutionAt'] as Timestamp?)?.toDate(),
      rewardType: RewardType.values.firstWhere(
        (value) => value.name == data['rewardType'],
        orElse: () => RewardType.none,
      ),
      rewardAmount: (data['rewardAmount'] as num?)?.toInt(),
      address: data['address'] as String?,
      contactDetails: (data['contactDetails'] as String?) ?? '',
      status: RequestStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => RequestStatus.active,
      ),
      responsesCount: responsesCount,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Future<int> _responsesCountForRequest(
    String requestId, {
    required int fallback,
  }) async {
    try {
      final query = await _db
          .collection(AppCollections.requestResponses)
          .where('requestId', isEqualTo: requestId)
          .get();
      return query.docs.length;
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<String, dynamic>> _publicUserData(String userId) async {
    if (userId.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final userDoc = await _db
          .collection(AppCollections.publicUsers)
          .doc(userId)
          .get();
      return userDoc.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _incrementCompletedServicesCount(String userId) async {
    try {
      await _db.collection(AppCollections.users).doc(userId).set({
        'completedServicesCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      await _db.collection(AppCollections.publicUsers).doc(userId).set({
        'completedServicesCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  RequestResponse _mapResponse(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return RequestResponse(
      id: doc.id,
      requestId: (data['requestId'] as String?) ?? '',
      executorId: (data['executorId'] as String?) ?? '',
      executorName: (data['executorName'] as String?) ?? '',
      executorAvatarUrl: data['executorAvatarUrl'] as String?,
      executorRating: ((data['executorRating'] as num?) ?? 0).toDouble(),
      executorReviewsCount: ((data['executorReviewsCount'] as num?) ?? 0)
          .toInt(),
      comment: (data['comment'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Future<ServiceRequest> createRequest({
    required String communityId,
    required String title,
    required String category,
    required String description,
    required RequestUrgency urgency,
    DateTime? desiredExecutionAt,
    required RewardType rewardType,
    int? rewardAmount,
    String? address,
    required String contactDetails,
  }) async {
    await _ensureCommunityMember(communityId);
    _validateRequestFields(
      title: title,
      category: category,
      description: description,
      desiredExecutionAt: desiredExecutionAt,
      rewardType: rewardType,
      rewardAmount: rewardAmount,
      address: address,
      contactDetails: contactDetails,
    );
    final ref = _db.collection(AppCollections.requests).doc();
    await ref.set({
      'communityId': communityId,
      'customerId': _userId,
      'executorId': null,
      'title': title.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'urgency': urgency.name,
      'desiredExecutionAt': desiredExecutionAt == null
          ? null
          : Timestamp.fromDate(desiredExecutionAt),
      'rewardType': rewardType.name,
      'rewardAmount': rewardAmount,
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'contactDetails': contactDetails.trim(),
      'status': RequestStatus.active.name,
      'responsesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.notifyCommunityMembersAboutNewRequest(
      communityId: communityId,
      title: 'Новый запрос в сообществе',
      body: title.trim(),
      targetRoute: '/requests/${ref.id}',
      category: category.trim(),
      urgencyLabel: urgency == RequestUrgency.urgent ? 'Срочный' : 'Несрочный',
    );

    final communityDoc = await _db
        .collection(AppCollections.communities)
        .doc(communityId)
        .get();
    final communityName =
        (communityDoc.data()?['name'] as String?) ?? 'Без названия';
    await _logActivity(
      userId: _userId,
      scope: 'customer',
      communityId: communityId,
      requestId: ref.id,
      message: 'Создан запрос "$title" в сообществе "$communityName"',
    );

    final snapshot = await ref.get();
    return _mapRequest(snapshot);
  }

  Future<List<ServiceRequest>> getCommunityRequests(String communityId) async {
    await _ensureCommunityMember(communityId);
    final query = await _db
        .collection(AppCollections.requests)
        .where('communityId', isEqualTo: communityId)
        .get();

    final items = await Future.wait(query.docs.map(_mapRequest));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<ServiceRequest>> getMyRequests() async {
    final query = await _db
        .collection(AppCollections.requests)
        .where('customerId', isEqualTo: _userId)
        .get();
    final items = await Future.wait(query.docs.map(_mapRequest));
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<List<ServiceRequest>> getExecutorHistory() async {
    final responseQuery = await _db
        .collection(AppCollections.requestResponses)
        .where('executorId', isEqualTo: _userId)
        .get();

    final requestIds = responseQuery.docs
        .map((doc) => (doc.data()['requestId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (requestIds.isEmpty) {
      return const [];
    }

    final requests = <ServiceRequest>[];
    for (final requestId in requestIds) {
      final doc = await _db
          .collection(AppCollections.requests)
          .doc(requestId)
          .get();
      if (doc.exists) {
        requests.add(await _mapRequest(doc));
      }
    }
    requests.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return requests;
  }

  Future<ServiceRequest> getRequestDetails(String requestId) async {
    final doc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final communityId = (doc.data()?['communityId'] as String?) ?? '';
    if (communityId.isNotEmpty) {
      await _ensureCommunityMember(communityId);
    }
    return _mapRequest(doc);
  }

  Future<void> updateRequest(ServiceRequest request) async {
    _validateRequestFields(
      title: request.title,
      category: request.category,
      description: request.description,
      desiredExecutionAt: request.desiredExecutionAt,
      rewardType: request.rewardType,
      rewardAmount: request.rewardAmount,
      address: request.address,
      contactDetails: request.contactDetails,
    );
    await _updateRequestWithNotifications(request);
  }

  Future<void> cancelRequest(String requestId) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final data = requestDoc.data() ?? <String, dynamic>{};
    if ((data['customerId'] as String?) != _userId) {
      throw StateError('Отменить запрос может только заказчик');
    }
    final status = data['status'] as String? ?? RequestStatus.active.name;
    if (status == RequestStatus.completed.name) {
      throw StateError('Завершённый запрос нельзя отменить');
    }

    final executorId = data['executorId'] as String?;
    final title = (data['title'] as String?) ?? 'Запрос';
    final communityId = (data['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    await _db.collection(AppCollections.requests).doc(requestId).update({
      'status': RequestStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _logActivity(
      userId: _userId,
      scope: 'customer',
      communityId: communityId,
      requestId: requestId,
      message: 'Запрос "$title" отменён в сообществе "$communityName"',
    );

    if (executorId != null) {
      await _notifications.createNotification(
        recipientUserId: executorId,
        title: 'Заказчик отменил запрос',
        body: title,
        targetRoute: '/requests/$requestId',
        preference: NotificationPreference.selectedAsExecutor,
      );
    }
  }

  Future<void> deleteRequestFromHistory(String requestId) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final data = requestDoc.data() ?? <String, dynamic>{};
    if ((data['customerId'] as String?) != _userId) {
      throw StateError('Удалить запрос из истории может только заказчик');
    }
    final status = data['status'] as String? ?? RequestStatus.active.name;
    if (status != RequestStatus.completed.name &&
        status != RequestStatus.cancelled.name) {
      throw StateError(
        'Удалять из истории можно только завершённые или отменённые запросы',
      );
    }
    await _db.collection(AppCollections.requests).doc(requestId).delete();
  }

  Future<List<RequestResponse>> getRequestResponses(String requestId) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    if ((requestData['customerId'] as String?) != _userId) {
      final ownResponse = await _db
          .collection(AppCollections.requestResponses)
          .where('requestId', isEqualTo: requestId)
          .where('executorId', isEqualTo: _userId)
          .limit(1)
          .get();
      return ownResponse.docs.map(_mapResponse).toList();
    }
    final query = await _db
        .collection(AppCollections.requestResponses)
        .where('requestId', isEqualTo: requestId)
        .get();
    final items = query.docs.map(_mapResponse).toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> respondToRequest({
    required String requestId,
    required String comment,
  }) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    final customerId = requestData['customerId'] as String?;
    final communityId = (requestData['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    await _ensureCommunityMember(communityId);
    if (customerId == _userId) {
      throw StateError('Нельзя откликнуться на собственный запрос');
    }
    final status =
        (requestData['status'] as String?) ?? RequestStatus.active.name;
    if (status != RequestStatus.active.name) {
      throw StateError('Откликнуться можно только на активный запрос');
    }

    final existing = await _db
        .collection(AppCollections.requestResponses)
        .where('requestId', isEqualTo: requestId)
        .where('executorId', isEqualTo: _userId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('Вы уже откликались на этот запрос');
    }

    final userDoc = await _db
        .collection(AppCollections.users)
        .doc(_userId)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    await _db.collection(AppCollections.requestResponses).add({
      'requestId': requestId,
      'executorId': _userId,
      'executorName': (userData['name'] as String?) ?? '',
      'executorAvatarUrl': userData['avatarUrl'] as String?,
      'executorRating': ((userData['rating'] as num?) ?? 0).toDouble(),
      'executorReviewsCount': ((userData['reviewsCount'] as num?) ?? 0).toInt(),
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final title = (requestData['title'] as String?) ?? 'Запрос';
    try {
      await _db.collection(AppCollections.requests).doc(requestId).update({
        'responsesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    await _logActivity(
      userId: _userId,
      scope: 'executor',
      communityId: communityId,
      requestId: requestId,
      message: 'Отклик на запрос "$title" в сообществе "$communityName"',
    );

    if (customerId != null) {
      await _notifications.createNotification(
        recipientUserId: customerId,
        title: 'Новый отклик на ваш запрос',
        body: (requestDoc.data()?['title'] as String?) ?? 'Открыт новый отклик',
        targetRoute: '/requests/$requestId',
        preference: NotificationPreference.responsesToMyRequests,
      );
    }
  }

  Future<void> cancelResponse(String requestId) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    final customerId = requestData['customerId'] as String?;
    final title = (requestData['title'] as String?) ?? 'Запрос';
    final communityId = (requestData['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    final existing = await _db
        .collection(AppCollections.requestResponses)
        .where('requestId', isEqualTo: requestId)
        .where('executorId', isEqualTo: _userId)
        .limit(1)
        .get();
    if (existing.docs.isEmpty) {
      return;
    }
    await existing.docs.first.reference.delete();
    await _db.collection(AppCollections.requests).doc(requestId).update({
      'responsesCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _logActivity(
      userId: _userId,
      scope: 'executor',
      communityId: communityId,
      requestId: requestId,
      message:
          'Отклик на запрос "$title" отозван в сообществе "$communityName"',
    );
    if (customerId != null) {
      await _notifications.createNotification(
        recipientUserId: customerId,
        title: 'Исполнитель отозвал отклик',
        body: title,
        targetRoute: '/requests/$requestId',
        preference: NotificationPreference.responsesToMyRequests,
      );
    }
  }

  Future<void> selectExecutor({
    required String requestId,
    required String executorId,
  }) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    if ((requestData['customerId'] as String?) != _userId) {
      throw StateError('Выбрать исполнителя может только заказчик');
    }
    final title = (requestData['title'] as String?) ?? 'Запрос';
    final communityId = (requestData['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    final currentStatus =
        (requestData['status'] as String?) ?? RequestStatus.active.name;
    if (currentStatus != RequestStatus.active.name) {
      throw StateError(
        'Исполнителя можно выбрать только для активного запроса',
      );
    }
    final selectedResponse = await _db
        .collection(AppCollections.requestResponses)
        .where('requestId', isEqualTo: requestId)
        .where('executorId', isEqualTo: executorId)
        .limit(1)
        .get();
    if (selectedResponse.docs.isEmpty) {
      throw StateError('Отклик выбранного исполнителя не найден');
    }
    final responseData = selectedResponse.docs.first.data();

    await _db.collection(AppCollections.requests).doc(requestId).update({
      'executorId': executorId,
      'executorName': (responseData['executorName'] as String?) ?? '',
      'executorAvatarUrl': responseData['executorAvatarUrl'],
      'executorRating': ((responseData['executorRating'] as num?) ?? 0)
          .toDouble(),
      'status': RequestStatus.inProgress.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final responses = await _db
        .collection(AppCollections.requestResponses)
        .where('requestId', isEqualTo: requestId)
        .get();

    for (final response in responses.docs) {
      final recipientId = response.data()['executorId'] as String;
      await _notifications.createNotification(
        recipientUserId: recipientId,
        title: recipientId == executorId
            ? 'Вас выбрали исполнителем'
            : 'По запросу выбран другой исполнитель',
        body: title,
        targetRoute: '/requests/$requestId',
        preference: NotificationPreference.selectedAsExecutor,
      );
    }
    await _logActivity(
      userId: _userId,
      scope: 'customer',
      communityId: communityId,
      requestId: requestId,
      message:
          'Выбран исполнитель для запроса "$title" в сообществе "$communityName"',
    );
    await _logActivity(
      userId: executorId,
      scope: 'executor',
      communityId: communityId,
      requestId: requestId,
      message:
          'Вас выбрали исполнителем по запросу "$title" в сообществе "$communityName"',
    );
  }

  Future<void> markAsCompletedByExecutor(String requestId) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    if ((requestData['executorId'] as String?) != _userId) {
      throw StateError(
        'Отметить выполнение может только назначенный исполнитель',
      );
    }
    final customerId = requestData['customerId'] as String?;
    final title = (requestData['title'] as String?) ?? 'Запрос';
    final communityId = (requestData['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    final currentStatus =
        (requestData['status'] as String?) ?? RequestStatus.active.name;
    if (currentStatus != RequestStatus.inProgress.name) {
      throw StateError('Отметить выполнение можно только для запроса в работе');
    }

    await _db.collection(AppCollections.requests).doc(requestId).update({
      'status': RequestStatus.awaitingCustomerConfirmation.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _logActivity(
      userId: _userId,
      scope: 'executor',
      communityId: communityId,
      requestId: requestId,
      message:
          'Запрос "$title" отмечен как выполненный в сообществе "$communityName"',
    );

    if (customerId != null) {
      await _notifications.createNotification(
        recipientUserId: customerId,
        title: 'Исполнитель отметил услугу как выполненную',
        body: title,
        targetRoute: '/requests/$requestId',
        preference: NotificationPreference.responsesToMyRequests,
      );
    }
  }

  Future<void> confirmCompletionByCustomer(String requestId) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    if ((requestData['customerId'] as String?) != _userId) {
      throw StateError('Завершить запрос может только заказчик');
    }
    final executorId = requestData['executorId'] as String?;
    final title = (requestData['title'] as String?) ?? 'Запрос';
    final communityId = (requestData['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    final currentStatus =
        (requestData['status'] as String?) ?? RequestStatus.active.name;
    if (currentStatus != RequestStatus.awaitingCustomerConfirmation.name) {
      throw StateError('Сначала исполнитель должен отметить выполнение услуги');
    }
    await _db.collection(AppCollections.requests).doc(requestId).update({
      'status': RequestStatus.completed.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _logActivity(
      userId: _userId,
      scope: 'customer',
      communityId: communityId,
      requestId: requestId,
      message: 'Запрос "$title" завершён в сообществе "$communityName"',
    );
    if (executorId != null) {
      await _incrementCompletedServicesCount(executorId);
      await _logActivity(
        userId: executorId,
        scope: 'executor',
        communityId: communityId,
        requestId: requestId,
        message:
            'Запрос "$title" завершён заказчиком в сообществе "$communityName"',
      );
      await _notifications.createNotification(
        recipientUserId: executorId,
        title: 'Услуга завершена заказчиком',
        body: title,
        targetRoute: '/requests/$requestId',
      );
      await _notifications.createNotification(
        recipientUserId: _userId,
        title: 'Оставьте отзыв исполнителю',
        body: title,
        targetRoute: '/requests/$requestId/review/$executorId',
      );
    }
  }

  Future<void> refuseExecution({
    required String requestId,
    String? reason,
  }) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(requestId)
        .get();
    final requestData = requestDoc.data() ?? <String, dynamic>{};
    if ((requestData['executorId'] as String?) != _userId) {
      throw StateError(
        'Отказаться от выполнения может только назначенный исполнитель',
      );
    }
    final customerId = requestData['customerId'] as String?;
    final title = (requestData['title'] as String?) ?? 'Запрос';
    final communityId = (requestData['communityId'] as String?) ?? '';
    final communityName =
        ((await _db
                    .collection(AppCollections.communities)
                    .doc(communityId)
                    .get())
                .data()?['name']
            as String?) ??
        'Без названия';
    final currentStatus =
        (requestData['status'] as String?) ?? RequestStatus.active.name;
    if (currentStatus != RequestStatus.inProgress.name) {
      throw StateError('Отказаться можно только от принятого запроса');
    }

    await _db.collection(AppCollections.requests).doc(requestId).update({
      'executorId': null,
      'status': RequestStatus.active.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRefuseReason': reason?.trim(),
    });
    await _logActivity(
      userId: _userId,
      scope: 'executor',
      communityId: communityId,
      requestId: requestId,
      message:
          'Отказ от выполнения запроса "$title" в сообществе "$communityName"',
    );

    if (customerId != null) {
      await _notifications.createNotification(
        recipientUserId: customerId,
        title: 'Исполнитель отказался от выполнения',
        body: title,
        targetRoute: '/requests/$requestId',
        preference: NotificationPreference.responsesToMyRequests,
      );
    }
  }

  Future<void> _updateRequestWithNotifications(ServiceRequest request) async {
    final requestDoc = await _db
        .collection(AppCollections.requests)
        .doc(request.id)
        .get();
    final data = requestDoc.data() ?? <String, dynamic>{};
    if ((data['customerId'] as String?) != _userId) {
      throw StateError('Редактировать запрос может только заказчик');
    }
    final status = data['status'] as String? ?? RequestStatus.active.name;
    if (status != RequestStatus.active.name) {
      throw StateError('Редактировать можно только активные запросы');
    }

    await _db.collection(AppCollections.requests).doc(request.id).update({
      'title': request.title,
      'category': request.category,
      'description': request.description,
      'urgency': request.urgency.name,
      'desiredExecutionAt': request.desiredExecutionAt == null
          ? null
          : Timestamp.fromDate(request.desiredExecutionAt!),
      'rewardType': request.rewardType.name,
      'rewardAmount': request.rewardAmount,
      'address': request.address?.trim().isEmpty == true
          ? null
          : request.address?.trim(),
      'contactDetails': request.contactDetails,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _logActivity(
      userId: _userId,
      scope: 'customer',
      communityId: request.communityId,
      requestId: request.id,
      message:
          'Обновлён запрос "${request.title}" в сообществе "${request.communityName.isEmpty ? 'Без названия' : request.communityName}"',
    );

    final executorId = data['executorId'] as String?;
    if (executorId == null) {
      return;
    }
    await _notifications.createNotification(
      recipientUserId: executorId,
      title: 'Заказчик обновил параметры запроса',
      body: request.title,
      targetRoute: '/requests/${request.id}',
      preference: NotificationPreference.selectedAsExecutor,
    );
  }
}
