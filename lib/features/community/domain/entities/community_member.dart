import '../../../profile/domain/entities/profile.dart';
import 'community_role.dart';

class CommunityMember {
  final String communityId;
  final String userId;
  final CommunityRole role;
  final DateTime joinedAt;
  final Profile profile;

  const CommunityMember({
    required this.communityId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.profile,
  });
}
