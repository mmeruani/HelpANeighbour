import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:help_a_neighbour/features/auth/data/auth_api.dart';
import 'package:help_a_neighbour/features/auth/domain/entities/user.dart';
import 'package:help_a_neighbour/features/auth/domain/repositories/auth_repository.dart';
import 'package:help_a_neighbour/features/auth/presentation/controllers/auth_controller.dart';
import 'package:help_a_neighbour/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('LoginPage shows incorrect password text from AuthController', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(loginError: AuthException.incorrectPassword()),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '89161234567');
    await tester.enterText(find.byType(TextFormField).at(1), 'Wrong1!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Некорректный пароль, попробуйте снова.'), findsOneWidget);
  });

  testWidgets('LoginPage validates empty login and password fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(
      find.text('Введите номер телефона или адрес электронной почты'),
      findsOneWidget,
    );
    expect(find.text('Введите пароль'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  final Object? loginError;

  _FakeAuthRepository({this.loginError});

  @override
  Stream<AppUser?> authState() => const Stream.empty();

  @override
  Future<void> login({
    required String loginOrPhone,
    required String password,
  }) async {
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
  }) async {}

  @override
  Future<void> logout() async {}
}
