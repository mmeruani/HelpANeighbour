import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/constants.dart';
import '../../../core/config/service_categories.dart';

class AuthApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthApi(this._auth, this._db);

  List<String> _phoneCandidates(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    final values = <String>{trimmed};
    if (digits.length == 11 && digits.startsWith('8')) {
      values.add('+7${digits.substring(1)}');
      values.add('7${digits.substring(1)}');
      values.add('8${digits.substring(1)}');
    } else if (digits.length == 11 && digits.startsWith('7')) {
      values.add('+$digits');
      values.add(digits);
      values.add('8${digits.substring(1)}');
    } else if (digits.length == 10) {
      values.add('+7$digits');
      values.add('7$digits');
      values.add('8$digits');
    }
    return values.where((value) => value.trim().isNotEmpty).toList();
  }

  String _canonicalPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 11 && digits.startsWith('7')) {
      return '+$digits';
    }
    if (digits.length == 10) {
      return '+7$digits';
    }
    return phone.trim();
  }

  String _phoneLookupId(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  Future<String?> _emailByPhone(String phone) async {
    for (final candidate in _phoneCandidates(phone)) {
      final id = _phoneLookupId(candidate);
      if (id.isEmpty) {
        continue;
      }
      try {
        final snapshot = await _db
            .collection(AppCollections.phoneAuthIndex)
            .doc(id)
            .get();
        final email = snapshot.data()?['email'] as String?;
        if (email != null && email.trim().isNotEmpty) {
          return email.trim();
        }
      } on FirebaseException {
        continue;
      }
    }
    return null;
  }

  Future<void> _writePhoneLookup({
    required String uid,
    required String email,
    required String phone,
  }) async {
    final batch = _db.batch();
    for (final candidate in _phoneCandidates(phone)) {
      final id = _phoneLookupId(candidate);
      if (id.isEmpty) {
        continue;
      }
      batch.set(
        _db.collection(AppCollections.phoneAuthIndex).doc(id),
        {
          'userId': uid,
          'email': email.trim(),
          'phone': _canonicalPhone(phone),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> ensurePhoneIsUnique(String phone) async {
    final email = await _emailByPhone(phone);
    if (email != null) {
      throw AuthException.accountAlreadyExists();
    }
  }

  Future<void> ensureEmailIsUnique(String email) async {}

  Never _mapFirebaseAuthException(FirebaseAuthException e) {
    if (e.code == 'email-already-in-use') {
      throw AuthException.accountAlreadyExists();
    }

    final details = '${e.code} ${e.message ?? ''}'.toLowerCase();
    if (details.contains('configuration_not_found')) {
      throw AuthException.androidFirebaseConfigurationMissing();
    }

    throw AuthException.generic();
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    await ensurePhoneIsUnique(phone);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;
      final normalizedPhone = _canonicalPhone(phone);
      final normalizedName = name.trim();
      await cred.user!.updateDisplayName(normalizedName);
      await _db.collection('users').doc(uid).set({
        'email': email,
        'phone': normalizedPhone,
        'phoneVariants': _phoneCandidates(normalizedPhone),
        'name': normalizedName,
        'avatarUrl': null,
        'bio': '',
        'rating': 0.0,
        'completedServicesCount': 0,
        'reviewsCount': 0,
        'communityIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      try {
        await _db.collection('public_users').doc(uid).set({
          'name': normalizedName,
          'avatarUrl': null,
          'bio': '',
          'rating': 0.0,
          'completedServicesCount': 0,
          'reviewsCount': 0,
          'communityIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      await _db
          .collection('users')
          .doc(uid)
          .collection('notification_settings')
          .doc('default')
          .set({
            'newRequestsInCommunities': true,
            'responsesToMyRequests': true,
            'selectedAsExecutor': true,
            'newReviews': true,
            'subscribedCategoryIds': ServiceCategories.titles,
          });

      await _writePhoneLookup(uid: uid, email: email, phone: normalizedPhone);

      return cred;
    } on FirebaseAuthException catch (e) {
      _mapFirebaseAuthException(e);
    }
  }

  Future<UserCredential> login({
    required String loginOrPhone,
    required String password,
  }) async {
    final v = loginOrPhone.trim();

    if (v.contains('@')) {
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: v,
          password: password,
        );
        await _backfillPhoneLookupForCurrentUser(credential.user);
        return credential;
      } on FirebaseAuthException catch (e) {
        final details = '${e.code} ${e.message ?? ''}'.toLowerCase();
        if (details.contains('configuration_not_found')) {
          throw AuthException.androidFirebaseConfigurationMissing();
        }
        throw AuthException.invalidCredentials();
      }
    }

    final email = await _emailByPhone(v);
    if (email == null || email.isEmpty) {
      throw const AuthException._(
        'Аккаунт с таким номером телефона не найден. Проверьте формат номера или войдите по электронной почте.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _backfillPhoneLookupForCurrentUser(credential.user);
      return credential;
    } on FirebaseAuthException catch (e) {
      final details = '${e.code} ${e.message ?? ''}'.toLowerCase();
      if (details.contains('configuration_not_found')) {
        throw AuthException.androidFirebaseConfigurationMissing();
      }
      throw AuthException.incorrectPassword();
    }
  }

  Future<void> logout() => _auth.signOut();

  Stream<User?> authState() => _auth.authStateChanges();

  Future<void> _backfillPhoneLookupForCurrentUser(User? user) async {
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      return;
    }
    try {
      final userDoc = await _db
          .collection(AppCollections.users)
          .doc(user.uid)
          .get();
      final phone = userDoc.data()?['phone'] as String?;
      if (phone == null || phone.trim().isEmpty) {
        return;
      }
      await _writePhoneLookup(uid: user.uid, email: user.email!, phone: phone);
    } catch (_) {}
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException._(this.message);

  factory AuthException.accountAlreadyExists() => const AuthException._(
    'Такой аккаунт уже существует. Выполните вход или восстановление доступа.',
  );

  factory AuthException.invalidCredentials() =>
      const AuthException._('Ошибка авторизации. Проверьте введённые данные.');

  factory AuthException.incorrectPassword() =>
      const AuthException._('Некорректный пароль, попробуйте снова.');

  factory AuthException.androidFirebaseConfigurationMissing() =>
      const AuthException._(
        'Регистрация на Android сейчас недоступна: Firebase настроен не полностью. Нужно добавить SHA-ключи приложения в Firebase Console и скачать обновлённый google-services.json.',
      );

  factory AuthException.generic() => const AuthException._(
    'Не удалось выполнить операцию. Попробуйте ещё раз.',
  );

  @override
  String toString() => message;
}
