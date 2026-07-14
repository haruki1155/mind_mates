import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/sleep/models/sleep_models.dart';
import 'package:mind_mates/features/sleep/screens/sleep_quality_screen.dart';
import 'package:mind_mates/providers/sleep_provider.dart';
import 'package:mind_mates/repositories/sleep_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'guided form exposes core inputs, ratings, tags, and safety guidance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FormRepository();
      final provider = SleepProvider(repository);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: SleepEntryFormScreen(userId: 'user_1'),
          ),
        ),
      );

      expect(find.text('Attempted sleep'), findsOneWidget);
      expect(find.text('Estimated sleep onset'), findsOneWidget);
      expect(find.text('Morning restfulness: 3/5'), findsOneWidget);
      expect(find.text('Perceived sleep quality: 3/5'), findsOneWidget);
      expect(find.text('Breathing pauses or gasping'), findsOneWidget);

      await tester.ensureVisible(find.text('Breathing pauses or gasping'));
      await tester.tap(find.text('Breathing pauses or gasping'));
      await tester.pump();
      expect(find.textContaining('worth discussing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('default valid entry saves through the provider', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FormRepository();
    final provider = SleepProvider(repository);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SleepEntryFormScreen(userId: 'user_1')),
      ),
    );
    await tester.ensureVisible(find.text('Save sleep entry'));
    await tester.tap(find.text('Save sleep entry'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.wakeDateKey, hasLength(8));
    expect(repository.saved!.perceivedQuality, 3);
  });
}

class _FormRepository extends SleepRepository {
  SleepEntry? saved;

  @override
  Future<List<SleepEntry>> save(
    SleepEntry entry, {
    required bool cloudEnabled,
  }) async {
    saved = entry;
    return [entry];
  }
}
