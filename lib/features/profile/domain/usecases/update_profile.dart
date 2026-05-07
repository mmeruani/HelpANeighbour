import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  final ProfileRepository _repository;

  const UpdateProfileUseCase(this._repository);

  Future<void> call({
    required String name,
    required String bio,
    String? avatarUrl,
  }) {
    return _repository.updateProfile(
      name: name,
      bio: bio,
      avatarUrl: avatarUrl,
    );
  }
}
