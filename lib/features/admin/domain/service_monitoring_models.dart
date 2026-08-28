import 'package:flutter/material.dart';

enum ServiceHealthState { healthy, stale, degraded, unavailable }

class AdminServiceCatalogEntry {
  const AdminServiceCatalogEntry({
    required this.serviceKey,
    required this.displayLabel,
    required this.icon,
  });
  final String serviceKey;
  final String displayLabel;
  final IconData icon;
}

const adminServiceCatalog = <AdminServiceCatalogEntry>[
  AdminServiceCatalogEntry(
    serviceKey: 'quick_assessment',
    displayLabel: 'Quick Assessment',
    icon: Icons.bolt_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'full_assessment',
    displayLabel: 'Full Assessment',
    icon: Icons.assignment_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'appointments',
    displayLabel: 'Appointments',
    icon: Icons.calendar_month_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'mindaid',
    displayLabel: 'MindAid',
    icon: Icons.support_agent_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'log_mood',
    displayLabel: 'Log Mood',
    icon: Icons.mood_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'sleep_quality',
    displayLabel: 'Sleep Quality',
    icon: Icons.bedtime_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'breathing',
    displayLabel: 'Breathing',
    icon: Icons.air_outlined,
  ),
  AdminServiceCatalogEntry(
    serviceKey: 'secret_chat',
    displayLabel: 'Secret Chat',
    icon: Icons.forum_outlined,
  ),
];

class ServiceTrendPoint {
  const ServiceTrendPoint({required this.dateKey, required this.count});
  final String dateKey;
  final int count;
  factory ServiceTrendPoint.fromJson(Map<String, dynamic> json) =>
      ServiceTrendPoint(
        dateKey: json['dateKey']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class AdminServiceMonitoringSummary {
  const AdminServiceMonitoringSummary({
    required this.serviceKey,
    required this.displayLabel,
    required this.activityCount,
    required this.activeUserCount,
    required this.dailyTrend,
    required this.healthState,
    required this.successCount,
    required this.errorCount,
    required this.averageLatencyMs,
    required this.lastSuccessfulActivityAt,
    required this.telemetryFreshness,
    this.turnCount,
    this.fallbackCount,
    this.fallbackRate,
  });
  final String serviceKey;
  final String displayLabel;
  final int activityCount;
  final int activeUserCount;
  final List<ServiceTrendPoint> dailyTrend;
  final ServiceHealthState healthState;
  final int successCount;
  final int errorCount;
  final int averageLatencyMs;
  final DateTime? lastSuccessfulActivityAt;
  final DateTime? telemetryFreshness;
  final int? turnCount;
  final int? fallbackCount;
  final double? fallbackRate;

  factory AdminServiceMonitoringSummary.fromJson(Map<String, dynamic> json) =>
      AdminServiceMonitoringSummary(
        serviceKey: json['serviceKey']?.toString() ?? '',
        displayLabel: json['displayLabel']?.toString() ?? 'Service',
        activityCount: (json['activityCount'] as num?)?.toInt() ?? 0,
        activeUserCount: (json['activeUserCount'] as num?)?.toInt() ?? 0,
        dailyTrend:
            (json['dailyTrend'] is List ? json['dailyTrend'] as List : const [])
                .whereType<Map>()
                .map(
                  (item) => ServiceTrendPoint.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(),
        healthState: ServiceHealthState.values.firstWhere(
          (value) => value.name == json['healthState'],
          orElse: () => ServiceHealthState.unavailable,
        ),
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
        averageLatencyMs: (json['averageLatencyMs'] as num?)?.toInt() ?? 0,
        lastSuccessfulActivityAt: _date(json['lastSuccessfulActivityAt']),
        telemetryFreshness: _date(json['telemetryFreshness']),
        turnCount: (json['turnCount'] as num?)?.toInt(),
        fallbackCount: (json['fallbackCount'] as num?)?.toInt(),
        fallbackRate: (json['fallbackRate'] as num?)?.toDouble(),
      );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

class AdminServiceMonitoringResponse {
  const AdminServiceMonitoringResponse({
    required this.days,
    required this.services,
  });
  final int days;
  final List<AdminServiceMonitoringSummary> services;
  factory AdminServiceMonitoringResponse.fromJson(Map<String, dynamic> json) =>
      AdminServiceMonitoringResponse(
        days: (json['days'] as num?)?.toInt() ?? 7,
        services:
            (json['services'] is List ? json['services'] as List : const [])
                .whereType<Map>()
                .map(
                  (item) => AdminServiceMonitoringSummary.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(),
      );
}
