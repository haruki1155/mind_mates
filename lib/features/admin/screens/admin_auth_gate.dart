import 'package:flutter/material.dart';

import '../../../repositories/admin_portal_repository.dart';
import 'admin_portal.dart';

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
          ? AdminPortalHome(repository: repository)
          : AdminLoginScreen(repository: repository);
    },
  );
}
