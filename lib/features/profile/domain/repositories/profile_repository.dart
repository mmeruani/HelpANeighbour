import '../entities/notification_settings.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<Profile> getCurrentProfile();
  Future<void> updateProfile({
    required String name,
    required String bio,
    String? avatarUrl,
  });
  Future<void> updateNotificationSettings(NotificationSettings settings);
  Future<List<String>> getActivityHistory();
}
