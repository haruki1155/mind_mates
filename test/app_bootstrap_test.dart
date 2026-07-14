import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/admin_main.dart';
import 'package:mind_mates/app.dart';
import 'package:mind_mates/app_bootstrap.dart';

void main() {
  test('web selects the admin portal root', () {
    final root = selectMindMateRoot(
      isWeb: true,
      mobileApp: const MindMateApp(),
    );

    expect(root, isA<MindMateAdminApp>());
  });

  test('native platforms preserve the mobile application root', () {
    const mobileApp = MindMateApp();

    final root = selectMindMateRoot(isWeb: false, mobileApp: mobileApp);

    expect(identical(root, mobileApp), isTrue);
  });

  testWidgets('admin root displays staff login instead of mobile startup', (
    tester,
  ) async {
    await tester.pumpWidget(
      selectMindMateRoot(
        isWeb: true,
        mobileApp: const MaterialApp(home: Text('Mobile application')),
      ),
    );

    expect(find.text('MindMate'), findsOneWidget);
    expect(find.text('Counseling Management System'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Mobile application'), findsNothing);
  });
}
