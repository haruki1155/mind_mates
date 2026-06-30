import 'package:flutter/material.dart';

class HomeDashboardData {
  const HomeDashboardData({
    required this.headerTitle,
    required this.user,
    required this.days,
    required this.assessment,
    required this.services,
    required this.insights,
    required this.mentalHealthCheck,
    required this.resources,
    required this.toolkitItems,
    this.streak,
    this.affirmation,
    this.activityDates = const [],
  });

  final String headerTitle;
  final HomeUserData user;
  final List<HomeDayData> days;
  final HomeAssessmentPromptData assessment;
  final HomeStreakData? streak;
  final List<HomeServiceData> services;
  final List<HomeInsightData> insights;
  final HomeAffirmationData? affirmation;
  final HomeMentalHealthCheckData mentalHealthCheck;
  final List<HomeResourceData> resources;
  final List<HomeToolkitData> toolkitItems;
  final List<DateTime> activityDates;

  factory HomeDashboardData.mock() {
    final today = DateTime.now();

    return HomeDashboardData(
      headerTitle: _formatHeaderTitle(today),
      user: const HomeUserData(displayName: '', role: 'Choose your category'),
      days: _weekAround(today),
      assessment: const HomeAssessmentPromptData(
        title: 'Time for Your Stress Assessment',
        description:
            'Availability will sync with your account when backend tracking is connected.',
        actionLabel: 'Start Assessment',
        maxAttemptsPerMonth: 2,
      ),
      services: const [
        HomeServiceData(
          title: 'Testing Services',
          subtitle: 'Psychological assessment',
          icon: Icons.psychology_alt_outlined,
          colors: [Color(0xFFB8C8FF), Color(0xFF94A6DB)],
        ),
        HomeServiceData(
          title: 'Counseling Services',
          subtitle: 'Appoint Now',
          icon: Icons.groups_2_outlined,
          colors: [Color(0xFFF2A5D9), Color(0xFF7B3E78)],
        ),
        HomeServiceData(
          title: 'Individual Inventory',
          subtitle: 'Your profile & data',
          icon: Icons.assignment_outlined,
          colors: [Color(0xFFFF9987), Color(0xFFFF624C)],
        ),
        HomeServiceData(
          title: 'Information Services',
          subtitle: 'Mental health resources',
          icon: Icons.menu_book_outlined,
          colors: [Color(0xFF72E4B8), Color(0xFF008A61)],
        ),
      ],
      insights: const [
        HomeInsightData.action(title: 'Log your mood', icon: Icons.add),
        HomeInsightData.photo(
          title: 'Time for a wellness check?',
          subtitle: 'Check your mood',
          imageName: 'Rectangle 254.png',
        ),
        HomeInsightData.photo(
          title: 'Mindful breathing',
          subtitle: '5 min session',
          imageName: 'Rectangle 255.png',
        ),
      ],
      mentalHealthCheck: const HomeMentalHealthCheckData(
        title: 'How are you today',
        description:
            'Take our comprehensive mental health check to get personalized insights and recommendations.',
        durationLabel: 'Takes ~5 minutes',
        actionLabel: 'Take Assessment',
      ),
      resources: const [
        HomeResourceData(
          title: 'Talk to AI companion',
          subtitle: 'Get instant support anytime',
          icon: Icons.support_agent_outlined,
          color: Color(0xFFD9AF6A),
        ),
        HomeResourceData(
          title: 'View your insights',
          subtitle: 'Understand your emotional patterns',
          icon: Icons.insights_outlined,
          color: Color(0xFFD7AFC1),
          borderColor: Color(0xFFFF2FA2),
        ),
        HomeResourceData(
          title: 'Mental Wellbeing 101',
          subtitle: 'Essential mental health knowledge',
          icon: Icons.school_outlined,
          color: Color(0xFFFF9C97),
          borderColor: Color(0xFFFF4C4C),
        ),
        HomeResourceData(
          title: 'Latest News & Research',
          subtitle: 'Updates and mental health insights',
          icon: Icons.science_outlined,
          color: Color(0xFFD0C6C8),
        ),
        HomeResourceData(
          title: 'Recommended for You',
          subtitle: 'Personalized mental health resources',
          icon: Icons.thumb_up_alt_outlined,
          color: Color(0xFFB4C6FF),
        ),
      ],
      toolkitItems: const [
        HomeToolkitData(
          title: 'Breathing exercise',
          subtitle: '5 min guided session',
          imageName: 'Breathing exercise 5 min guided session.png',
          colors: [Color(0xFF6483F4), Color(0xFF5570C8)],
        ),
        HomeToolkitData(
          title: 'Facial Recognition',
          subtitle: 'Capturing your emotion',
          imageName: 'Facial Recognition.png',
          colors: [Color(0xFFFFB2D7), Color(0xFF8A3E82)],
        ),
      ],
    );
  }

