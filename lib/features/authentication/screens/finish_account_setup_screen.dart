import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../routes/route_names.dart';

class FinishAccountSetupScreen extends StatefulWidget {
  const FinishAccountSetupScreen({super.key});

  @override
  State<FinishAccountSetupScreen> createState() =>
      _FinishAccountSetupScreenState();
}

class _FinishAccountSetupScreenState extends State<FinishAccountSetupScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final auth = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final uid = await auth.resolveAuthenticatedUserId();
    if (uid != null && auth.hasPendingProfileSetup) {
      await auth.retryPendingProfileSetup();
      await userProvider.loadProfile(uid);
    } else if (uid != null) {
      await userProvider.loadProfile(uid);
    }
    if (!mounted) return;
    setState(() => _retrying = false);
    if (userProvider.user != null) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.assessmentStatus, (route) => false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finish account setup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Your sign-in account is ready, but your MindMate profile still needs to finish setting up.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(_retrying ? 'Retrying…' : 'Retry setup'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(RouteNames.finishAccountSetupForm),
                  child: const Text('Enter profile details'),
                ),
                TextButton(onPressed: _signOut, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
