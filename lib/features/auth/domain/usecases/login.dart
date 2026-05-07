import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<void> call({
    required String loginOrPhone,
    required String password,
  }) {
    return _repository.login(
      loginOrPhone: loginOrPhone,
      password: password,
    );
  }
}
