import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

enum AdminAuthenticationStage {
  credentials,
  emailVerification,
  appCheck,
  profile,
  authorization,
  superAdminConfirmation,
  network,
}

class AdminAuthenticationException implements Exception {
  const AdminAuthenticationException({
    required this.stage,
    required this.code,
    required this.userMessage,
    this.correlationId,
  });

  final AdminAuthenticationStage stage;
  final String code;
  final String userMessage;
  final String? correlationId;

  factory AdminAuthenticationException.fromFirebase(
    Object error, {
    required AdminAuthenticationStage stage,
    required String fallback,
  }) {
    final code = error is FirebaseException ? error.code : 'unknown';
    final normalized = code.toLowerCase();
    final text = error.toString().toLowerCase();
    final correlationId = _correlationId(error);

    if (text.contains('app check') ||
        text.contains('appcheck') ||
        normalized == 'app-check' ||
        normalized == 'unauthorized') {
      return AdminAuthenticationException(
        stage: AdminAuthenticationStage.appCheck,
        code: normalized,
        userMessage:
            'This Admin web session could not be verified by Firebase App Check. '
            'Reload the official hosted site and try again.',
        correlationId: correlationId,
      );
    }

    final message = switch (normalized) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'invalid-email' => 'Enter a valid portal account email address.',
      'user-disabled' => 'This portal account is disabled.',
      'too-many-requests' =>
        'Sign-in is temporarily blocked after too many attempts. Try again later.',
      'network-request-failed' || 'unavailable' =>
        'The Admin portal cannot reach Firebase. Check the connection and try again.',
      'permission-denied' =>
        stage == AdminAuthenticationStage.superAdminConfirmation
            ? 'This account is not the configured super-administrator.'
            : 'Firebase denied access to the administrator profile.',
      'unauthenticated' => 'The portal session expired. Sign in again.',
      _ => fallback,
    };
    return AdminAuthenticationException(
      stage:
          normalized == 'network-request-failed' || normalized == 'unavailable'
          ? AdminAuthenticationStage.network
          : stage,
      code: normalized,
      userMessage: message,
      correlationId: correlationId,
    );
  }

  static String? _correlationId(Object error) {
    if (error is! FirebaseFunctionsException || error.details is! Map) {
      return null;
    }
    final value = (error.details as Map)['correlationId']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  String toString() => userMessage;
}
