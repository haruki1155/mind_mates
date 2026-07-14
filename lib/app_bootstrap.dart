import 'package:flutter/widgets.dart';

import 'admin_main.dart';

Widget selectMindMateRoot({required bool isWeb, required Widget mobileApp}) {
  return isWeb ? const MindMateAdminApp() : mobileApp;
}
