import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Admin entrypoints and JavaScript are not cached across deployments',
    () {
      final config =
          jsonDecode(File('firebase.json').readAsStringSync())
              as Map<String, dynamic>;
      final hosting = config['hosting'] as Map<String, dynamic>;
      final headers = (hosting['headers'] as List).cast<Map<String, dynamic>>();

      for (final source in ['/', '/index.html', '**/*.js']) {
        final rule = headers.singleWhere((item) => item['source'] == source);
        final values = (rule['headers'] as List).cast<Map<String, dynamic>>();
        expect(
          values.singleWhere((item) => item['key'] == 'Cache-Control')['value'],
          contains('no-store'),
        );
      }
    },
  );

  test('Admin portal exposes the injected build identifier', () {
    final source = File(
      'lib/features/admin/screens/admin_portal.dart',
    ).readAsStringSync();
    expect(source, contains("String.fromEnvironment(\n  'ADMIN_BUILD_ID'"));
    expect(source, contains("'Build \$_adminBuildId'"));
  });
}
