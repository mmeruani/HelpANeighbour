import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/community_api.dart';
import '../../data/community_repository_impl.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/community_member.dart';
import '../../domain/repositories/community_repository.dart';

typedef AuthReadyChecker = Future<bool> Function();

class CommunityState {
  final bool loading;
  final String? error;
  final Map<String, String> memberErrorsByCommunity;
  final List<Community> communities;
  final Map<String, List<CommunityMember>> membersByCommunity;

  const CommunityState({
    this.loading = true,
    this.error,
    this.memberErrorsByCommunity = const {},
    this.communities = const [],
    this.membersByCommunity = const {},
  });

  static const _errorSentinel = Object();

  CommunityState copyWith({
    bool? loading,
    Object? error = _errorSentinel,
    Map<String, String>? memberErrorsByCommunity,
    List<Community>? communities,
    Map<String, List<CommunityMember>>? membersByCommunity,
  }) {
    return CommunityState(
      loading: loading ?? this.loading,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      memberErrorsByCommunity:
          memberErrorsByCommunity ?? this.memberErrorsByCommunity,
      communities: communities ?? this.communities,
      membersByCommunity: membersByCommunity ?? this.membersByCommunity,
    );
  }
}

class CommunityController extends StateNotifier<CommunityState> {
  final CommunityRepository _repository;
  final AuthReadyChecker _authReady;

  CommunityController(this._repository, this._authReady)
    : super(const CommunityState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    final authReady = await _authReady();
    if (!authReady) {
      state = state.copyWith(loading: false, error: null);
      return;
    }
    try {
      final communities = await _repository.getMyCommunities();
      state = state.copyWith(loading: false, communities: communities);
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
    }
  }

  Future<bool> createCommunity({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.createCommunity(
        name: name,
        description: description,
        imageUrl: imageUrl,
      );
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> joinCommunityByCode(String code) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.joinCommunityByCode(code);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> joinCommunityByLink(String link) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.joinCommunityByLink(link);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> leaveCommunity(String communityId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.leaveCommunity(communityId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> updateCommunity({
    required String communityId,
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.updateCommunity(
        communityId: communityId,
        name: name,
        description: description,
        imageUrl: imageUrl,
      );
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> deleteCommunity(String communityId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.deleteCommunity(communityId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> regenerateInvitationCode(String communityId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.regenerateInvitationCode(communityId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<void> loadMembers(String communityId) async {
    try {
      final members = await _repository.getCommunityMembers(communityId);
      final updatedMembers = Map<String, List<CommunityMember>>.from(
        state.membersByCommunity,
      );
      final updatedErrors = Map<String, String>.from(
        state.memberErrorsByCommunity,
      )..remove(communityId);
      updatedMembers[communityId] = members;
      state = state.copyWith(
        membersByCommunity: updatedMembers,
        memberErrorsByCommunity: updatedErrors,
      );
    } catch (e) {
      final updatedErrors = Map<String, String>.from(
        state.memberErrorsByCommunity,
      );
      updatedErrors[communityId] = mapAppError(e);
      state = state.copyWith(memberErrorsByCommunity: updatedErrors);
    }
  }

  Future<bool> removeMember({
    required String communityId,
    required String memberUserId,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.removeMember(
        communityId: communityId,
        memberUserId: memberUserId,
      );
      await loadMembers(communityId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }

  Future<bool> transferCreatorRole({
    required String communityId,
    required String newCreatorUserId,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repository.transferCreatorRole(
        communityId: communityId,
        newCreatorUserId: newCreatorUserId,
      );
      await loadMembers(communityId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: mapAppError(e));
      return false;
    }
  }
}

final communityApiProvider = Provider<CommunityApi>((ref) {
  return CommunityApi(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
  );
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepositoryImpl(ref.watch(communityApiProvider));
});

final communityAuthReadyProvider = Provider<AuthReadyChecker>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return () async {
    final current = auth.currentUser;
    if (current != null) {
      return true;
    }
    try {
      final user = await auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 8));
      return user != null;
    } catch (_) {
      return false;
    }
  };
});

final communityControllerProvider =
    StateNotifierProvider<CommunityController, CommunityState>((ref) {
      return CommunityController(
        ref.watch(communityRepositoryProvider),
        ref.watch(communityAuthReadyProvider),
      );
    });
