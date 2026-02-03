import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthApi {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthApi(this._auth, this._db);

  Future<void> ensurePhoneIsUnique(String phone) async {
    final q = await _db.collection('users').where('phone', isEqualTo: phone).limit(1).get();
    if (q.docs.isNotEmpty) {
      throw AuthException.accountAlreadyExists();
    }
  }

  Future<void> ensureEmailIsUnique(String email) async {
    // FirebaseAuth сам упадет на createUserWithEmailAndPassword
  }

  Future<UserCredential> register({
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
      await _db.collection('users').doc(uid).set({
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw AuthException.accountAlreadyExists();
      }
      rethrow;
    }
  }

  Future<UserCredential> login({
    required String loginOrPhone,
    required String password,
  }) async {
    final v = loginOrPhone.trim();

    if (v.contains('@')) {
      // login by email
      try {
        return await _auth.signInWithEmailAndPassword(email: v, password: password);
      } on FirebaseAuthException {
        throw AuthException.invalidCredentials(); // без раскрытия деталей
      }
    }

    // login by phone: find email by phone
    final q = await _db.collection('users').where('phone', isEqualTo: v).limit(1).get();
    if (q.docs.isEmpty) {
      throw AuthException.invalidCredentials();
    }
    final email = (q.docs.first.data())['email'] as String;

    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException {
      throw AuthException.invalidCredentials();
    }
  }

  Future<void> logout() => _auth.signOut();

  Stream<User?> authState() => _auth.authStateChanges();
}

class AuthException implements Exception {
  final String message;
  const AuthException._(this.message);

  factory AuthException.accountAlreadyExists() => const AuthException._('Такой аккаунт уже существует. Выполните вход или восстановление доступа.');

  factory AuthException.invalidCredentials() => const AuthException._('Ошибка авторизации. Проверьте введённые данные.');
}
