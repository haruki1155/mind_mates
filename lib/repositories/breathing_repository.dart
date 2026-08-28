import 'package:cloud_functions/cloud_functions.dart';

import '../features/breathing/models/breathing_models.dart';
import '../services/firebase/firebase_callable_router.dart';

class BreathingSessionRecord {
  const BreathingSessionRecord({
    required this.sessionId,
    required this.technique,
  });

  final String sessionId;
  final BreathingTechnique technique;
}

class BreathingRepository {
  // Firebase is deliberately resolved lazily so repository fakes can run
  // without a Firebase app in unit/widget tests.
  // ignore: prefer_initializing_formals
  BreathingRepository({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;
  FirebaseFunctions get _client =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> startSession(BreathingSessionRecord record) async {
    await _client.routedCallable('startBreathingSession').call({
      'sessionId': record.sessionId,
      'techniqueId': record.technique.id,
    });
  }

  Future<String> completeSession(BreathingSessionRecord record) async {
    final response = await _client
        .routedCallable('completeBreathingSession')
        .call({
          'sessionId': record.sessionId,
          'techniqueId': record.technique.id,
        });
    final data = response.data;
    if (data is! Map || data['sessionId']?.toString() != record.sessionId) {
      throw const FormatException('Breathing completion response was invalid.');
    }
    return record.sessionId;
  }
}
