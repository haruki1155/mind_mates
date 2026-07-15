import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/admin/domain/admin_management_models.dart';
import 'package:mind_mates/features/admin/screens/staff_registration_screen.dart';
import 'package:mind_mates/features/authentication/data/registration_organization_catalog.dart';
import 'package:mind_mates/repositories/admin_portal_repository.dart';

class _EmptyDirectoryRepository extends AdminPortalRepository {
  @override
  Stream<List<College>> watchColleges() => Stream.value(const []);

  @override
  Stream<List<Course>> watchCourses() => Stream.value(const []);
}

void main() {
  test('shared staff department catalog retains app registration options', () {
    expect(
      staffDepartmentOptions,
      containsAll(<String>[
        'Administration',
        'Registrar',
        'Finance',
        'Library',
        'Guidance/PACC',
        'Health Services',
        'IT/MIS',
        'Maintenance/Facilities',
        'Security',
        'Other',
      ]),
    );
  });

  testWidgets('department works when the Firestore directory is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StaffRegistrationScreen(repository: _EmptyDirectoryRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No optional colleges or courses are configured.'),
      findsOneWidget,
    );
    final departmentDropdown = find
        .byType(DropdownButtonFormField<String>)
        .first;
    await tester.ensureVisible(departmentDropdown);
    await tester.tap(departmentDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Guidance/PACC'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });
}
