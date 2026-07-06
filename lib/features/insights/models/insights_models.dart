import '../../../core/utils/firestore_mapper.dart';
import '../../../models/mood_model.dart';
import '../../../models/report_model.dart';

class InsightsDashboardData {
  const InsightsDashboardData({
    required this.categories,
    required this.sections,
  });

  final List<InsightCategory> categories;
  final List<InsightSection> sections;
}

class InsightCategory {
  const InsightCategory({
    required this.id,
    required this.label,
    required this.icon,
    this.isSelected = false,
  });

  final String id;
  final String label;
  final String icon;
  final bool isSelected;

  factory InsightCategory.fromJson(Map<String, dynamic> json) {
    return InsightCategory(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      icon: (json['icon'] ?? 'mood').toString(),
      isSelected: boolFromFirestore(json['isDefaultSelected']),
    );
  }
}

class InsightMetric {
  const InsightMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final String icon;
}

class InsightCardItem {
  const InsightCardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.imageAsset,
    this.actionRoute,
    this.publishedAt,
    this.contentType,
    this.body,
    this.tags = const [],
    this.source,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String imageAsset;
  final String? actionRoute;
  final DateTime? publishedAt;
  final String? contentType;
  final String? body;
  final List<String> tags;
  final String? source;

  factory InsightCardItem.fromJson(Map<String, dynamic> json) {
    return InsightCardItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      category: (json['categoryLabel'] ?? json['category'] ?? '').toString(),
      imageAsset: (json['imageAsset'] ?? '').toString(),
      actionRoute: _stringOrNull(json['actionRoute']),
      publishedAt: dateTimeFromFirestore(json['publishedAt']),
      contentType: _stringOrNull(json['contentType']),
      body: _stringOrNull(json['body']),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(growable: false),
      source: _stringOrNull(json['source']),
    );
  }
}

class InsightSection {
  const InsightSection({
    required this.id,
    required this.title,
    required this.items,
    this.showSeeAll = true,
  });

  final String id;
  final String title;
  final List<InsightCardItem> items;
  final bool showSeeAll;
}

class InsightMetricsSummary {
  const InsightMetricsSummary({
    required this.checkIns,
    required this.goodDays,
    required this.totalLogs,
  });

  final int checkIns;
  final int goodDays;
  final int totalLogs;

  factory InsightMetricsSummary.from({
    required List<MoodModel> moods,
    ReportModel? report,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final startOfWeek = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    ).subtract(Duration(days: effectiveNow.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final weeklyMoods = moods
        .where((mood) {
          final createdAt = mood.createdAt;
          return !createdAt.isBefore(startOfWeek) &&
              createdAt.isBefore(endOfWeek);
        })
        .toList(growable: false);

    return InsightMetricsSummary(
      checkIns: weeklyMoods.length,
      goodDays: weeklyMoods.where((mood) => mood.level >= 4).length,
      totalLogs: moods.length + (report?.assessmentCount ?? 0),
    );
  }
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
