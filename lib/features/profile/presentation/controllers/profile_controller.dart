import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/profile_api.dart';
import '../../data/profile_repository_impl.dart';
import '../../domain/entities/notification_settings.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileState {
  final bool loading;
  final String? error;
  final Profile? profile;
  final List<String> activityHistory;

  const ProfileState({
    this.loading = true,
    this.error,
    this.profile,
    this.activityHistory = const [],
  });

  static const _errorSentinel = Object();

  ProfileState copyWith({
    bool? loading,
    Object? error = _errorSentinel,
    Profile? profile,
    List<String>? activityHistory,
  }) {
    return ProfileState(
      loading: loading ?? this.loading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      profile: profile ?? this.profile,
      activityHistory: activityHistory ?? this.activityHistory,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  final FirebaseAuth _auth;

  ProfileController(this._repository, this._auth)
    : super(const ProfileState()) {
    load();
  }

  Future<User?> _waitForUser() async {
    final current = _auth.currentUser;
    if (current != null) {
      return current;
    }
    try {
      return await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final user = await _waitForUser();
    if (user == null) {
      state = state.copyWith(
        loading: false,
        error: 'Не удалось подтвердить вход. Повторите попытку.',
      );
      return;
    }
    try {
      final profile = await _repository.getCurrentProfile();
      state = state.copyWith(
        loading: false,
        profile: profile,
        activityHistory: const [],
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String bio,
    String? avatarUrl,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.updateProfile(
        name: name,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.updateNotificationSettings(settings);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }
}

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileApiProvider));
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      return ProfileController(
        ref.watch(profileRepositoryProvider),
        ref.watch(firebaseAuthProvider),
      );
    });
