import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release Android manifest permits network access', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.INTERNET" />',
      ),
      reason: 'Firebase and HTTP features require INTERNET in release builds.',
    );
  });
}
