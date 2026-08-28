import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/mood_model.dart';

void main() {
  group('MoodModel Firestore compatibility', () {
    test('reads Firestore timestamps and preserves all persisted fields', () {
      final createdAt = DateTime(2026, 7, 18, 9, 30);

      final mood = MoodModel.fromJson({
        'level': 4,
        'label': 'Good',
        'note': 'A manageable day.',
        'dateKey': '20260718',
        'timezone': 'Asia/Manila',
        'userId': 'user_1',
        'createdAt': Timestamp.fromDate(createdAt),
      }, id: 'mood_1');

      expect(mood.id, 'mood_1');
      expect(mood.userId, 'user_1');
      expect(mood.level, 4);
      expect(mood.label, 'Good');
      expect(mood.note, 'A manageable day.');
      expect(mood.dateKey, '20260718');
      expect(mood.timezone, 'Asia/Manila');
      expect(mood.createdAt, createdAt);
    });

    test('reads legacy ISO timestamps and numeric strings', () {
      final mood = MoodModel.fromJson({
        'id': 'legacy_mood',
        'level': '2',
        'createdAt': '2026-07-17T08:15:00.000',
      });

      expect(mood.id, 'legacy_mood');
      expect(mood.level, 2);
      expect(mood.createdAt, DateTime(2026, 7, 17, 8, 15));
      expect(mood.userId, isNull);
      expect(mood.note, isNull);
    });

    test(
      'serializes optional fields with stable Firestore-compatible values',
      () {
        final createdAt = DateTime(2026, 7, 16, 14);
        final mood = MoodModel(
          id: 'mood_3',
          level: 5,
          createdAt: createdAt,
          userId: 'user_3',
        );

        final json = mood.toJson();

        expect(json['userId'], 'user_3');
        expect(json['level'], 5);
        expect(json['label'], '');
        expect(json['note'], '');
        expect(json['dateKey'], '');
        expect(json['timezone'], '');
        expect(json['createdAt'], createdAt);
      },
    );
  });
}
