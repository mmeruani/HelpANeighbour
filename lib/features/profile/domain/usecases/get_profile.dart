import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository _repository;

  const GetProfileUseCase(this._repository);

  Future<Profile> call() {
    return _repository.getCurrentProfile();
  }
}
