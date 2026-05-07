import '../domain/entities/notification_settings.dart';
import '../domain/entities/profile.dart';
import '../domain/repositories/profile_repository.dart';
import 'profile_api.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileApi _api;

  const ProfileRepositoryImpl(this._api);

  @override
  Future<Profile> getCurrentProfile() => _api.getCurrentProfile();

  @override
  Future<List<String>> getActivityHistory() => _api.getActivityHistory();

  @override
  Future<void> updateNotificationSettings(NotificationSettings settings) {
    return _api.updateNotificationSettings(settings);
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String bio,
    String? avatarUrl,
  }) {
    return _api.updateProfile(name: name, bio: bio, avatarUrl: avatarUrl);
  }
}
