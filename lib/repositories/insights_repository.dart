import '../features/insights/models/insights_models.dart';

class InsightsRepository {
  Future<InsightsDashboardData> fetchInsights() async {
    return const InsightsDashboardData(
      categories: [
        InsightCategory(
          id: 'mood_tracking',
          label: 'Mood tracking',
          icon: 'mood',
        ),
        InsightCategory(
          id: 'stress_relief',
          label: 'Stress relief',
          icon: 'stress',
        ),
        InsightCategory(
          id: 'better_sleep',
          label: 'Better sleep',
          icon: 'sleep',
          isSelected: true,
        ),
        InsightCategory(
          id: 'manage_anxiety',
          label: 'Manage anxiety',
          icon: 'anxiety',
        ),
      ],
      sections: [
        InsightSection(
          id: 'patterns',
          title: 'Your mental health patterns',
          items: [
            InsightCardItem(
              id: 'your_data',
              title: 'Understanding your mood patterns',
              subtitle: 'Learn how to identify triggers',
              category: 'Your data',
              imageAsset: '',
            ),
            InsightCardItem(
              id: 'trending',
              title: 'Weekly emotional check-in',
              subtitle: 'See how your records can become patterns',
              category: 'Trending',
              imageAsset: '',
            ),
          ],
        ),
        InsightSection(
          id: 'wellbeing_101',
          title: 'Mental Wellbeing 101',
          items: [
            InsightCardItem(
              id: 'burnout_signs',
              title: '5 signs of emotional burnout',
              subtitle: 'Recognize the warning signs early',
              category: 'Wellbeing',
              imageAsset: 'assets/images/INSIGHTS/Frame 13.png',
            ),
            InsightCardItem(
              id: 'mindfulness',
              title: 'Quick mindfulness exercise',
              subtitle: '3-minute mental health pause',
              category: 'Mindfulness',
              imageAsset: 'assets/images/INSIGHTS/Frame 14.png',
            ),
          ],
        ),
        InsightSection(
          id: 'latest',
          title: 'The latest',
          items: [
            InsightCardItem(
              id: 'exam_anxiety',
              title: 'Feeling anxious about exams?',
              subtitle: 'Techniques that actually work',
              category: 'Academic',
              imageAsset: 'assets/images/INSIGHTS/Frame 15.png',
            ),
            InsightCardItem(
              id: 'journaling',
              title: 'The power of journaling',
              subtitle: 'Write your way to wellness',
              category: 'Self-care',
              imageAsset: 'assets/images/INSIGHTS/Frame 16.png',
            ),
          ],
        ),
        InsightSection(
          id: 'recommended',
          title: 'Recommended for you',
          items: [
            InsightCardItem(
              id: 'talk_about_mental_health',
              title: 'How to talk about mental health',
              subtitle: 'Learn how to identify triggers',
              category: 'Social',
              imageAsset: 'assets/images/INSIGHTS/Group 1383.png',
            ),
            InsightCardItem(
              id: 'sleep_and_mood',
              title: 'Sleep and mental wellbeing',
              subtitle: 'See how rest supports mood',
              category: 'Sleep',
              imageAsset: 'assets/images/INSIGHTS/Group 1463.png',
            ),
          ],
        ),
      ],
    );
  }
}
