import 'package:flutter/material.dart';

import 'app_pages.dart';

class RouteGenerator {
  const RouteGenerator._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final builder = AppPages.routes[settings.name];

    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    return MaterialPageRoute(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('Page not found'))),
      settings: settings,
    );
  }
}
