import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/counseling/screens/pacc_counseling_screen.dart';
import 'package:mind_mates/features/counseling/screens/services_screen.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('services screen matches the mockup structure and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.text('PACC Services'), findsOneWidget);
    expect(find.text('All Services'), findsOneWidget);
    expect(find.text('Information Services'), findsOneWidget);
    expect(find.text('Individual Inventory Services'), findsOneWidget);
    expect(find.text('Counseling Services'), findsOneWidget);
    expect(find.text('Career Guidance and Placement Services'), findsOneWidget);
    expect(find.text('Referral Services'), findsOneWidget);
    expect(find.text('Follow-up Services'), findsOneWidget);
    expect(find.text('Inquire'), findsNWidgets(3));
    expect(find.text('Contact counselor'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Secret chat'), findsNothing);
  });

  testWidgets('services Back returns to the previous screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ServicesScreen())),
              child: const Text('Open services'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open services'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open services'), findsOneWidget);
    expect(find.byType(ServicesScreen), findsNothing);
  });

  testWidgets('services root Back falls back to Home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/services-root',
        routes: {
          '/services-root': (_) => const ServicesScreen(),
          RouteNames.home: (_) => const Scaffold(body: Text('Home target')),
        },
      ),
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Home target'), findsOneWidget);
  });

  testWidgets('services layout has no overflow on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Contact counselor'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('contact counselor opens PACC appointment flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Contact counselor'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact counselor'));
    await tester.pumpAndSettle();

    expect(find.byType(PaccCounselingScreen), findsOneWidget);
    expect(find.text('PACC Counseling'), findsOneWidget);
    expect(find.text('No upcoming appointments'), findsOneWidget);
    expect(find.text('Appoint a Session'), findsOneWidget);
  });

  testWidgets('appointment flow creates an in-memory appointment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_paccApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appoint New'));
    await tester.pumpAndSettle();
    expect(find.text('Counseling Intake Form'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Please complete all required fields.'), findsOneWidget);

    await _fillVisibleForm(tester);
    await _chooseVisibleOption(tester, 'Male');
    await _chooseVisibleOption(tester, 'Fourth Year');
    await _chooseVisibleOption(tester, 'Email');
    await _chooseVisibleOption(tester, 'No');

    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment Schedule'), findsOneWidget);
    expect(find.text('April 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to intake form'));
    await tester.pumpAndSettle();
    expect(find.text('Counseling Intake Form'), findsOneWidget);
    expect(
      find.text('I feel overwhelmed and would like to talk to someone.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Time'), findsOneWidget);
    expect(find.text('Thursday, April 30'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment Schedule'), findsOneWidget);

    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Appointment').last);
    await tester.pumpAndSettle();
    expect(find.text('Confirm Appointment'), findsOneWidget);

    await tester.tap(find.text('Back to My Appointments'));
    await tester.pumpAndSettle();
    expect(find.text('Molar, Leonardo M.'), findsOneWidget);
    expect(find.text('Thursday, April 30, 2026'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
    expect(
      find.text('I feel overwhelmed and would like to talk to someone.'),
      findsOneWidget,
    );
  });

  testWidgets('appointment details and calendar phase 2 feedback work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_paccApp());
    await tester.pumpAndSettle();
    await _createAppointment(tester);

    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();
    expect(find.text('Appointment Details'), findsOneWidget);
    expect(find.text('Email | +63 912 345 6789'), findsOneWidget);

    Navigator.of(tester.element(find.text('Appointment Details'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to Calendar'));
    await tester.pump();
    expect(
      find.text('Calendar integration is coming in phase 2.'),
      findsOneWidget,
    );
  });
}

Widget _servicesApp() {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: const ServicesScreen(),
  );
}

Widget _paccApp() {
  final userProvider = UserProvider(_FakeUserRepository())
    ..setUser(
      const UserModel(
        id: 'user_1',
        email: 'leo@example.com',
        firstName: 'Leonardo',
        middleName: 'M',
        lastName: 'Molar',
        course: 'BS Information Technology',
      ),
    );

  return ChangeNotifierProvider<UserProvider>.value(
    value: userProvider,
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const PaccCounselingScreen(),
    ),
  );
}

Future<void> _createAppointment(WidgetTester tester) async {
  await tester.tap(find.text('Appoint New'));
  await tester.pumpAndSettle();
  await _fillVisibleForm(tester);
  await _chooseVisibleOption(tester, 'Male');
  await _chooseVisibleOption(tester, 'Fourth Year');
  await _chooseVisibleOption(tester, 'Email');
  await _chooseVisibleOption(tester, 'No');

  await tester.ensureVisible(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('30'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('11:00 AM'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm Appointment').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Back to My Appointments'));
  await tester.pumpAndSettle();
}

Future<void> _fillVisibleForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(3), '20');
  await tester.enterText(fields.at(4), 'Urdaneta City');
  await tester.enterText(fields.at(5), '+63 912 345 6789');
  await tester.enterText(fields.at(6), 'leo@example.com');
  await tester.enterText(fields.at(7), 'facebook.com/leo');
  await tester.enterText(
    fields.at(8),
    'I feel overwhelmed and would like to talk to someone.',
  );
  await tester.enterText(fields.at(9), 'Weekday mornings');
}

Future<void> _chooseVisibleOption(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _FakeUserRepository extends UserRepository {}
