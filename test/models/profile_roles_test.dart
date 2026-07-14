import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/profile_roles.dart';
import 'package:mind_mates/models/user_model.dart';

void main() {
  test('population roles parse canonical and legacy spellings', () {
    expect(PopulationRole.parse('student'), PopulationRole.student);
    expect(PopulationRole.parse('faculty'), PopulationRole.teaching);
    expect(PopulationRole.parse('Teaching Personnel'), PopulationRole.teaching);
    expect(PopulationRole.parse('staff'), PopulationRole.nonTeaching);
    expect(PopulationRole.parse('non-teaching'), PopulationRole.nonTeaching);
    expect(PopulationRole.parse('unknown'), isNull);
  });

  test('legacy privileged roles map only to access roles', () {
    expect(AccessRole.parse(null, legacyRole: 'admin'), AccessRole.admin);
    expect(
      AccessRole.parse(null, legacyRole: 'counselor'),
      AccessRole.counselor,
    );
    expect(AccessRole.parse(null, legacyRole: 'staff'), AccessRole.appUser);
  });

  test('role-specific completeness requires institutional fields', () {
    const student = UserModel(
      id: 's',
      email: 's@example.com',
      firstName: 'Sam',
      lastName: 'Lee',
      populationRole: PopulationRole.student,
      schoolId: 'S1',
      department: 'CITE',
      course: 'BSIT',
      yearLevel: '2',
    );
    expect(student.isProfileComplete, isTrue);
    expect(student.copyWith(yearLevel: '').isProfileComplete, isFalse);

    const teaching = UserModel(
      id: 't',
      email: 't@example.com',
      firstName: 'Tia',
      lastName: 'Yu',
      populationRole: PopulationRole.teaching,
      employeeId: 'E1',
      department: 'CITE',
      position: 'Instructor',
    );
    expect(teaching.isProfileComplete, isTrue);
  });
}
