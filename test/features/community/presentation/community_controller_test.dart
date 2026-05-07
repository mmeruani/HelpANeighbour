import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/features/community/domain/entities/community.dart';
import 'package:help_a_neighbour/features/community/domain/entities/community_member.dart';
import 'package:help_a_neighbour/features/community/domain/entities/community_role.dart';
import 'package:help_a_neighbour/features/community/domain/repositories/community_repository.dart';
import 'package:help_a_neighbour/features/community/presentation/controllers/community_controller.dart';
import 'package:help_a_neighbour/features/profile/domain/entities/notification_settings.dart';
import 'package:help_a_neighbour/features/profile/domain/entities/profile.dart';

void main() {
  group('CommunityController', () {
    test('does not load communities before auth is ready', () async {
      final repository = _FakeCommunityRepository();
      final controller = CommunityController(repository, () async => false);
      addTearDown(controller.dispose);

      await _flushMicrotasks();

      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.communities, isEmpty);
      expect(repository.getMyCommunitiesCalls, 0);
    });

    test('loads user communities when auth is ready', () async {
      final community = _community(id: 'c1', name: 'Дом');
      final repository = _FakeCommunityRepository(communities: [community]);
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);

      await _flushMicrotasks();

      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.communities, [community]);
      expect(repository.getMyCommunitiesCalls, 1);
    });

    test('createCommunity forwards data and reloads communities', () async {
      final repository = _FakeCommunityRepository();
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);
      await _flushMicrotasks();

      final success = await controller.createCommunity(
        name: 'Подъезд',
        description: 'Соседи подъезда',
        imageUrl: 'https://example.com/image.jpg',
      );

      expect(success, isTrue);
      expect(repository.createdName, 'Подъезд');
      expect(repository.createdDescription, 'Соседи подъезда');
      expect(repository.createdImageUrl, 'https://example.com/image.jpg');
      expect(controller.state.communities.single.name, 'Подъезд');
      expect(controller.state.error, isNull);
    });

    test('joinCommunityByCode reloads communities after success', () async {
      final repository = _FakeCommunityRepository(
        communityToJoin: _community(id: 'joined', name: 'Улица'),
      );
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);
      await _flushMicrotasks();

      final success = await controller.joinCommunityByCode('ABC12345');

      expect(success, isTrue);
      expect(repository.joinedCode, 'ABC12345');
      expect(controller.state.communities.single.id, 'joined');
    });

    test('joinCommunityByLink maps repository error', () async {
      final repository = _FakeCommunityRepository(
        joinLinkError: StateError('Ссылка приглашения не найдена'),
      );
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);
      await _flushMicrotasks();

      final success = await controller.joinCommunityByLink('bad-link');

      expect(success, isFalse);
      expect(controller.state.loading, isFalse);
      expect(controller.state.error, 'Ссылка приглашения не найдена');
    });

    test('loadMembers stores members by community', () async {
      final member = _member(communityId: 'c1', userId: 'user-1');
      final repository = _FakeCommunityRepository(members: [member]);
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);
      await _flushMicrotasks();

      await controller.loadMembers('c1');

      expect(controller.state.membersByCommunity['c1'], [member]);
      expect(controller.state.memberErrorsByCommunity['c1'], isNull);
    });

    test(
      'loadMembers stores member-specific errors without global error',
      () async {
        final repository = _FakeCommunityRepository(
          membersError: Exception('permission-denied'),
        );
        final controller = CommunityController(repository, () async => true);
        addTearDown(controller.dispose);
        await _flushMicrotasks();

        await controller.loadMembers('c1');

        expect(
          controller.state.memberErrorsByCommunity['c1'],
          'Недостаточно прав для выполнения этого действия.',
        );
        expect(controller.state.error, isNull);
      },
    );

    test('removeMember reloads members and communities', () async {
      final repository = _FakeCommunityRepository(
        communities: [_community(id: 'c1', membersCount: 2)],
        members: [_member(communityId: 'c1', userId: 'creator')],
      );
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);
      await _flushMicrotasks();

      final success = await controller.removeMember(
        communityId: 'c1',
        memberUserId: 'user-2',
      );

      expect(success, isTrue);
      expect(repository.removedMemberUserId, 'user-2');
      expect(repository.loadedMembersCommunityId, 'c1');
      expect(repository.getMyCommunitiesCalls, greaterThanOrEqualTo(2));
    });

    test('transferCreatorRole reloads members and communities', () async {
      final repository = _FakeCommunityRepository(
        communities: [_community(id: 'c1')],
        members: [_member(communityId: 'c1', userId: 'new-creator')],
      );
      final controller = CommunityController(repository, () async => true);
      addTearDown(controller.dispose);
      await _flushMicrotasks();

      final success = await controller.transferCreatorRole(
        communityId: 'c1',
        newCreatorUserId: 'new-creator',
      );

      expect(success, isTrue);
      expect(repository.transferredCreatorUserId, 'new-creator');
      expect(repository.loadedMembersCommunityId, 'c1');
    });
  });
}

