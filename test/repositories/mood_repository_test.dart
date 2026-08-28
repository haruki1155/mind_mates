import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/repositories/mood_repository.dart';

void main() {
  group('MoodRepository date handling', () {
    test('uses Asia/Manila date at the UTC boundary', () {
      expect(
        MoodRepository.dateKeyFor(DateTime.utc(2026, 7, 7, 15, 59)),
        '20260707',
      );
      expect(
        MoodRepository.dateKeyFor(DateTime.utc(2026, 7, 7, 16)),
        '20260708',
      );
    });

    test('builds daily document ids from the Manila date', () {
      expect(
        MoodRepository.dailyDocumentId('user_1', DateTime.utc(2026, 7, 7, 16)),
        'daily_user_1_20260708',
      );
    });
  });
}
