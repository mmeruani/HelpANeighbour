import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/features/auth/data/auth_api.dart';
import 'package:help_a_neighbour/features/auth/domain/entities/user.dart';
import 'package:help_a_neighbour/features/auth/domain/repositories/auth_repository.dart';
import 'package:help_a_neighbour/features/auth/presentation/controllers/auth_controller.dart';

void main() {
  group('AuthController', () {
    test(
      'sets incorrect password message when repository reports it',
      () async {
        final repository = _FakeAuthRepository(
          loginError: AuthException.incorrectPassword(),
        );
        final controller = AuthController(repository);

        final success = await controller.login('89161234567', 'bad-password');

        expect(success, isFalse);
        expect(controller.state.loading, isFalse);
        expect(
          controller.state.error,
          'Некорректный пароль, попробуйте снова.',
        );
      },
    );

    test('clears error after a successful login', () async {
      final repository = _FakeAuthRepository();
      final controller = AuthController(repository);

      final success = await controller.login('user@example.com', 'Strong1!');

      expect(success, isTrue);
      expect(controller.state.loading, isFalse);
      expect(controller.state.error, isNull);
      expect(repository.lastLogin, 'user@example.com');
      expect(repository.lastPassword, 'Strong1!');
    });

    test('maps duplicate registration to existing account message', () async {
      final repository = _FakeAuthRepository(
        registerError: AuthException.accountAlreadyExists(),
      );
      final controller = AuthController(repository);

      final success = await controller.register(
        'Мария',
        'maria@example.com',
        '+79991234567',
        'Strong1!',
      );

      expect(success, isFalse);
      expect(
        controller.state.error,
        'Такой аккаунт уже существует. Выполните вход или восстановление доступа.',
      );
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  final Object? loginError;
  final Object? registerError;
  String? lastLogin;
  String? lastPassword;

  _FakeAuthRepository({this.loginError, this.registerError});

  @override
  Stream<AppUser?> authState() => const Stream.empty();

  @override
  Future<void> login({
    required String loginOrPhone,
    required String password,
  }) async {
    lastLogin = loginOrPhone;
    lastPassword = password;
    final error = loginError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final error = registerError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> logout() async {}
}
