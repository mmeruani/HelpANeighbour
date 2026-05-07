import '../entities/notification_settings.dart';
import '../repositories/profile_repository.dart';

class UpdateNotificationSettingsUseCase {
  final ProfileRepository _repository;

  const UpdateNotificationSettingsUseCase(this._repository);

  Future<void> call(NotificationSettings settings) {
    return _repository.updateNotificationSettings(settings);
  }
}
