import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind_mates/services/firebase/firebase_operation.dart';

void main() {
  test(
    'requires a live authenticated user before a protected operation',
    () async {
      var calls = 0;
      final runner = FirebaseOperationRunner(currentUserId: () => null);

      await expectLater(
        runner.run(
          area: 'test save',
          operation: () async {
            calls += 1;
            return true;
          },
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(calls, 0);
    },
  );

  test('refreshes Auth once after unauthenticated and retries', () async {
    var calls = 0;
    var refreshes = 0;
    final runner = FirebaseOperationRunner(
      currentUserId: () => 'user_1',
      refreshAuthToken: () async => refreshes += 1,
    );

    final result = await runner.run(
      area: 'test save',
      operation: () async {
        calls += 1;
        if (calls == 1) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unauthenticated',
          );
        }
        return 'saved';
      },
    );

    expect(result, 'saved');
    expect(calls, 2);
    expect(refreshes, 1);
  });

  test('does not retry permission or App Check failures', () async {
    for (final code in ['permission-denied', 'app-check']) {
      var calls = 0;
      var refreshes = 0;
      final runner = FirebaseOperationRunner(
        currentUserId: () => 'user_1',
        refreshAuthToken: () async => refreshes += 1,
      );

      await expectLater(
        runner.run(
          area: 'test save',
          operation: () async {
            calls += 1;
            throw FirebaseException(plugin: 'cloud_firestore', code: code);
          },
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(calls, 1);
      expect(refreshes, 0);
    }
  });
}
