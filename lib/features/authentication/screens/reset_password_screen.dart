import 'package:flutter/material.dart';

import '../../../routes/route_names.dart';
import '../../../services/auth/recovery_service.dart';
import '../../../services/firebase/firebase_error_message.dart';
import 'recovery_email_screen.dart';
import '../password_policy.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.recoveryService});

  final RecoveryService? recoveryService;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _passwordObscured = true;
  bool _confirmationObscured = true;
  String get _token => tokenFromWebLocation();

  RecoveryService get _recoveryService =>
      widget.recoveryService ?? FirebaseRecoveryService();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_saving) return;
    if (_token.isEmpty ||
        validateNewPassword(_password.text) != null ||
        _password.text.length > passwordMaximumLength ||
        _password.text != _confirmation.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use a valid reset link, at least 8 characters, and matching passwords.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _recoveryService.confirmPasswordRecovery(
        token: _token,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.login, (_) => false);
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Resetting password failed.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FirebaseErrorMessage.describe(
              error,
              fallback: 'Unable to reset password.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _password,
            obscureText: _passwordObscured,
            decoration: InputDecoration(
              labelText: 'New password',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _passwordObscured ? 'Show password' : 'Hide password',
                onPressed: () =>
                    setState(() => _passwordObscured = !_passwordObscured),
                icon: Icon(
                  _passwordObscured ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmation,
            obscureText: _confirmationObscured,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _confirmationObscured
                    ? 'Show password'
                    : 'Hide password',
                onPressed: () => setState(
                  () => _confirmationObscured = !_confirmationObscured,
                ),
                icon: Icon(
                  _confirmationObscured
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _reset,
            child: const Text('Reset password'),
          ),
        ],
      ),
    ),
  );
}
