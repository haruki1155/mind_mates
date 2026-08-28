import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/authentication/screens/forgot_password_screen.dart';
import 'package:mind_mates/features/authentication/screens/recovery_email_screen.dart';
import 'package:mind_mates/features/authentication/screens/reset_password_screen.dart';
import 'package:mind_mates/services/auth/recovery_service.dart';

class _FakeRecoveryService implements RecoveryService {
  Future<void> Function(String schoolId)? onPasswordRequest;
  Future<void> Function(String email)? onRecoveryEmailRequest;
  Future<void> Function(String token)? onRecoveryEmailConfirmation;
  Future<void> Function(String token, String password)? onPasswordConfirmation;

  int passwordRequestCount = 0;

  @override
  Future<void> requestPasswordRecovery(String schoolId) {
    passwordRequestCount++;
    return onPasswordRequest?.call(schoolId) ?? Future<void>.value();
  }

  @override
  Future<void> requestRecoveryEmailVerification(String email) =>
      onRecoveryEmailRequest?.call(email) ?? Future<void>.value();

  @override
  Future<void> confirmRecoveryEmailVerification(String token) =>
      onRecoveryEmailConfirmation?.call(token) ?? Future<void>.value();

  @override
  Future<void> confirmPasswordRecovery({
    required String token,
    required String password,
  }) => onPasswordConfirmation?.call(token, password) ?? Future<void>.value();
}

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  testWidgets('forgot password delegates to the recovery service', (
    tester,
  ) async {
    final service = _FakeRecoveryService();
    String? schoolId;
    service.onPasswordRequest = (value) async => schoolId = value;

    await tester.pumpWidget(
      _app(ForgotPasswordScreen(recoveryService: service)),
    );
    await tester.enterText(find.byType(TextField), '  STU-42  ');
    await tester.tap(find.text('Send reset instructions'));
    await tester.pumpAndSettle();

    expect(schoolId, 'STU-42');
    expect(
      find.text(
        'If this account has a verified recovery email, reset instructions have been sent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('forgot password maps service failures to safe UI copy', (
    tester,
  ) async {
    final service = _FakeRecoveryService();
    service.onPasswordRequest = (_) async => throw StateError('backend detail');

    await tester.pumpWidget(
      _app(ForgotPasswordScreen(recoveryService: service)),
    );
    await tester.enterText(find.byType(TextField), 'STU-42');
    await tester.tap(find.text('Send reset instructions'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to request password recovery.'), findsOneWidget);
    expect(find.text('backend detail'), findsNothing);
  });

  testWidgets('recovery email delegates the entered email', (tester) async {
    final service = _FakeRecoveryService();
    String? email;
    service.onRecoveryEmailRequest = (value) async => email = value;

    await tester.pumpWidget(
      _app(RecoveryEmailScreen(recoveryService: service)),
    );
    await tester.enterText(find.byType(TextField), 'person@example.com');
    await tester.tap(find.text('Send verification email'));
    await tester.pumpAndSettle();

    expect(email, 'person@example.com');
    expect(
      find.text(
        'Verification email sent. Open the link to confirm this address.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('forgot password prevents duplicate in-flight requests', (
    tester,
  ) async {
    final service = _FakeRecoveryService();
    final pending = Completer<void>();
    service.onPasswordRequest = (_) => pending.future;

    await tester.pumpWidget(
      _app(ForgotPasswordScreen(recoveryService: service)),
    );
    await tester.enterText(find.byType(TextField), 'STU-42');
    await tester.tap(find.text('Send reset instructions'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(service.passwordRequestCount, 1);

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('reset password rejects an invalid link before calling service', (
    tester,
  ) async {
    final service = _FakeRecoveryService();

    await tester.pumpWidget(
      _app(ResetPasswordScreen(recoveryService: service)),
    );
    await tester.enterText(find.byType(TextField).first, 'password123');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(service.onPasswordConfirmation, isNull);
    expect(
      find.text(
        'Use a valid reset link, at least 8 characters, and matching passwords.',
      ),
      findsOneWidget,
    );
  });
}
