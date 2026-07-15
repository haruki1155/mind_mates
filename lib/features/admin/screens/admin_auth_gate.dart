import 'package:flutter/material.dart';

import '../../../repositories/admin_portal_repository.dart';
import 'admin_portal.dart';
import 'admin_change_password_screen.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});
  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  final repository = AdminPortalRepository();
  late final Future<bool> session = repository.restoreSession();
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data == true
          ? repository.mustChangePassword
                ? AdminChangePasswordScreen(repository: repository)
                : AdminPortalHome(repository: repository)
          : AdminLoginScreen(repository: repository);
    },
  );
}