  static String _formatHeaderTitle(DateTime date) {
    return '${_monthName(date.month)} ${date.day}';
  }

  static List<HomeDayData> _weekAround(
    DateTime date, {
    List<DateTime> activityDates = const [],
  }) {
    final today = DateTime(date.year, date.month, date.day);
    return List.generate(7, (index) {
      final day = today.add(Duration(days: index - 3));
      return HomeDayData(
        label: _weekdayLabel(day.weekday),
        date: '${day.day}',
        dateValue: day,
        isToday: _isSameDay(day, today),
        isPast: day.isBefore(today),
        hasActivity:
            _isSameDay(day, today) ||
            activityDates.any((activityDate) => _isSameDay(day, activityDate)),
      );
    });
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  static String _weekdayLabel(int weekday) {
    const labels = ['M', 'T', 'W', 'Th', 'F', 'Sat', 'S'];
    return labels[weekday - 1];
  }
}

class HomeUserData {
  const HomeUserData({required this.displayName, required this.role});

  final String displayName;
  final String role;
}

class HomeDayData {
  const HomeDayData({
    required this.label,
    required this.date,
    this.dateValue,
    this.isToday = false,
    this.hasActivity = false,
    this.isPast = false,
  });

  final String label;
  final String date;
  final DateTime? dateValue;
  final bool isToday;
  final bool hasActivity;
  final bool isPast;
}

class HomeAssessmentPromptData {
  const HomeAssessmentPromptData({
    required this.title,
    required this.description,
    required this.actionLabel,
    this.attemptsUsedThisMonth,
    this.maxAttemptsPerMonth,
    this.nextAvailableAt,
    this.canTakeAssessment,
  });

  final String title;
  final String description;
  final String actionLabel;
  final int? attemptsUsedThisMonth;
  final int? maxAttemptsPerMonth;
  final DateTime? nextAvailableAt;
  final bool? canTakeAssessment;
}

class HomeStreakData {
  const HomeStreakData({
    required this.title,
    required this.days,
    required this.description,
    required this.linkLabel,
    this.lastActiveAt,
    this.missedDays,
    this.wasReset,
  });

  final String title;
  final int days;
  final String description;
  final String linkLabel;
  final DateTime? lastActiveAt;
  final int? missedDays;
  final bool? wasReset;
}

class HomeServiceData {
  const HomeServiceData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}

class HomeInsightData {
  const HomeInsightData._({
    required this.title,
    this.subtitle,
    this.imageName,
    this.icon,
  });

  const HomeInsightData.action({required String title, required IconData icon})
    : this._(title: title, icon: icon);

  const HomeInsightData.photo({
    required String title,
    required String subtitle,
    required String imageName,
  }) : this._(title: title, subtitle: subtitle, imageName: imageName);

  final String title;
  final String? subtitle;
  final String? imageName;
  final IconData? icon;

  bool get isAction => icon != null;
}

class HomeAffirmationData {
  const HomeAffirmationData({
    required this.title,
    required this.quote,
    this.author,
    this.activeDate,
  });

  final String title;
  final String quote;
  final String? author;
  final DateTime? activeDate;
}

class HomeMentalHealthCheckData {
  const HomeMentalHealthCheckData({
    required this.title,
    required this.description,
    required this.durationLabel,
    required this.actionLabel,
  });

  final String title;
  final String description;
  final String durationLabel;
  final String actionLabel;
}

class HomeResourceData {
  const HomeResourceData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.borderColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color? borderColor;
}

class HomeToolkitData {
  const HomeToolkitData({
    required this.title,
    required this.subtitle,
    required this.imageName,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String imageName;
  final List<Color> colors;
}
