import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/admin_main.dart';
import 'package:mind_mates/app.dart';
import 'package:mind_mates/app_bootstrap.dart';
import 'package:mind_mates/services/firebase/firebase_app_check_service.dart';

void main() {
  test('web selects the normal user app root', () {
    const mobileApp = MindMateApp();
    final root = selectMindMateRoot(isWeb: true, mobileApp: mobileApp);

    expect(identical(root, mobileApp), isTrue);
  });

  test('native platforms preserve the mobile application root', () {
    const mobileApp = MindMateApp();

    final root = selectMindMateRoot(isWeb: false, mobileApp: mobileApp);

    expect(identical(root, mobileApp), isTrue);
  });

  testWidgets('explicit admin root displays staff login', (tester) async {
    await tester.pumpWidget(const MindMateAdminApp());
    await tester.pumpAndSettle();

    expect(find.text('MindMate'), findsOneWidget);
    expect(find.text('Counseling Management System'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('web shows a blocking gate when App Check is unconfigured', (
    tester,
  ) async {
    await tester.pumpWidget(
      selectMindMateRoot(
        isWeb: true,
        mobileApp: const MindMateApp(),
        appCheckStatus: FirebaseAppCheckStatus.missingWebConfiguration,
      ),
    );

    expect(
      find.text('MindMate web verification is not configured'),
      findsOneWidget,
    );
  });
}
