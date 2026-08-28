import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../../database/firestore_collections.dart';
import '../../features/mind_aid/domain/mind_aid_integration_models.dart';
import 'firebase_operation.dart';
import 'firebase_callable_router.dart';

abstract interface class MindAidCloudGateway {
  Future<MindAidPreferences> loadPreferences(String userId);

  Future<MindAidPreferences> saveConsent({
    required String userId,
    required bool cloudConsent,
    required bool personalizationEnabled,
    String? existingConversationId,
  });

  Future<bool> isCloudEnabled();

  Future<MindAidCloudResponse> send({
    required String requestId,
    required String conversationId,
    required String text,
    required String launchContext,
  });

  Future<void> clearHistory(String userId);

  Future<String> startNewConversation(String userId);

  Future<void> submitFeedback({
    required String userId,
    required String messageId,
    required bool helpful,
  });
}

class MindAidCloudService implements MindAidCloudGateway {
  MindAidCloudService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseRemoteConfig? remoteConfig,
    FirebaseOperationRunner? operationRunner,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
       _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
       _operationRunner = operationRunner ?? FirebaseOperationRunner();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseRemoteConfig _remoteConfig;
  final FirebaseOperationRunner _operationRunner;
  bool _remoteConfigReady = false;

  @override
  Future<MindAidPreferences> loadPreferences(String userId) async {
    final snapshot = await _operationRunner.run(
      area: 'Loading MindAid preferences',
      operation: () => _firestore
          .collection(FirestoreCollections.mindAidPreferences)
          .doc(userId)
          .get(),
    );
    return MindAidPreferences.fromMap(snapshot.data());
  }

  @override
  Future<MindAidPreferences> saveConsent({
    required String userId,
    required bool cloudConsent,
    required bool personalizationEnabled,
    String? existingConversationId,
  }) async {
    final conversationId = existingConversationId?.trim().isNotEmpty == true
        ? existingConversationId!.trim()
        : createConversationId();
    await _operationRunner.run(
      area: 'Saving MindAid consent',
      operation: () => _firestore
          .collection(FirestoreCollections.mindAidPreferences)
          .doc(userId)
          .set({
            'userId': userId,
            'hasDecision': true,
            'cloudConsent': cloudConsent,
            'personalizationEnabled': cloudConsent && personalizationEnabled,
            'consentVersion': MindAidPreferences.currentConsentVersion,
            if (cloudConsent) 'grantedAt': FieldValue.serverTimestamp(),
            if (!cloudConsent) 'revokedAt': FieldValue.serverTimestamp(),
            'conversationId': conversationId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
    );
    return MindAidPreferences(
      hasDecision: true,
      cloudConsent: cloudConsent,
      personalizationEnabled: cloudConsent && personalizationEnabled,
      conversationId: conversationId,
      consentVersion: MindAidPreferences.currentConsentVersion,
    );
  }

  @override
  Future<bool> isCloudEnabled() async {
    const force = bool.fromEnvironment('MINDAID_DIALOGFLOW_FORCE');
    if (force) return true;
    try {
      if (!_remoteConfigReady) {
        await _remoteConfig.setDefaults({'mind_aid_dialogflow_enabled': false});
        await _remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 5),
            minimumFetchInterval: const Duration(hours: 1),
          ),
        );
        await _remoteConfig.fetchAndActivate();
        _remoteConfigReady = true;
      }
      return _remoteConfig.getBool('mind_aid_dialogflow_enabled');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<MindAidCloudResponse> send({
    required String requestId,
    required String conversationId,
    required String text,
    required String launchContext,
  }) async {
    final result = await _operationRunner.run(
      area: 'Sending MindAid callable message',
      operation: () =>
          FirebaseCallableRouter.callable(
            _functions,
            'sendMindAidMessage',
          ).call({
            'requestId': requestId,
            'conversationId': conversationId,
            'text': text,
            'locale': 'en',
            'launchContext': launchContext,
          }),
    );
    final data = result.data;
    if (data is! Map) throw const FormatException('Invalid MindAid response.');
    return MindAidCloudResponse.fromMap(data);
  }

  @override
  Future<void> clearHistory(String userId) async {
    await _operationRunner.run<void>(
      area: 'Clearing MindAid history',
      operation: () async {
        while (true) {
          final snapshot = await _firestore
              .collection(FirestoreCollections.mindAidMessages)
              .where('userId', isEqualTo: userId)
              .limit(400)
              .get();
          if (snapshot.docs.isEmpty) break;
          final batch = _firestore.batch();
          for (final document in snapshot.docs) {
            batch.delete(document.reference);
          }
          await batch.commit();
        }
      },
    );
    await startNewConversation(userId);
  }

  @override
  Future<String> startNewConversation(String userId) async {
    final nextId = createConversationId();
    await _operationRunner.run(
      area: 'Starting new MindAid conversation',
      operation: () => _firestore
          .collection(FirestoreCollections.mindAidPreferences)
          .doc(userId)
          .set({
            'conversationId': nextId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
    );
    return nextId;
  }

  @override
  Future<void> submitFeedback({
    required String userId,
    required String messageId,
    required bool helpful,
  }) {
    return _operationRunner.run(
      area: 'Saving MindAid feedback',
      operation: () => _firestore
          .collection(FirestoreCollections.mindAidFeedback)
          .doc('${userId}_$messageId')
          .set({
            'userId': userId,
            'messageId': messageId,
            'helpful': helpful,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
    );
  }

  static String createConversationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
