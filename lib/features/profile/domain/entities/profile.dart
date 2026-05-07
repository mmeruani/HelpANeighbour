import 'notification_settings.dart';

class Profile {
  final String userId;
  final String email;
  final String phone;
  final String name;
  final String? avatarUrl;
  final String bio;
  final double rating;
  final int completedServicesCount;
  final int reviewsCount;
  final List<String> communityIds;
  final NotificationSettings notificationSettings;

  const Profile({
    required this.userId,
    required this.email,
    required this.phone,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.rating,
    required this.completedServicesCount,
    required this.reviewsCount,
    required this.communityIds,
    required this.notificationSettings,
  });
}