class _FakeCommunityRepository implements CommunityRepository {
  final Object? joinLinkError;
  final Object? membersError;
  final Community? communityToJoin;
  List<Community> communities;
  List<CommunityMember> members;

  int getMyCommunitiesCalls = 0;
  String? createdName;
  String? createdDescription;
  String? createdImageUrl;
  String? joinedCode;
  String? joinedLink;
  String? loadedMembersCommunityId;
  String? removedMemberUserId;
  String? transferredCreatorUserId;

  _FakeCommunityRepository({
    this.communities = const [],
    this.members = const [],
    this.communityToJoin,
    this.joinLinkError,
    this.membersError,
  });

  @override
  Future<List<Community>> getMyCommunities() async {
    getMyCommunitiesCalls += 1;
    return communities;
  }

  @override
  Future<Community> createCommunity({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    createdName = name;
    createdDescription = description;
    createdImageUrl = imageUrl;
    final community = _community(id: 'created', name: name);
    communities = [community];
    return community;
  }

  @override
  Future<void> joinCommunityByCode(String code) async {
    joinedCode = code;
    communities = [communityToJoin ?? _community(id: 'joined', name: 'Дом')];
  }

  @override
  Future<void> joinCommunityByLink(String link) async {
    final error = joinLinkError;
    if (error != null) {
      throw error;
    }
    joinedLink = link;
    communities = [communityToJoin ?? _community(id: 'joined', name: 'Дом')];
  }

  @override
  Future<List<CommunityMember>> getCommunityMembers(String communityId) async {
    final error = membersError;
    if (error != null) {
      throw error;
    }
    loadedMembersCommunityId = communityId;
    return members
        .where((member) => member.communityId == communityId)
        .toList();
  }

  @override
  Future<void> removeMember({
    required String communityId,
    required String memberUserId,
  }) async {
    removedMemberUserId = memberUserId;
    members = members.where((member) => member.userId != memberUserId).toList();
  }

  @override
  Future<void> transferCreatorRole({
    required String communityId,
    required String newCreatorUserId,
  }) async {
    transferredCreatorUserId = newCreatorUserId;
  }

  @override
  Future<void> deleteCommunity(String communityId) async {
    communities = communities
        .where((community) => community.id != communityId)
        .toList();
  }

  @override
  Future<void> leaveCommunity(String communityId) async {
    communities = communities
        .where((community) => community.id != communityId)
        .toList();
  }

  @override
  Future<void> regenerateInvitationCode(String communityId) async {}

  @override
  Future<void> updateCommunity({
    required String communityId,
    required String name,
    required String description,
    String? imageUrl,
  }) async {}
}

Community _community({
  required String id,
  String name = 'Дом',
  int membersCount = 1,
}) {
  return Community(
    id: id,
    name: name,
    description: 'Описание',
    imageUrl: null,
    invitationCode: 'ABC12345',
    invitationLink: 'invite-link',
    creatorId: 'creator',
    membersCount: membersCount,
    currentUserRole: CommunityRole.creator,
    createdAt: DateTime(2026, 5, 6),
  );
}

CommunityMember _member({
  required String communityId,
  required String userId,
  CommunityRole role = CommunityRole.participant,
}) {
  return CommunityMember(
    communityId: communityId,
    userId: userId,
    role: role,
    joinedAt: DateTime(2026, 5, 6),
    profile: Profile(
      userId: userId,
      email: '$userId@example.com',
      phone: '+79991234567',
      name: userId,
      avatarUrl: null,
      bio: '',
      rating: 0,
      completedServicesCount: 0,
      reviewsCount: 0,
      communityIds: [communityId],
      notificationSettings: NotificationSettings.defaults(),
    ),
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
