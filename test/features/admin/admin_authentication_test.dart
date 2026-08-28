import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/admin/domain/admin_auth_failure.dart';
import 'package:mind_mates/features/admin/screens/admin_portal.dart';
import 'package:mind_mates/repositories/admin_portal_repository.dart';

class _FailingAdminRepository extends AdminPortalRepository {
  _FailingAdminRepository(this.error);

  final Object error;

  @override
  Future<void> signInStaff({
    required String schoolId,
    required String password,
  }) async {
    throw error;
  }
}

void main() {
  test('credential errors are safe and do not expose Firebase raw text', () {
    final failure = AdminAuthenticationException.fromFirebase(
      FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The supplied auth credential is malformed or expired.',
      ),
      stage: AdminAuthenticationStage.credentials,
      fallback: 'fallback',
    );

    expect(failure.userMessage, 'Email or password is incorrect.');
    expect(failure.userMessage, isNot(contains('malformed')));
    expect(failure.stage, AdminAuthenticationStage.credentials);
  });

  test('super-admin denial keeps its safe correlation ID', () {
    final failure = AdminAuthenticationException.fromFirebase(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'internal authorization detail',
        details: const {'correlationId': 'safe-correlation'},
      ),
      stage: AdminAuthenticationStage.superAdminConfirmation,
      fallback: 'fallback',
    );

    expect(
      failure.userMessage,
      'This account is not the configured super-administrator.',
    );
    expect(failure.correlationId, 'safe-correlation');
    expect(failure.userMessage, isNot(contains('internal')));
  });

  testWidgets('Admin login never renders an unknown raw exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminLoginScreen(
          repository: _FailingAdminRepository(
            StateError('sensitive backend implementation detail'),
          ),
        ),
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'administrator@example.test');
    await tester.enterText(fields.at(1), 'not-a-real-password');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(
      find.text('Unable to sign in to the Admin portal. Try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive backend'), findsNothing);
  });
}
