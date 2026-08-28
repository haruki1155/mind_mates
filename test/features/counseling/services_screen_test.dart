import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/counseling/screens/pacc_counseling_screen.dart';
import 'package:mind_mates/features/counseling/screens/reactivation_request_screen.dart';
import 'package:mind_mates/features/counseling/screens/service_detail_screen.dart';
import 'package:mind_mates/features/counseling/screens/services_screen.dart';
import 'package:mind_mates/models/appointment_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/appointment_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/appointment_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('services screen shows compact tappable service cards', (
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
    expect(find.text('Information Service'), findsOneWidget);
    expect(find.text('Individual Inventory Service'), findsOneWidget);
    expect(find.text('Testing Service'), findsOneWidget);
    expect(find.text('Counseling Service'), findsOneWidget);
    expect(find.text('Career Guidance and Placement Service'), findsOneWidget);
    expect(find.text('Referral Service'), findsOneWidget);
    expect(find.text('Follow-up Service'), findsOneWidget);
    expect(find.text('Key Features'), findsNothing);
    expect(find.text('Learn More'), findsNothing);
    expect(find.text('Inquire'), findsNothing);
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

  testWidgets('appointment details and MindMate calendar work', (tester) async {
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
    await tester.pumpAndSettle();
    expect(find.text('Appointment Calendar'), findsOneWidget);
    expect(find.text('April 30, 2026'), findsOneWidget);
  });

  testWidgets('service cards open the correct detail screen', (tester) async {
    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Testing Service'));
    await tester.pumpAndSettle();

    expect(find.byType(ServiceDetailScreen), findsOneWidget);
    expect(find.text('Service Details'), findsOneWidget);
    expect(
      find.textContaining(
        'Using psychological tests and non-psychometric devices',
      ),
      findsOneWidget,
    );
    expect(find.text('Request an Appointment'), findsNothing);
  });

  testWidgets('counseling detail opens the appointment flow', (tester) async {
    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Counseling Service'));
    await tester.pumpAndSettle();
    expect(find.text('Request an Appointment'), findsOneWidget);

    await tester.tap(find.text('Request an Appointment'));
    await tester.pumpAndSettle();

    expect(find.byType(PaccCounselingScreen), findsOneWidget);
  });

  testWidgets('follow-up detail opens the reactivation request form', (
    tester,
  ) async {
    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Follow-up Service'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Follow-up Service'));
    await tester.pumpAndSettle();
    expect(find.text('Request reactivation'), findsOneWidget);

    await tester.tap(find.text('Request reactivation'));
    await tester.pumpAndSettle();
    expect(find.byType(ReactivationRequestScreen), findsOneWidget);
    expect(
      find.text('APPLICATION FOR REACTIVATION\nOF ENROLLMENT'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Attachments (optional)'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Attachments (optional)'), findsOneWidget);
  });

  testWidgets('reactivation form pre-fills the signed-in student profile', (
    tester,
  ) async {
    final provider = UserProvider(_FakeUserRepository())
      ..setUser(
        const UserModel(
          id: 'user_1',
          email: 'leo@example.com',
          firstName: 'Leonardo',
          lastName: 'Molar',
          schoolId: '2026-001',
          course: 'BS Information Technology',
          department: 'College of Information Technology',
          yearLevel: 'Fourth Year',
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: provider,
        child: const MaterialApp(home: ReactivationRequestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leonardo Molar'), findsOneWidget);
    expect(find.text('2026-001'), findsOneWidget);
    expect(find.text('BS Information Technology'), findsOneWidget);
    expect(find.text('College of Information Technology'), findsOneWidget);
  });

  testWidgets('service detail back returns to services', (tester) async {
    await tester.pumpWidget(_servicesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Information Service'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ServicesScreen), findsOneWidget);
    expect(find.text('Information Service'), findsOneWidget);
  });

  testWidgets('app user can accept a server-confirmed reschedule proposal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeAppointmentRepository(
      appointments: [
        AppointmentModel(
          id: 'proposal-1',
          userId: 'user_1',
          fullName: 'Molar, Leonardo M.',
          scheduledAt: DateTime(2026, 4, 30, 11),
          scheduledTime: '11:00 AM',
          proposedScheduledAt: DateTime(2026, 5, 2, 14),
          proposedScheduledTime: '2:00 PM',
          location: 'PACC Office',
          status: 'reschedule_proposed',
          concern: 'Needs support.',
          contactNumber: '+63 912 345 6789',
          email: 'leo@example.com',
          preferredContactMethod: 'Email',
          createdAt: DateTime(2026, 4, 15),
        ),
      ],
    );
    await tester.pumpWidget(_paccApp(appointmentRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Details'));
    await tester.pumpAndSettle();
    expect(find.text('Accept new schedule'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    await tester.tap(find.text('Accept new schedule'));
    await tester.pumpAndSettle();
    expect(repository.rescheduleResponses, [true]);
  });

  testWidgets('past appointment dates are disabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_paccApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appoint New'));
    await tester.pumpAndSettle();
    await _fillVisibleForm(tester);
    await _chooseVisibleOption(tester, 'Male');
    await _chooseVisibleOption(tester, 'Fourth Year');
    await _chooseVisibleOption(tester, 'Email');
    await _chooseVisibleOption(tester, 'No');
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('Appointment Schedule'), findsOneWidget);
    expect(find.text('Choose Time'), findsNothing);
  });
}

Widget _servicesApp() {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: const ServicesScreen(),
  );
}

Widget _paccApp({_FakeAppointmentRepository? appointmentRepository}) {
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

  final appointments = appointmentRepository ?? _FakeAppointmentRepository();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ChangeNotifierProvider(create: (_) => AppointmentProvider(appointments)),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: PaccCounselingScreen(nowProvider: () => DateTime(2026, 4, 15, 9)),
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

class _FakeAppointmentRepository extends AppointmentRepository {
  _FakeAppointmentRepository({List<AppointmentModel> appointments = const []})
    : appointments = [...appointments];

  final List<AppointmentModel> appointments;
  bool shouldFail = false;
  final List<bool> rescheduleResponses = [];

  @override
  Future<List<AppointmentModel>> fetchAppointments(String userId) async {
    if (shouldFail) throw StateError('load failed');
    return appointments.where((item) => item.userId == userId).toList();
  }

  @override
  Future<AppointmentModel> createAppointment(
    AppointmentModel appointment, {
    String? submissionId,
  }) async {
    if (shouldFail) throw StateError('save failed');
    final created = appointment.copyWith(
      id: 'appointment_${appointments.length + 1}',
    );
    appointments.insert(0, created);
    return created;
  }

  @override
  Future<AppointmentRescheduleResult> respondToReschedule({
    required String appointmentId,
    required bool accept,
    required String operationId,
  }) async {
    rescheduleResponses.add(accept);
    final current = appointments.singleWhere(
      (item) => item.id == appointmentId,
    );
    return AppointmentRescheduleResult(
      status: accept ? 'confirmed' : 'pending',
      scheduledAt: accept ? current.proposedScheduledAt! : current.scheduledAt,
      scheduledTime: accept
          ? current.proposedScheduledTime!
          : current.scheduledTime,
    );
  }
}
