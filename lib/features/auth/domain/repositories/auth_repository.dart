import '../entities/user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authState();
  Future<void> register({required String email, required String password, required String phone});
  Future<void> login({required String loginOrPhone, required String password});
  Future<void> logout();
}
