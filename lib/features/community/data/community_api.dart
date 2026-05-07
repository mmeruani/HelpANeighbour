import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/constants.dart';
import '../../../core/utils/validators.dart';
import '../../profile/domain/entities/notification_settings.dart';
import '../../profile/domain/entities/profile.dart';
import '../domain/entities/community.dart';
import '../domain/entities/community_member.dart';
import '../domain/entities/community_role.dart';

class CommunityApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  const CommunityApi(this._auth, this._db);

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    return user.uid;
  }

  String _generateInvitationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      AppLimits.invitationCodeLength,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<String> _generateUniqueInvitationCode() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final code = _generateInvitationCode();
      final existing = await _db
          .collection(AppCollections.communities)
          .where('invitationCode', isEqualTo: code)
          .limit(1)
          .get();
      final previouslyUsed = await _db
          .collection(AppCollections.communities)
          .where('previousInvitationCodes', arrayContains: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty && previouslyUsed.docs.isEmpty) {
        return code;
      }
    }
    throw StateError('Не удалось создать уникальный код приглашения');
  }

  Future<void> _logActivity({
    required String message,
    String scope = 'app',
    String? communityId,
    String? requestId,
  }) async {
    try {
      await _db.collection(AppCollections.activityEvents).add({
        'userId': _userId,
        'scope': scope,
        'message': message,
        'communityId': communityId,
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _syncPublicCommunityIds(
    String userId,
    FieldValue communityIdsValue,
  ) async {
    try {
      await _db.collection(AppCollections.publicUsers).doc(userId).set({
        'communityIds': communityIdsValue,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<List<Community>> getMyCommunities() async {
    final memberships = await _db
        .collection(AppCollections.communityMembers)
        .where('userId', isEqualTo: _userId)
        .get();

    if (memberships.docs.isEmpty) {
      return const [];
    }

    final communities = await Future.wait(
      memberships.docs.map((doc) async {
        final communityId = doc.data()['communityId'] as String;
        final communityDoc = await _db
            .collection(AppCollections.communities)
            .doc(communityId)
            .get();
        final data = communityDoc.data() ?? <String, dynamic>{};
        return Community(
          id: communityDoc.id,
          name: (data['name'] as String?) ?? '',
          description: (data['description'] as String?) ?? '',
          imageUrl: data['imageUrl'] as String?,
          invitationCode: (data['invitationCode'] as String?) ?? '',
          invitationLink: (data['invitationLink'] as String?) ?? '',
          creatorId: (data['creatorId'] as String?) ?? '',
          membersCount: ((data['membersCount'] as num?) ?? 0).toInt(),
          currentUserRole: doc.data()['role'] == CommunityRole.creator.name
              ? CommunityRole.creator
              : CommunityRole.participant,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }),
    );

    communities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return communities;
  }

  Future<Community> createCommunity({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    final nameError = Validators.communityName(name);
    if (nameError != null) {
      throw StateError(nameError);
    }
    final descriptionError = Validators.communityDescription(description);
    if (descriptionError != null) {
      throw StateError(descriptionError);
    }

    final code = await _generateUniqueInvitationCode();
    final ref = _db.collection(AppCollections.communities).doc();
    final invitationLink = 'helpaneighbour://community/${ref.id}?code=$code';

    await ref.set({
      'name': name.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl,
      'invitationCode': code,
      'invitationLink': invitationLink,
      'previousInvitationCodes': [code],
      'creatorId': _userId,
      'membersCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection(AppCollections.communityMembers)
        .doc('${ref.id}_$_userId')
        .set({
          'communityId': ref.id,
          'userId': _userId,
          'role': CommunityRole.creator.name,
          'joinedAt': FieldValue.serverTimestamp(),
        });

    await _db.collection(AppCollections.users).doc(_userId).set({
      'communityIds': FieldValue.arrayUnion([ref.id]),
    }, SetOptions(merge: true));
    await _syncPublicCommunityIds(_userId, FieldValue.arrayUnion([ref.id]));

    await _logActivity(
      message: 'Создано сообщество "$name"',
      communityId: ref.id,
    );

    return Community(
      id: ref.id,
      name: name.trim(),
      description: description.trim(),
      imageUrl: imageUrl,
      invitationCode: code,
      invitationLink: invitationLink,
      creatorId: _userId,
      membersCount: 1,
      currentUserRole: CommunityRole.creator,
      createdAt: DateTime.now(),
    );
  }

  Future<void> updateCommunity({
    required String communityId,
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    final nameError = Validators.communityName(name);
    if (nameError != null) {
      throw StateError(nameError);
    }
    final descriptionError = Validators.communityDescription(description);
    if (descriptionError != null) {
      throw StateError(descriptionError);
    }

    await _db.collection(AppCollections.communities).doc(communityId).update({
      'name': name.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl,
    });
  }

  Future<void> regenerateInvitationCode(String communityId) async {
    final community = await _db
        .collection(AppCollections.communities)
        .doc(communityId)
        .get();
    final oldCode = community.data()?['invitationCode'] as String?;
    final code = await _generateUniqueInvitationCode();
    final invitationLink = 'helpaneighbour://community/$communityId?code=$code';
    await _db.collection(AppCollections.communities).doc(communityId).update({
      'invitationCode': code,
      'invitationLink': invitationLink,
      'previousInvitationCodes': FieldValue.arrayUnion([
        if (oldCode != null && oldCode.isNotEmpty) oldCode,
        code,
      ]),
    });
  }

  Future<void> deleteCommunity(String communityId) async {
    final communityRef = _db
        .collection(AppCollections.communities)
        .doc(communityId);
    final community = await communityRef.get();
    if (!community.exists) {
      throw StateError('Сообщество не найдено');
    }
    if (community.data()?['creatorId'] != _userId) {
      throw StateError('Удалить сообщество может только создатель');
    }

    final requestDocs = await _db
        .collection(AppCollections.requests)
        .where('communityId', isEqualTo: communityId)
        .get();
    final memberDocs = await _db
        .collection(AppCollections.communityMembers)
        .where('communityId', isEqualTo: communityId)
        .get();

    for (final requestDoc in requestDocs.docs) {
      await _deleteRequestRelatedData(requestDoc.id);
      await requestDoc.reference.delete();
    }
    for (final memberDoc in memberDocs.docs) {
      await memberDoc.reference.delete();
    }
    await communityRef.delete();

    await _db.collection(AppCollections.users).doc(_userId).set({
      'communityIds': FieldValue.arrayRemove([communityId]),
    }, SetOptions(merge: true));
    await _syncPublicCommunityIds(
      _userId,
      FieldValue.arrayRemove([communityId]),
    );
  }

  Future<void> _deleteRequestRelatedData(String requestId) async {
    final responseDocs = await _db
        .collection(AppCollections.requestResponses)
        .where('requestId', isEqualTo: requestId)
        .get();
    for (final responseDoc in responseDocs.docs) {
      await responseDoc.reference.delete();
    }

    final reviewDocs = await _db
        .collection(AppCollections.reviews)
        .where('requestId', isEqualTo: requestId)
        .get();
    final reviewExecutorIds = reviewDocs.docs
        .map((doc) => doc.data()['executorId'] as String?)
        .whereType<String>()
        .toSet();
    for (final reviewDoc in reviewDocs.docs) {
      await reviewDoc.reference.delete();
    }
    for (final executorId in reviewExecutorIds) {
      await _recalculateUserRating(executorId);
    }
  }

  Future<void> _recalculateUserRating(String userId) async {
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
  }

  Future<void> joinCommunityByCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    final codeError = Validators.invitationCode(normalizedCode);
    if (codeError != null) {
      throw StateError(codeError);
    }
    final QuerySnapshot<Map<String, dynamic>> query;
    try {
      query = await _db
          .collection(AppCollections.communities)
          .where('invitationCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'Не удалось проверить код приглашения. Попробуйте вступить по полной ссылке или повторите попытку позже.',
        );
      }
      rethrow;
    }

    if (query.docs.isEmpty) {
      throw StateError('Некорректный код приглашения');
    }

    final communityId = query.docs.first.id;
    final communityName =
        (query.docs.first.data()['name'] as String?) ?? 'Без названия';
    await _joinCommunityDirectly(
      communityId: communityId,
      communityName: communityName,
    );
  }

  Future<void> _joinCommunityDirectly({
    required String communityId,
    String? expectedCode,
    String? communityName,
  }) async {
    final communityRef = _db
        .collection(AppCollections.communities)
        .doc(communityId);
    try {
      final communitySnapshot = await communityRef.get();
      final data = communitySnapshot.data();
      if (data == null) {
        throw StateError('Сообщество не найдено');
      }
      final actualCode = (data['invitationCode'] as String?)?.toUpperCase();
      if (expectedCode != null &&
          actualCode != null &&
          actualCode != expectedCode.toUpperCase()) {
        throw StateError('Некорректный код приглашения');
      }
      communityName ??= (data['name'] as String?) ?? 'Без названия';
    } on StateError {
      rethrow;
    } catch (_) {}

    final membershipRef = _db
        .collection(AppCollections.communityMembers)
        .doc('${communityId}_$_userId');
    try {
      final membershipSnapshot = await membershipRef.get();
      if (membershipSnapshot.exists) {
        throw StateError('Вы уже состоите в этом сообществе');
      }
    } on StateError {
      rethrow;
    } catch (_) {}
    try {
      await membershipRef.set({
        'communityId': communityId,
        'userId': _userId,
        'role': CommunityRole.participant.name,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));
    } on FirebaseException catch (e) {
      if (e.code == 'already-exists') {
        throw StateError('Вы уже состоите в этом сообществе');
      }
      rethrow;
    }

    await _syncJoinedCommunityMetadata(communityId);
    await _logActivity(
      message: 'Вступление в сообщество "${communityName ?? 'Без названия'}"',
      communityId: communityId,
    );
  }

  Future<void> _syncJoinedCommunityMetadata(String communityId) async {
    try {
      await _db.collection(AppCollections.communities).doc(communityId).update({
        'membersCount': FieldValue.increment(1),
      });
    } catch (_) {}
    try {
      await _db.collection(AppCollections.users).doc(_userId).set({
        'communityIds': FieldValue.arrayUnion([communityId]),
      }, SetOptions(merge: true));
    } catch (_) {}
    await _syncPublicCommunityIds(
      _userId,
      FieldValue.arrayUnion([communityId]),
    );
  }

  Future<void> joinCommunityByLink(String link) async {
    final uri = Uri.tryParse(link.trim());
    final code = uri?.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw StateError('Некорректная ссылка приглашения');
    }
    final communityId = _communityIdFromInvitationUri(uri!);
    if (communityId == null || communityId.isEmpty) {
      await joinCommunityByCode(code);
      return;
    }
    await _joinCommunityDirectly(
      communityId: communityId,
      expectedCode: code.trim().toUpperCase(),
    );
  }

  String? _communityIdFromInvitationUri(Uri uri) {
    if (uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    if (uri.host.isNotEmpty && uri.host != 'community') {
      return uri.host;
    }
    return null;
  }

  Future<void> leaveCommunity(String communityId) async {
    final membershipRef = _db
        .collection(AppCollections.communityMembers)
        .doc('${communityId}_$_userId');
    final membership = await membershipRef.get();
    final role = membership.data()?['role'] as String?;

    if (role == CommunityRole.creator.name) {
      throw StateError(
        'Создатель не может покинуть сообщество без передачи роли или удаления сообщества',
      );
    }

    await membershipRef.delete();
    await _db.collection(AppCollections.communities).doc(communityId).update({
      'membersCount': FieldValue.increment(-1),
    });
    await _db.collection(AppCollections.users).doc(_userId).set({
      'communityIds': FieldValue.arrayRemove([communityId]),
    }, SetOptions(merge: true));
    await _syncPublicCommunityIds(
      _userId,
      FieldValue.arrayRemove([communityId]),
    );
    final communitySnapshot = await _db
        .collection(AppCollections.communities)
        .doc(communityId)
        .get();
    final communityName =
        (communitySnapshot.data()?['name'] as String?) ?? 'Без названия';
    await _logActivity(
      message: 'Выход из сообщества "$communityName"',
      communityId: communityId,
    );
  }

  Future<List<CommunityMember>> getCommunityMembers(String communityId) async {
    final members = await _db
        .collection(AppCollections.communityMembers)
        .where('communityId', isEqualTo: communityId)
        .get();

    return Future.wait(
      members.docs.map((doc) async {
        final data = doc.data();
        final userId = data['userId'] as String;
        final userData = await _publicUserData(userId);

        final profile = Profile(
          userId: userId,
          email: '',
          phone: '',
          name: (userData['name'] as String?) ?? '',
          avatarUrl: userData['avatarUrl'] as String?,
          bio: (userData['bio'] as String?) ?? '',
          rating: ((userData['rating'] as num?) ?? 0).toDouble(),
          completedServicesCount:
              ((userData['completedServicesCount'] as num?) ?? 0).toInt(),
          reviewsCount: ((userData['reviewsCount'] as num?) ?? 0).toInt(),
          communityIds:
              ((userData['communityIds'] as List<dynamic>?) ?? const [])
                  .map((id) => id.toString())
                  .toList(),
          notificationSettings: NotificationSettings.defaults(),
        );

        return CommunityMember(
          communityId: communityId,
          userId: userId,
          role: data['role'] == CommunityRole.creator.name
              ? CommunityRole.creator
              : CommunityRole.participant,
          joinedAt:
              (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          profile: profile,
        );
      }),
    );
  }

  Future<Map<String, dynamic>> _publicUserData(String userId) async {
    try {
      final userSnapshot = await _db
          .collection(AppCollections.publicUsers)
          .doc(userId)
          .get();
      return userSnapshot.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> removeMember({
    required String communityId,
    required String memberUserId,
  }) async {
    await _db
        .collection(AppCollections.communityMembers)
        .doc('${communityId}_$memberUserId')
        .delete();
    await _db.collection(AppCollections.communities).doc(communityId).update({
      'membersCount': FieldValue.increment(-1),
    });
    if (memberUserId == _userId) {
      await _db.collection(AppCollections.users).doc(memberUserId).set({
        'communityIds': FieldValue.arrayRemove([communityId]),
      }, SetOptions(merge: true));
    }
    await _syncPublicCommunityIds(
      memberUserId,
      FieldValue.arrayRemove([communityId]),
    );
  }

  Future<void> transferCreatorRole({
    required String communityId,
    required String newCreatorUserId,
  }) async {
    final currentCreatorRef = _db
        .collection(AppCollections.communityMembers)
        .doc('${communityId}_$_userId');
    final newCreatorRef = _db
        .collection(AppCollections.communityMembers)
        .doc('${communityId}_$newCreatorUserId');

    final batch = _db.batch();
    batch.update(currentCreatorRef, {'role': CommunityRole.participant.name});
    batch.update(newCreatorRef, {'role': CommunityRole.creator.name});
    batch.update(_db.collection(AppCollections.communities).doc(communityId), {
      'creatorId': newCreatorUserId,
    });
    await batch.commit();
  }
}
