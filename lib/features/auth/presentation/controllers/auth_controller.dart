import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../data/auth_api.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthState {
  final bool loading;
  final String? error;

  const AuthState({this.loading = false, this.error});
  static const _errorSentinel = Object();

  AuthState copyWith({bool? loading, Object? error = _errorSentinel}) {
    return AuthState(
      loading: loading ?? this.loading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AuthState());

  Future<bool> login(String loginOrPhone, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.login(loginOrPhone: loginOrPhone, password: password);
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<bool> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: mapAppError(e));
      return false;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserIdProvider = Provider<String?>((ref) {
  final authUser = ref.watch(authUserProvider);
  return authUser.valueOrNull?.uid;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authApiProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider));
  },
);
