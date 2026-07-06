import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/authentication/screens/signup_screen.dart';
import 'package:mind_mates/features/quick_assessment/models/quick_assessment_models.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/providers/auth_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';
import 'package:mind_mates/repositories/auth_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:mind_mates/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('department selection enables related courses', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_SignupHarness(authProvider: _FakeAuthProvider()));

    expect(find.text('College or Department'), findsWidgets);
    expect(find.text('Course or Program'), findsWidgets);
    expect(find.text('Select college first'), findsOneWidget);

    await _selectDropdownItem(
      tester,
      fieldLabel: 'College or Department',
      itemLabel: 'College of Nursing',
    );

    await _selectDropdownItem(
      tester,
      fieldLabel: 'Course or Program',
      itemLabel: 'BS Nursing',
    );

    expect(find.text('College of Nursing'), findsOneWidget);
    expect(find.text('BS Nursing'), findsOneWidget);
  });

  testWidgets('changing department clears the previous course', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_SignupHarness(authProvider: _FakeAuthProvider()));

    await _selectDropdownItem(
      tester,
      fieldLabel: 'College or Department',
      itemLabel: 'College of Nursing',
    );
    await _selectDropdownItem(
      tester,
      fieldLabel: 'Course or Program',
      itemLabel: 'BS Nursing',
    );

    await _selectDropdownItem(
      tester,
      fieldLabel: 'College or Department',
      itemLabel: 'College of Pharmacy',
    );

    expect(find.text('College of Pharmacy'), findsOneWidget);
    expect(find.text('BS Nursing'), findsNothing);

    await _selectDropdownItem(
      tester,
      fieldLabel: 'Course or Program',
      itemLabel: 'BS Pharmacy',
    );
    expect(find.text('BS Pharmacy'), findsOneWidget);
  });

  testWidgets('signup requires department and course', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authProvider = _FakeAuthProvider();
    await tester.pumpWidget(_SignupHarness(authProvider: authProvider));

    await _fillRequiredTextFields(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(find.text('College or department is required'), findsOneWidget);
    expect(find.text('Course or program is required'), findsOneWidget);
    expect(authProvider.signupCalls, 0);
  });

  testWidgets('signup passes selected department and course', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authProvider = _FakeAuthProvider();
    await tester.pumpWidget(_SignupHarness(authProvider: authProvider));

    await _fillRequiredTextFields(tester);
    await _selectDropdownItem(
      tester,
      fieldLabel: 'College or Department',
      itemLabel:
          'College of Information and Technology Education / College of Computer Studies',
    );
    await _selectDropdownItem(
      tester,
      fieldLabel: 'Course or Program',
      itemLabel: 'BS Information Technology',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(authProvider.signupCalls, 1);
    expect(
      authProvider.department,
      'College of Information and Technology Education / College of Computer Studies',
    );
    expect(authProvider.course, 'BS Information Technology');
    expect(find.text('onboarding target'), findsOneWidget);
  });
}

Future<void> _fillRequiredTextFields(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'First Name'),
    'Leo',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Last Name'),
    'Molar',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'School ID'),
    '2026-1',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    'leo@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    'password123',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirm Password'),
    'password123',
  );
  await tester.pump();
}

Future<void> _selectDropdownItem(
  WidgetTester tester, {
  required String fieldLabel,
  required String itemLabel,
}) async {
  final field = find
      .byType(DropdownButtonFormField<String>)
      .at(fieldLabel == 'College or Department' ? 0 : 1);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();

  final item = find.text(itemLabel).last;
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

class _SignupHarness extends StatelessWidget {
  const _SignupHarness({required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(_FakeUserRepository()),
        ),
        ChangeNotifierProvider<AssessmentProvider>(
          create: (_) => AssessmentProvider(_FakeAssessmentRepository()),
        ),
      ],
      child: MaterialApp(
        home: const SignupScreen(),
        routes: {
          RouteNames.onboarding: (_) =>
              const Scaffold(body: Center(child: Text('onboarding target'))),
        },
      ),
    );
  }
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(_FakeAuthRepository());

  int signupCalls = 0;
  String? department;
  String? course;

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolId,
    required String department,
    required String course,
    String? middleName,
    AssessmentRole? role,
  }) async {
    signupCalls += 1;
    this.department = department;
    this.course = course;
    return 'user_1';
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(AuthService());
}

class _FakeUserRepository extends UserRepository {
  @override
  Future<UserModel?> fetchUserProfile(String uid) async {
    return UserModel(id: uid, email: 'leo@example.com');
  }
}

class _FakeAssessmentRepository extends AssessmentRepository {}
