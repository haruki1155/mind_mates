import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/authentication/auth_flow_routes.dart';
import 'package:mind_mates/features/splash/screens/splash_screen.dart';
import 'package:mind_mates/features/authentication/screens/assessment_status_gate_screen.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/auth_provider.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/auth_repository.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:mind_mates/features/admin/domain/admin_management_models.dart';
import 'package:mind_mates/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('splash routes signed out users to login', (tester) async {
    await tester.pumpWidget(
      _SplashHarness(
        authProvider: AuthProvider(_FakeAuthRepository()),
        userProvider: UserProvider(_FakeUserRepository()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1901));
    await tester.pumpAndSettle();

    expect(find.text('login target'), findsOneWidget);
  });

  testWidgets('splash routes signed in users to home and loads profile', (
    tester,
  ) async {
    final userRepository = _FakeUserRepository(
      user: const UserModel(id: 'user_1', email: 'leo@example.com'),
    );

    await tester.pumpWidget(
      _SplashHarness(
        authProvider: AuthProvider(
          _FakeAuthRepository(currentUserId: 'user_1'),
        ),
        userProvider: UserProvider(userRepository),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1901));
    await tester.pumpAndSettle();

    expect(find.text('home target'), findsOneWidget);
    expect(userRepository.loadedUid, 'user_1');
  });

  testWidgets(
    'splash preserves auth when assessment verification is unavailable',
    (tester) async {
      final authRepository = _FakeAuthRepository(currentUserId: 'user_1');
      await tester.pumpWidget(
        _SplashHarness(
          authProvider: AuthProvider(authRepository),
          userProvider: UserProvider(
            _FakeUserRepository(
              user: const UserModel(id: 'user_1', email: 'leo@example.com'),
            ),
          ),
          assessmentRepository: _FakeAssessmentRepository(throws: true),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1901));
      await tester.pumpAndSettle();

      expect(find.text('Retry status check'), findsOneWidget);
      expect(authRepository.signOutCalls, 0);
    },
  );

  test('post-auth destination opens onboarding before quick assessment', () {
    expect(
      destinationAfterAuthentication(hasCompletedQuickAssessment: false),
      RouteNames.onboarding,
    );
  });

  test('post-auth destination opens home after quick assessment', () {
    expect(
      destinationAfterAuthentication(hasCompletedQuickAssessment: true),
      RouteNames.home,
    );
  });

  test('suspended state takes precedence over onboarding and assessment', () {
    const profile = UserModel(
      id: 'user_1',
      email: 'leo@example.com',
      staffAccountStatus: StaffAccountStatus.disabled,
    );
    expect(
      resolveAccountState(
        isAuthenticated: true,
        profile: profile,
        assessmentCompleted: false,
        onboardingComplete: false,
      ),
      AccountState.suspended,
    );
  });

  test('missing profile takes precedence over assessment state', () {
    expect(
      resolveAccountState(
        isAuthenticated: true,
        profile: null,
        assessmentCompleted: true,
      ),
      AccountState.profileRecoveryRequired,
    );
  });
}

class _SplashHarness extends StatelessWidget {
  const _SplashHarness({
    required this.authProvider,
    required this.userProvider,
    this.assessmentRepository,
  });

  final AuthProvider authProvider;
  final UserProvider userProvider;
  final AssessmentRepository? assessmentRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider<AssessmentProvider>(
          create: (_) => AssessmentProvider(
            assessmentRepository ?? _FakeAssessmentRepository(),
          ),
        ),
      ],
      child: MaterialApp(
        initialRoute: RouteNames.splash,
        routes: {
          RouteNames.splash: (_) => const SplashScreen(),
          RouteNames.assessmentStatus: (_) =>
              const AssessmentStatusGateScreen(),
          RouteNames.login: (_) => const _RouteMarker('login target'),
          RouteNames.onboarding: (_) => const _RouteMarker('onboarding target'),
          RouteNames.home: (_) => const _RouteMarker('home target'),
        },
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.currentUserId}) : super(AuthService());

  @override
  final String? currentUserId;
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeUserRepository extends UserRepository {
  _FakeUserRepository({this.user});

  final UserModel? user;
  String? loadedUid;

  @override
  Future<UserModel?> fetchUserProfile(String uid) async {
    loadedUid = uid;
    return user;
  }
}

class _FakeAssessmentRepository extends AssessmentRepository {
  _FakeAssessmentRepository({this.throws = false});

  final bool throws;

  @override
  Future<bool> ensureQuickAssessmentCompletion(String userId) async {
    if (throws) throw StateError('temporary backend failure');
    return true;
  }
}
