enum SecretChatProfileUploadError {
  authenticationRequired,
  appCheckRejected,
  storageDenied,
  uploadFailed,
  downloadUrlFailed,
  profileUpdateDenied,
  cleanupFailed,
}

class SecretChatProfileUploadException implements Exception {
  const SecretChatProfileUploadException(this.code, this.message, [this.cause]);

  final SecretChatProfileUploadError code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
