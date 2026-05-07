import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String mapAppError(Object error) {
  if (error is FirebaseAuthException) {
    return _mapFirebaseAuthError(error);
  }

  if (error is FirebaseException) {
    return _mapFirebaseError(error);
  }

  if (error is SocketException) {
    return 'Нет подключения к интернету. Проверьте сеть и попробуйте ещё раз.';
  }

  if (error is TimeoutException) {
    return 'Сервис отвечает слишком долго. Попробуйте ещё раз.';
  }

  if (error is FormatException) {
    return 'Получены некорректные данные. Попробуйте ещё раз.';
  }

  if (error is PlatformException) {
    return _mapPlatformError(error);
  }

  if (error is StateError) {
    return _mapStateError(error);
  }

  final text = error.toString().trim();
  final lower = text.toLowerCase();

  if (lower.contains('permission-denied')) {
    return 'Недостаточно прав для выполнения этого действия.';
  }
  if (lower.contains('network-request-failed') ||
      lower.contains('failed host lookup') ||
      lower.contains('socketexception')) {
    return 'Нет подключения к интернету. Проверьте сеть и попробуйте ещё раз.';
  }
  if (lower.contains('configuration_not_found')) {
    return 'Конфигурация приложения Firebase настроена не полностью. Проверьте настройки проекта.';
  }
  if (lower.contains('already exists')) {
    return 'Такой объект уже существует.';
  }
  if (lower.contains('cloudinary')) {
    return 'Не удалось загрузить изображение. Проверьте настройки хранилища и попробуйте ещё раз.';
  }
  if (lower.contains(
        'upload preset must be whitelisted for unsigned uploads',
      ) ||
      lower.contains('unsigned uploads')) {
    return 'Загрузка изображения пока недоступна: в Cloudinary не настроен unsigned upload preset. Проверьте настройки пресета.';
  }
  if (lower.contains('developer_error') ||
      lower.contains('com.google.android.gms')) {
    return 'Службы Google Play на устройстве работают некорректно. Перезапустите приложение и попробуйте ещё раз.';
  }

  if (_looksLikeTechnicalError(text)) {
    return 'Произошла ошибка. Попробуйте ещё раз.';
  }

  return text.isEmpty
      ? 'Произошла неизвестная ошибка. Попробуйте ещё раз.'
      : text;
}

String _mapFirebaseAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-login-credentials':
      return 'Ошибка авторизации. Проверьте введённые данные.';
    case 'email-already-in-use':
    case 'account-exists-with-different-credential':
      return 'Такой аккаунт уже существует.';
    case 'weak-password':
      return 'Слишком простой пароль. Измените его и попробуйте ещё раз.';
    case 'network-request-failed':
      return 'Нет подключения к интернету. Проверьте сеть и попробуйте ещё раз.';
    case 'too-many-requests':
      return 'Слишком много попыток. Подождите немного и попробуйте ещё раз.';
    case 'operation-not-allowed':
      return 'Этот способ входа сейчас недоступен. Проверьте настройки Firebase Authentication.';
    case 'user-disabled':
      return 'Учётная запись отключена.';
    default:
      final details = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (details.contains('configuration_not_found')) {
        return 'Конфигурация Firebase Authentication настроена не полностью.';
      }
      return error.message?.trim().isNotEmpty == true
          ? (_looksLikeTechnicalError(error.message!.trim())
                ? 'Не удалось выполнить авторизацию. Попробуйте ещё раз.'
                : error.message!.trim())
          : 'Не удалось выполнить авторизацию. Попробуйте ещё раз.';
  }
}

String _mapFirebaseError(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Недостаточно прав для выполнения этого действия.';
    case 'unavailable':
      return 'Сервис временно недоступен. Попробуйте ещё раз позже.';
    case 'not-found':
      return 'Нужные данные не найдены.';
    case 'already-exists':
      return 'Такой объект уже существует.';
    case 'failed-precondition':
      return 'Действие нельзя выполнить в текущем состоянии данных.';
    case 'cancelled':
      return 'Операция была отменена.';
    case 'resource-exhausted':
      return 'Сервис временно перегружен. Попробуйте позже.';
    default:
      final details = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (details.contains('permission-denied')) {
        return 'Недостаточно прав для выполнения этого действия.';
      }
      return error.message?.trim().isNotEmpty == true
          ? (_looksLikeTechnicalError(error.message!.trim())
                ? 'Не удалось выполнить операцию. Попробуйте ещё раз.'
                : error.message!.trim())
          : 'Не удалось выполнить операцию. Попробуйте ещё раз.';
  }
}

String _mapStateError(StateError error) {
  final message = error.message.toString().trim();
  if (message.isEmpty) {
    return 'Не удалось выполнить операцию. Попробуйте ещё раз.';
  }
  if (message.toLowerCase().contains('cloudinary')) {
    return 'Не удалось загрузить изображение. Проверьте настройки хранилища и попробуйте ещё раз.';
  }
  if (message.toLowerCase().contains(
        'upload preset must be whitelisted for unsigned uploads',
      ) ||
      message.toLowerCase().contains('unsigned uploads')) {
    return 'Загрузка изображения пока недоступна: в Cloudinary не настроен unsigned upload preset. Проверьте настройки пресета.';
  }
  if (_looksLikeTechnicalError(message)) {
    return 'Не удалось выполнить операцию. Попробуйте ещё раз.';
  }
  return message;
}

String _mapPlatformError(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();
  final text = '$code $message';

  if (text.contains('photo_access_denied') ||
      text.contains('camera_access_denied') ||
      text.contains('access_denied') ||
      text.contains('permission')) {
    return 'Доступ к фотографиям запрещён. Разрешите доступ в настройках устройства.';
  }

  if (text.contains('no_available_camera')) {
    return 'Камера на устройстве недоступна.';
  }

  return 'Не удалось выбрать изображение. Попробуйте ещё раз.';
}

bool _looksLikeTechnicalError(String text) {
  final lower = text.toLowerCase();
  return lower.contains('firebase_auth') ||
      lower.contains('firebaseexception') ||
      lower.contains('platformexception') ||
      lower.contains('socketexception') ||
      lower.contains('configuration_not_found') ||
      lower.contains('cloudinary') ||
      lower.contains('unsigned uploads') ||
      lower.contains('developer_error') ||
      lower.contains('com.google.android.gms') ||
      lower.contains('stack trace') ||
      lower.contains('exception:') ||
      lower.contains('[unknown]') ||
      lower.contains('permission_denied') ||
      (lower.contains('code=') && lower.contains('message=')) ||
      (kDebugMode && lower.startsWith('instance of '));
}
