import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/repositories/auth_repository.dart';

void main() {
  group('AuthRepository.authEmailForSchoolId', () {
    test('normalizes common school id formats', () {
      expect(
        AuthRepository.authEmailForSchoolId('2026-0001'),
        '2026.0001@mindmate.local',
      );
      expect(
        AuthRepository.authEmailForSchoolId(' UCU 2026/0001 '),
        'ucu.2026.0001@mindmate.local',
      );
      expect(
        AuthRepository.authEmailForSchoolId('FAC_001'),
        'fac.001@mindmate.local',
      );
    });

    test('falls back to a safe local part for blank values', () {
      expect(AuthRepository.authEmailForSchoolId(' '), 'user@mindmate.local');
    });
  });
}
