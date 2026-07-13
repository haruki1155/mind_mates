import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../database/firestore_collections.dart';
import 'firestore_service.dart';

class AppNotificationService {
  AppNotificationService({this.messaging, FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  FirebaseMessaging? messaging;
  final FirestoreService _firestoreService;
  StreamSubscription<String>? _tokenSubscription;

  FirebaseMessaging get _instance => messaging ??= FirebaseMessaging.instance;

  Future<void> initializeForUser(String userId) async {
    final settings = await _instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final vapidKey = const String.fromEnvironment('FCM_VAPID_KEY');
    final token = await _instance.getToken(
      vapidKey: vapidKey.isEmpty ? null : vapidKey,
    );
    if (token != null && token.isNotEmpty) await _saveToken(userId, token);

    await _tokenSubscription?.cancel();
    _tokenSubscription = _instance.onTokenRefresh.listen(
      (token) => _saveToken(userId, token),
    );
  }

  Future<void> _saveToken(String userId, String token) {
    return _firestoreService.setDocument(
      '${FirestoreCollections.userDevices}/$userId/tokens',
      token,
      {'token': token, 'updatedAt': DateTime.now()},
      merge: true,
    );
  }

  Future<void> dispose() => _tokenSubscription?.cancel() ?? Future.value();
}
