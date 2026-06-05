import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName)),
      body: const SafeArea(
        child: Center(
          child: Text('MindMate home'),
        ),
      ),
    );
  }
}
