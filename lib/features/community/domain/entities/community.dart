import 'community_role.dart';

class Community {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String invitationCode;
  final String invitationLink;
  final String creatorId;
  final int membersCount;
  final CommunityRole currentUserRole;
  final DateTime createdAt;

  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.invitationCode,
    required this.invitationLink,
    required this.creatorId,
    required this.membersCount,
    required this.currentUserRole,
    required this.createdAt,
  });
}
