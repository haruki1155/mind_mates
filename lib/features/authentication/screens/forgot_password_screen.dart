import 'package:flutter/material.dart';

import '../../../services/auth/recovery_service.dart';
import '../../../services/firebase/firebase_error_message.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.recoveryService});

  final RecoveryService? recoveryService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _schoolId = TextEditingController();
  bool _sending = false;

  RecoveryService get _recoveryService =>
      widget.recoveryService ?? FirebaseRecoveryService();

  @override
  void dispose() {
    _schoolId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _schoolId.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _recoveryService.requestPasswordRecovery(_schoolId.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this account has a verified recovery email, reset instructions have been sent.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Requesting password recovery failed.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FirebaseErrorMessage.describe(
              error,
              fallback: 'Unable to request password recovery.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot password')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Enter your School ID. For privacy, the result is the same whether or not an account exists.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _schoolId,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'School ID',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send reset instructions'),
          ),
        ],
      ),
    ),
  );
}
