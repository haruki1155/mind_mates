import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';

typedef FirebaseOperation<T> = Future<T> Function();

class FirebaseOperationRunner {
  FirebaseOperationRunner({
    FirebaseAuth? auth,
    String? Function()? currentUserId,
    this.refreshAuthToken,
  }) : _authOverride = auth,
       _currentUserIdOverride = currentUserId,
       _hasCurrentUserIdOverride = currentUserId != null;

  final FirebaseAuth? _authOverride;
  final String? Function()? _currentUserIdOverride;
  final bool _hasCurrentUserIdOverride;
  final Future<void> Function()? refreshAuthToken;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get currentUserId => _hasCurrentUserIdOverride
      ? _currentUserIdOverride!.call()
      : _auth.currentUser?.uid;

  Future<T> run<T>({
    required String area,
    required FirebaseOperation<T> operation,
    bool requiresAuthentication = true,
  }) async {
    if (requiresAuthentication && currentUserId == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Sign in is required before this action.',
      );
    }

    try {
      return await operation();
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'unauthenticated' ||
          !requiresAuthentication ||
          currentUserId == null) {
        _log(area, error, stackTrace, retry: false);
        rethrow;
      }

      _log(area, error, stackTrace, retry: true);
      try {
        await (refreshAuthToken?.call() ?? _auth.currentUser!.getIdToken(true));
        final result = await operation();
        developer.log(
          '$area succeeded after Firebase Auth token refresh.',
          name: 'FirebaseOperation',
        );
        return result;
      } on FirebaseException catch (retryError, retryStackTrace) {
        _log(
          area,
          retryError,
          retryStackTrace,
          retry: false,
          retryResult: 'failed',
        );
        rethrow;
      }
    }
  }

  void _log(
    String area,
    Object error,
    StackTrace stackTrace, {
    required bool retry,
    String? retryResult,
  }) {
    developer.log(
      '$area failed (code: ${_errorCode(error)}, retry: $retry${retryResult == null ? '' : ', retryResult: $retryResult'}).',
      name: 'FirebaseOperation',
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _errorCode(Object error) {
    if (error is FirebaseException) return error.code;
    return 'unknown';
  }
}
