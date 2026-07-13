import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/counseling/screens/mind_aid_screen.dart';
import 'package:mind_mates/features/mind_aid/domain/mind_aid_integration_models.dart';

void main() {
  test('cloud response ignores actions outside the client allowlist', () {
    final response = MindAidCloudResponse.fromMap({
      'messageId': 'message-1',
      'text': 'Try one small next step.',
      'intent': 'academic_stress',
      'actions': [
        {'type': 'startBreathing', 'label': 'Breathe'},
        {'type': 'openArbitraryRoute', 'label': 'Unsafe'},
      ],
    });

    expect(response.actions, hasLength(1));
    expect(response.actions.single.type, MindAidActionType.startBreathing);
  });

  testWidgets('assistant action invokes the typed callback', (tester) async {
    MindAidAction? selected;
    const action = MindAidAction(
      type: MindAidActionType.bookAppointment,
      label: 'Book an appointment',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MindAidScreen(
          messages: [
            MindAidMessage(
              id: 'assistant-1',
              sender: MindAidSender.assistant,
              text: 'Would you like to contact PACC?',
              createdAt: DateTime(2026),
              actions: const [action],
            ),
          ],
          onActionSelected: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Book an appointment'));
    expect(selected?.type, MindAidActionType.bookAppointment);
  });
}
