import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mind_mates/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile startup renders the MindMate splash', (tester) async {
    await app.main();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('MindMate'), findsOneWidget);
  });
}
