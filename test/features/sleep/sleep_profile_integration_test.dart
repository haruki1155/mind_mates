import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/profile/screens/profile_screen.dart';
import 'package:mind_mates/features/sleep/models/sleep_models.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/auth_provider.dart';
import 'package:mind_mates/providers/sleep_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/auth_repository.dart';
import 'package:mind_mates/repositories/sleep_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:mind_mates/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Profile shows sleep quality and opens the diary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final userProvider = UserProvider(_UserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'user@example.com'));
    final sleepProvider = SleepProvider(_SleepRepository());
    await sleepProvider.load('user_1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userProvider),
          ChangeNotifierProvider.value(value: sleepProvider),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(_AuthRepository()),
          ),
        ],
        child: MaterialApp(
          routes: {
            RouteNames.home: (_) => const Scaffold(body: Text('Home route')),
            RouteNames.sleepQuality: (_) =>
                const Scaffold(body: Text('Sleep diary route')),
          },
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('4.0/5'), findsOneWidget);
    expect(find.text('Sleep Quality'), findsOneWidget);
    await tester.tap(find.text('Sleep Quality'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sleep diary route'), findsOneWidget);
  });

  testWidgets('Profile shows an empty sleep quality until an entry is saved', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final userProvider = UserProvider(_UserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'user@example.com'));
    final repository = _SleepRepository(entries: const []);
    final sleepProvider = SleepProvider(repository);
    await sleepProvider.load('user_1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userProvider),
          ChangeNotifierProvider.value(value: sleepProvider),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(_AuthRepository()),
          ),
        ],
        child: MaterialApp(
          routes: {
            RouteNames.home: (_) => const Scaffold(body: Text('Home route')),
            RouteNames.sleepQuality: (_) => const Scaffold(),
          },
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('--/5'), findsOneWidget);
    await sleepProvider.save(_entry());
    await tester.pump();
    expect(find.text('4.0/5'), findsOneWidget);
  });

  testWidgets('Profile Home button clears the navigation stack', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final userProvider = UserProvider(_UserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'user@example.com'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userProvider),
          ChangeNotifierProvider.value(
            value: SleepProvider(_SleepRepository(entries: const [])),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(_AuthRepository()),
          ),
        ],
        child: MaterialApp(
          routes: {
            RouteNames.home: (_) => const Scaffold(body: Text('Home route')),
          },
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
  });
}

class _AuthRepository extends AuthRepository {
  _AuthRepository() : super(AuthService());
  @override
  String? get currentUserId => 'user_1';
}

class _UserRepository extends UserRepository {}

class _SleepRepository extends SleepRepository {
  _SleepRepository({List<SleepEntry>? entries})
    : _entries = entries ?? [_entry()];

  List<SleepEntry> _entries;

  @override
  Future<SleepLoadResult> load(String userId) async => SleepLoadResult(
    entries: _entries,
    consent: SleepConsent(
      choice: SleepConsentChoice.localOnly,
      version: SleepConsent.currentVersion,
      decidedAt: DateTime.now(),
    ),
    pendingSync: false,
  );

  @override
  Future<SleepSaveResult> save(
    SleepEntry entry, {
    required bool cloudEnabled,
  }) async {
    _entries = [..._entries.where((value) => value.id != entry.id), entry];
    return SleepSaveResult(
      status: SleepSaveStatus.savedLocallyAndSynced,
      savedEntry: entry,
    );
  }
}

SleepEntry _entry() {
  final wake = SleepCalculator.manilaDate(DateTime.now());
  return SleepEntry(
    id: SleepEntry.documentId('user_1', wake),
    userId: 'user_1',
    wakeDateKey: SleepEntry.wakeKey(wake),
    attemptedSleepAt: wake.subtract(const Duration(hours: 8)),
    sleepOnsetAt: wake.subtract(const Duration(hours: 7, minutes: 30)),
    finalWakeAt: wake,
    outOfBedAt: wake.add(const Duration(minutes: 15)),
    awakeningCount: 0,
    awakeMinutes: 0,
    napCount: 0,
    napMinutes: 0,
    restfulness: 4,
    daytimeSleepiness: 2,
    perceivedQuality: 4,
    contributorTags: const {},
    concernTags: const {},
    createdAt: DateTime.now(),
    clientUpdatedAt: DateTime.now(),
  );
}
