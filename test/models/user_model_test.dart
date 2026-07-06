import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('maps registration fields and defaults missing day streak', () {
      final user = UserModel.fromJson({
        'id': 'user_1',
        'email': 'leo@example.com',
        'firstName': 'Leonardo',
        'middleName': 'Santos',
        'lastName': 'Molar',
        'schoolId': '2026-0001',
        'department': 'Information Technology',
        'course': 'BS Information Technology',
        'role': 'student',
        'createdAt': '2026-06-30T08:15:00.000',
      });

      expect(user.id, 'user_1');
      expect(user.displayName, 'Leonardo Santos Molar');
      expect(user.roleLabel, 'Student');
      expect(user.course, 'BS Information Technology');
      expect(user.dayStreak, 0);
      expect(user.createdAt, DateTime(2026, 6, 30, 8, 15));
    });

    test('missing createdAt does not crash', () {
      final user = UserModel.fromJson({
        'id': 'user_2',
        'email': 'mia@example.com',
      });

      expect(user.createdAt, isNull);
      expect(user.displayName, 'mia@example.com');
    });

    test('profile update json includes editable fields', () {
      final user = const UserModel(
        id: 'user_3',
        email: 'ana@example.com',
        firstName: 'Ana',
        lastName: 'Rivera',
        schoolId: 'UCU-1',
        department: 'Guidance',
        course: 'Master of Arts in Education - all major fields',
        role: 'faculty',
        dayStreak: 7,
      ).toProfileUpdateJson();

      expect(user['name'], 'Ana Rivera');
      expect(user['schoolId'], 'UCU-1');
      expect(user['department'], 'Guidance');
      expect(user['course'], 'Master of Arts in Education - all major fields');
      expect(user['role'], 'faculty');
      expect(user['updatedAt'], isA<String>());
    });

    test('roleLabel maps known categories and falls back to User', () {
      expect(
        const UserModel(
          id: '1',
          email: 'a@example.com',
          role: 'student',
        ).roleLabel,
        'Student',
      );
      expect(
        const UserModel(
          id: '2',
          email: 'b@example.com',
          role: 'faculty',
        ).roleLabel,
        'Teaching',
      );
      expect(
        const UserModel(
          id: '3',
          email: 'c@example.com',
          role: 'staff',
        ).roleLabel,
        'Non-Teaching',
      );
      expect(
        const UserModel(
          id: '4',
          email: 'd@example.com',
          role: 'non-teaching',
        ).roleLabel,
        'Non-Teaching',
      );
      expect(
        const UserModel(
          id: '5',
          email: 'e@example.com',
          role: 'guest',
        ).roleLabel,
        'User',
      );
      expect(
        const UserModel(id: '6', email: 'f@example.com').roleLabel,
        'User',
      );
    });
  });
}
