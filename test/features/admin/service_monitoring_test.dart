import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/admin/domain/service_monitoring_models.dart';
import 'package:mind_mates/features/admin/screens/service_monitoring_page.dart';
import 'package:mind_mates/repositories/admin_portal_repository.dart';

class _MonitoringRepository extends AdminPortalRepository {
  @override
  Future<AdminServiceMonitoringResponse> getAdminServiceMonitoring({
    int days = 7,
    String? serviceKey,
  }) async => AdminServiceMonitoringResponse(
    days: days,
    services: adminServiceCatalog
        .map(
          (service) => AdminServiceMonitoringSummary(
            serviceKey: service.serviceKey,
            displayLabel: service.displayLabel,
            activityCount: 0,
            activeUserCount: 0,
            dailyTrend: const [],
            healthState: ServiceHealthState.healthy,
            successCount: 1,
            errorCount: 0,
            averageLatencyMs: 10,
            lastSuccessfulActivityAt: DateTime.now(),
            telemetryFreshness: DateTime.now(),
          ),
        )
        .toList(),
  );
}

void main() {
  test(
    'service catalog contains exactly eight cards and excludes app opens',
    () {
      expect(adminServiceCatalog, hasLength(8));
      expect(
        adminServiceCatalog.any((item) => item.serviceKey == 'app_open'),
        isFalse,
      );
      expect(
        adminServiceCatalog.map((item) => item.serviceKey),
        contains('sleep_quality'),
      );
    },
  );

  testWidgets(
    'service monitoring renders all service cards and range controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceMonitoringPage(repository: _MonitoringRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Service Monitoring'), findsOneWidget);
      expect(find.text('Quick Assessment'), findsOneWidget);
      expect(find.text('Sleep Quality'), findsOneWidget);
      expect(find.text('Secret Chat'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('No monitoring data'), findsNothing);
    },
  );

  testWidgets('service monitoring supports narrow layouts without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceMonitoringPage(repository: _MonitoringRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
