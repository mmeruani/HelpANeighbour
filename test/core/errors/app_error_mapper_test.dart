import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:help_a_neighbour/core/errors/app_error_mapper.dart';
import 'package:help_a_neighbour/features/auth/data/auth_api.dart';

void main() {
  group('mapAppError', () {
    test('maps incorrect password auth exception to user-friendly text', () {
      expect(
        mapAppError(AuthException.incorrectPassword()),
        'Некорректный пароль, попробуйте снова.',
      );
    });

    test('maps Firebase wrong-password to authorization text', () {
      expect(
        mapAppError(FirebaseAuthException(code: 'wrong-password')),
        'Ошибка авторизации. Проверьте введённые данные.',
      );
    });

    test('maps Firestore permission-denied to permission message', () {
      expect(
        mapAppError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        'Недостаточно прав для выполнения этого действия.',
      );
    });

    test('maps network and timeout failures', () {
      expect(
        mapAppError(const SocketException('offline')),
        'Нет подключения к интернету. Проверьте сеть и попробуйте ещё раз.',
      );
      expect(
        mapAppError(TimeoutException('slow')),
        'Сервис отвечает слишком долго. Попробуйте ещё раз.',
      );
    });
  });
}
