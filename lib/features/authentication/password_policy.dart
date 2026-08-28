const int passwordMinimumLength = 8;
const int passwordMaximumLength = 128;

String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Password is required.';
  if (password.length < passwordMinimumLength) {
    return 'Use at least $passwordMinimumLength characters.';
  }
  if (password.length > passwordMaximumLength) {
    return 'Use no more than $passwordMaximumLength characters.';
  }
  return null;
}
