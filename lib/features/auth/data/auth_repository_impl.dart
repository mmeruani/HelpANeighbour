import 'package:firebase_auth/firebase_auth.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi _api;
  AuthRepositoryImpl(this._api);

  @override
  Stream<AppUser?> authState() => _api.authState().map((u) {
    if (u == null) return null;
    // можно доработать позже
    return AppUser(uid: u.uid, email: u.email ?? '', phone: '');
  });

  @override
  Future<void> register({required String email, required String password, required String phone}) async {
    await _api.register(email: email, password: password, phone: phone);
  }

  @override
  Future<void> login({required String loginOrPhone, required String password}) async {
    await _api.login(loginOrPhone: loginOrPhone, password: password);
  }

  @override
  Future<void> logout() => _api.logout();
}
