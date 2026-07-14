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
  testWidgets('Profile shows latest-seven sleep average and opens the diary', (
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
    await tester.tap(find.text('Sleep'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sleep diary route'), findsOneWidget);
  });
}

class _AuthRepository extends AuthRepository {
  _AuthRepository() : super(AuthService());
  @override
  String? get currentUserId => 'user_1';
}

class _UserRepository extends UserRepository {}

class _SleepRepository extends SleepRepository {
  @override
  Future<SleepLoadResult> load(String userId) async => SleepLoadResult(
    entries: [_entry()],
    consent: SleepConsent(
      choice: SleepConsentChoice.localOnly,
      version: SleepConsent.currentVersion,
      decidedAt: DateTime.now(),
    ),
    pendingSync: false,
  );
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
