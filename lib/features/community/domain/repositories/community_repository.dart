import '../entities/community.dart';
import '../entities/community_member.dart';

abstract class CommunityRepository {
  Future<List<Community>> getMyCommunities();
  Future<Community> createCommunity({
    required String name,
    required String description,
    String? imageUrl,
  });
  Future<void> updateCommunity({
    required String communityId,
    required String name,
    required String description,
    String? imageUrl,
  });
  Future<void> regenerateInvitationCode(String communityId);
  Future<void> deleteCommunity(String communityId);
  Future<void> joinCommunityByCode(String code);
  Future<void> joinCommunityByLink(String link);
  Future<void> leaveCommunity(String communityId);
  Future<List<CommunityMember>> getCommunityMembers(String communityId);
  Future<void> removeMember({
    required String communityId,
    required String memberUserId,
  });
  Future<void> transferCreatorRole({
    required String communityId,
    required String newCreatorUserId,
  });
}
