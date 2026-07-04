import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/authentication/auth_flow_routes.dart';
import 'package:mind_mates/features/authentication/screens/account_gate_screen.dart';
import 'package:mind_mates/features/splash/screens/splash_screen.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/auth_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/auth_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/app_pages.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:mind_mates/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  test('account gate route is registered', () {
    expect(AppPages.routes[RouteNames.accountGate], isNotNull);
  });

  testWidgets('account gate sends existing users to login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {RouteNames.login: (_) => const _RouteMarker('login target')},
        home: const AccountGateScreen(),
      ),
    );

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    expect(find.text('login target'), findsOneWidget);
  });

  testWidgets('account gate sends new users to quick assessment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          RouteNames.quickAssessmentRole: (_) =>
              const _RouteMarker('quick assessment target'),
        },
        home: const AccountGateScreen(),
      ),
    );

    await tester.tap(find.text('I am new here'));
    await tester.pumpAndSettle();

    expect(find.text('quick assessment target'), findsOneWidget);
  });

  testWidgets('splash routes signed out users to account gate', (tester) async {
    await tester.pumpWidget(
      _SplashHarness(
        authProvider: AuthProvider(_FakeAuthRepository()),
        userProvider: UserProvider(_FakeUserRepository()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1901));
    await tester.pumpAndSettle();

    expect(find.text('account gate target'), findsOneWidget);
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

  test('post-auth destination skips quick assessment when none is pending', () {
    expect(
      destinationAfterAuthentication(savedQuickAssessment: false),
      RouteNames.home,
    );
  });

  test('post-auth destination keeps pending quick assessment follow-up', () {
    expect(
      destinationAfterAuthentication(savedQuickAssessment: true),
      RouteNames.quickAssessmentCategory,
    );
  });
}

class _SplashHarness extends StatelessWidget {
  const _SplashHarness({
    required this.authProvider,
    required this.userProvider,
  });

  final AuthProvider authProvider;
  final UserProvider userProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: MaterialApp(
        initialRoute: RouteNames.splash,
        routes: {
          RouteNames.splash: (_) => const SplashScreen(),
          RouteNames.accountGate: (_) =>
              const _RouteMarker('account gate target'),
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
