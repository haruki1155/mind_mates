import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/app.dart';
import 'package:mind_mates/core/theme/app_theme.dart';

void main() {
  testWidgets('MindMate stays light when the device is in dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    late MaterialApp configuredApp;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          configuredApp = const MindMateApp().build(context) as MaterialApp;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(configuredApp.themeMode, ThemeMode.light);
    expect(configuredApp.theme?.brightness, Brightness.light);
    expect(configuredApp.darkTheme?.brightness, Brightness.dark);
  });

  test('light app bars use dark system icons', () {
    final overlay = AppTheme.light.appBarTheme.systemOverlayStyle;

    expect(overlay, isNotNull);
    expect(overlay!.statusBarIconBrightness, Brightness.dark);
    expect(overlay.statusBarBrightness, Brightness.light);
    expect(overlay.systemNavigationBarIconBrightness, Brightness.dark);
    expect(overlay.systemNavigationBarColor, const Color(0xFFFFFFFF));
    expect(overlay, isA<SystemUiOverlayStyle>());
  });
}
