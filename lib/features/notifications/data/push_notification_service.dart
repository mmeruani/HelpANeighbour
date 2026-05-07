import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/config/constants.dart';

class PushNotificationService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  bool _initialized = false;

  PushNotificationService(this._auth, this._db, this._messaging);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _messaging.setAutoInitEnabled(true);
    await requestPermissions();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        return;
      }
      await syncCurrentToken();
    });

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      await _storeRemoteMessage(message);
    });

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) async {
      await _storeRemoteMessage(message);
      _openRouteFromMessage(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _storeRemoteMessage(initialMessage);
      _openRouteFromMessage(initialMessage);
    }

    if (_auth.currentUser != null) {
      await syncCurrentToken();
    }
  }

  Future<void> requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> syncCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null) {
      return;
    }
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    await _db
        .collection(AppCollections.users)
        .doc(user.uid)
        .collection(AppCollections.deviceTokens)
        .doc(token)
        .set({
          'token': token,
          'platform': Platform.isIOS
              ? 'ios'
              : Platform.isAndroid
              ? 'android'
              : 'unknown',
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _storeRemoteMessage(RemoteMessage message) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Уведомление';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final targetRoute = message.data['targetRoute'] as String? ?? '';
    final docId = message.messageId;

    final collection = _db.collection(AppCollections.notifications);
    if (docId == null || docId.isEmpty) {
      await collection.add({
        'recipientUserId': user.uid,
        'title': title,
        'body': body,
        'targetRoute': targetRoute,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await collection.doc(docId).set({
      'recipientUserId': user.uid,
      'title': title,
      'body': body,
      'targetRoute': targetRoute,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _openRouteFromMessage(RemoteMessage message) {
    final targetRoute = message.data['targetRoute'] as String?;
    if (targetRoute == null || targetRoute.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        try {
          GoRouter.of(context).push(targetRoute);
        } catch (_) {}
      }
    });
  }

  void dispose() {
    _authSubscription?.cancel();
    _tokenSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
  }
}
