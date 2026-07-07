class MentalHealthActivitySummary {
  const MentalHealthActivitySummary({
    required this.date,
    required this.moodCheckIns,
    required this.averageMoodLevel,
    required this.mindAidMessages,
    required this.breathingSessions,
    required this.breathingMinutes,
    required this.secretChatPosts,
    required this.secretChatComments,
    required this.secretChatInteractions,
    required this.assessmentCount,
    required this.currentStreak,
    required this.recentActivities,
  });

  final DateTime date;
  final int moodCheckIns;
  final double? averageMoodLevel;
  final int mindAidMessages;
  final int breathingSessions;
  final int breathingMinutes;
  final int secretChatPosts;
  final int secretChatComments;
  final int secretChatInteractions;
  final int assessmentCount;
  final int currentStreak;
  final List<MentalHealthActivityItem> recentActivities;

  int get secretChatEngagementCount =>
      secretChatPosts + secretChatComments + secretChatInteractions;

  int get activeDayCount => totalActions > 0 ? 1 : 0;

  int get totalActions =>
      moodCheckIns +
      mindAidMessages +
      breathingSessions +
      secretChatEngagementCount +
      assessmentCount;

  bool get hasActivity => totalActions > 0;

  String get averageMoodLabel {
    final average = averageMoodLevel;
    if (average == null) return '-';
    return average.toStringAsFixed(1);
  }

  String get dateLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static MentalHealthActivitySummary empty({
    DateTime? date,
    int currentStreak = 0,
  }) {
    return MentalHealthActivitySummary(
      date: date ?? DateTime.now(),
      moodCheckIns: 0,
      averageMoodLevel: null,
      mindAidMessages: 0,
      breathingSessions: 0,
      breathingMinutes: 0,
      secretChatPosts: 0,
      secretChatComments: 0,
      secretChatInteractions: 0,
      assessmentCount: 0,
      currentStreak: currentStreak,
      recentActivities: const [],
    );
  }
}

class MentalHealthActivityItem {
  const MentalHealthActivityItem({
    required this.type,
    required this.label,
    required this.occurredAt,
  });

  final String type;
  final String label;
  final DateTime occurredAt;

  String get timeLabel {
    final hour = occurredAt.hour;
    final minute = occurredAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }
}
