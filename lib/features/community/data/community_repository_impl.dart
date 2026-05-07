import '../domain/entities/community.dart';
import '../domain/entities/community_member.dart';
import '../domain/repositories/community_repository.dart';
import 'community_api.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityApi _api;

  const CommunityRepositoryImpl(this._api);

  @override
  Future<Community> createCommunity({
    required String name,
    required String description,
    String? imageUrl,
  }) {
    return _api.createCommunity(
      name: name,
      description: description,
      imageUrl: imageUrl,
    );
  }

  @override
  Future<void> deleteCommunity(String communityId) =>
      _api.deleteCommunity(communityId);

  @override
  Future<List<CommunityMember>> getCommunityMembers(String communityId) =>
      _api.getCommunityMembers(communityId);

  @override
  Future<List<Community>> getMyCommunities() => _api.getMyCommunities();

  @override
  Future<void> joinCommunityByCode(String code) =>
      _api.joinCommunityByCode(code);

  @override
  Future<void> joinCommunityByLink(String link) =>
      _api.joinCommunityByLink(link);

  @override
  Future<void> leaveCommunity(String communityId) =>
      _api.leaveCommunity(communityId);

  @override
  Future<void> regenerateInvitationCode(String communityId) {
    return _api.regenerateInvitationCode(communityId);
  }

  @override
  Future<void> removeMember({
    required String communityId,
    required String memberUserId,
  }) {
    return _api.removeMember(
      communityId: communityId,
      memberUserId: memberUserId,
    );
  }

  @override
  Future<void> updateCommunity({
    required String communityId,
    required String name,
    required String description,
    String? imageUrl,
  }) {
    return _api.updateCommunity(
      communityId: communityId,
      name: name,
      description: description,
      imageUrl: imageUrl,
    );
  }

  @override
  Future<void> transferCreatorRole({
    required String communityId,
    required String newCreatorUserId,
  }) {
    return _api.transferCreatorRole(
      communityId: communityId,
      newCreatorUserId: newCreatorUserId,
    );
  }
}
