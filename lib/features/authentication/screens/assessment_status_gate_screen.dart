import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../routes/route_names.dart';
import '../../../services/firebase/firebase_error_message.dart';
import '../auth_flow_routes.dart';

enum _GateStage { signedIn, profile, assessment }

class AssessmentStatusGateScreen extends StatefulWidget {
  const AssessmentStatusGateScreen({super.key});

  @override
  State<AssessmentStatusGateScreen> createState() =>
      _AssessmentStatusGateScreenState();
}

class _AssessmentStatusGateScreenState
    extends State<AssessmentStatusGateScreen> {
  bool _checking = false;
  String? _error;
  _GateStage _stage = _GateStage.signedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
      _stage = _GateStage.signedIn;
    });
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final assessmentProvider = context.read<AssessmentProvider>();
    try {
      final userId = await authProvider.resolveAuthenticatedUserId();
      if (userId == null || userId.isEmpty) {
        _replace(RouteNames.login);
        return;
      }
      setState(() => _stage = _GateStage.profile);
      await userProvider.loadProfile(userId);
      if (userProvider.user == null) {
        if (userProvider.errorMessage != null) {
          throw StateError(userProvider.errorMessage!);
        }
        _replace(RouteNames.finishAccountSetup);
        return;
      }
      setState(() => _stage = _GateStage.assessment);
      final completed = await assessmentProvider
          .ensureQuickAssessmentCompletion(userId)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final state = resolveAccountState(
        isAuthenticated: true,
        profile: userProvider.user,
        assessmentCompleted: completed,
        onboardingComplete: completed,
      );
      _replace(destinationForAccountState(state));
    } on TimeoutException catch (error, stackTrace) {
      _showFailure(
        'We could not confirm your assessment status yet. Your account is safe; please try again.',
        error,
        stackTrace,
      );
    } catch (error, stackTrace) {
      final code = FirebaseErrorMessage.codeOf(error);
      final retryable =
          FirebaseErrorMessage.isNetworkFailure(error) ||
          code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'internal';
      _showFailure(
        retryable
            ? 'The connection is taking longer than expected. Please try again.'
            : code == 'unauthenticated'
            ? 'Your sign-in session has expired. Please sign in again.'
            : 'We could not verify your account right now. Please try again later.',
        error,
        stackTrace,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showFailure(String message, Object error, StackTrace stackTrace) {
    FirebaseErrorMessage.log(
      error,
      stackTrace,
      area: 'Assessment status verification failed.',
    );
    if (mounted) setState(() => _error = message);
  }

  void _replace(String route) {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) _replace(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.spa_outlined, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    hasError ? 'We need a moment' : 'Preparing MindMate',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error ??
                        (_stage == _GateStage.profile
                            ? 'Checking your profile…'
                            : 'Checking assessment status…'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_checking) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 18),
                    const _StageRow(label: 'Signed in', complete: true),
                    _StageRow(
                      label: 'Profile ready',
                      complete: _stage == _GateStage.assessment,
                      active: _stage == _GateStage.profile,
                    ),
                    _StageRow(
                      label: 'Assessment status checked',
                      active: _stage == _GateStage.assessment,
                    ),
                  ],
                  if (hasError) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _checking ? null : _check,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry status check'),
                    ),
                    TextButton(
                      onPressed: _checking ? null : _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    this.complete = false,
    this.active = false,
  });
  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final icon = complete
        ? const Icon(Icons.check_circle, color: Colors.green)
        : active
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.radio_button_unchecked, color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [icon, const SizedBox(width: 10), Text(label)]),
    );
  }
}
