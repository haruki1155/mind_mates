import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/report_model.dart';

void main() {
  group('ReportModel', () {
    test('parses generated mental health summary fields', () {
      final report = ReportModel.fromJson({
        'id': 'report_1',
        'userId': 'user_1',
        'title': 'Mental Health Summary',
        'description': 'Latest assessment shows moderate concern.',
        'generatedAt': '2026-07-03T10:00:00.000',
        'assessmentCount': 2,
        'mindAidMessageCount': 4,
        'activeDayCount': 3,
        'currentStreak': 5,
        'breathingSessionCount': 3,
        'mindfulBreathingMinutes': 12,
        'latestAssessmentStatus': 'moderate',
        'latestAssessmentSource': 'quickAssessment',
        'mentalStatusSignal': 'watchful',
        'topConcernAreas': ['Sleep and Rest', 'Academic Stress'],
        'recommendedNextActions': ['Continue daily check-ins'],
        'hasEnoughData': true,
      });

      expect(report.mindAidMessageCount, 4);
      expect(report.activeDayCount, 3);
      expect(report.currentStreak, 5);
      expect(report.breathingSessionCount, 3);
      expect(report.mindfulBreathingMinutes, 12);
      expect(report.latestAssessmentStatus, 'moderate');
      expect(report.latestAssessmentSource, 'quickAssessment');
      expect(report.mentalStatusSignal, 'watchful');
      expect(report.topConcernAreas, ['Sleep and Rest', 'Academic Stress']);
      expect(report.hasEnoughData, isTrue);
    });
  });
}
