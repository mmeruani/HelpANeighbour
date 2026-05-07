import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  const RegisterUseCase(this._repository);

  Future<void> call({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _repository.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );
  }
}
