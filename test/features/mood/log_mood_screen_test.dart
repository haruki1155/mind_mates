import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/mood/screens/log_mood_screen.dart';

void main() {
  testWidgets('renders all mood choices and note field', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: LogMoodScreen()));

    expect(find.text('How are you feeling?'), findsOneWidget);
    for (final label in [
      'Great',
      'Okay',
      'Stressed',
      'Sad',
      'Angry',
      'Tired',
      'Excited',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text("What's on your mind today?"), findsOneWidget);
    expect(find.text('0/300 characters'), findsOneWidget);
  });

  testWidgets('tapping a mood updates selected card styling', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: LogMoodScreen()));

    final angryCard = find.byKey(const ValueKey('mood-card-Angry'));
    expect(_cardBorderWidth(tester, angryCard), 1.2);

    await tester.tap(find.text('Angry'));
    await tester.pumpAndSettle();

    expect(_cardBorderWidth(tester, angryCard), 2);
  });

  testWidgets('typing thoughts updates character count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: LogMoodScreen()));

    await tester.enterText(find.byType(TextField), 'Feeling steady today');
    await tester.pump();

    expect(find.text('20/300 characters'), findsOneWidget);
  });
}

double? _cardBorderWidth(WidgetTester tester, Finder finder) {
  final card = tester.widget<AnimatedContainer>(finder);
  final decoration = card.decoration;
  if (decoration is! BoxDecoration) return null;
  final border = decoration.border;
  if (border is! Border) return null;
  return border.top.width;
}
