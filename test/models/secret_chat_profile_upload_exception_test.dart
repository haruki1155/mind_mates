import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/secret_chat_profile_upload_exception.dart';

void main() {
  test(
    'profile upload errors expose stable categories and friendly messages',
    () {
      const error = SecretChatProfileUploadException(
        SecretChatProfileUploadError.appCheckRejected,
        'Device verification failed.',
      );

      expect(error.code, SecretChatProfileUploadError.appCheckRejected);
      expect(error.toString(), 'Device verification failed.');
    },
  );
}
