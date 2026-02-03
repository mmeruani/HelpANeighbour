import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthState {
  final bool loading;
  final String? error;

  const AuthState({this.loading = false, this.error});
  AuthState copyWith({bool? loading, String? error}) =>
      AuthState(loading: loading ?? this.loading, error: error);
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AuthState());

  Future<void> login(String loginOrPhone, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.login(loginOrPhone: loginOrPhone, password: password);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> register(String email, String phone, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.register(email: email, phone: phone, password: password);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
  }
}
