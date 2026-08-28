import 'package:flutter/material.dart';

import '../../../services/auth/recovery_service.dart';
import '../../../services/firebase/firebase_error_message.dart';

String tokenFromWebLocation() {
  final direct = Uri.base.queryParameters['token'];
  if (direct != null) return direct;
  final fragment = Uri.base.fragment;
  final question = fragment.indexOf('?');
  if (question < 0) return '';
  return Uri.tryParse(fragment.substring(question))?.queryParameters['token'] ??
      '';
}

class RecoveryEmailScreen extends StatefulWidget {
  const RecoveryEmailScreen({
    super.key,
    this.confirmLink = false,
    this.recoveryService,
  });

  final bool confirmLink;
  final RecoveryService? recoveryService;
  @override
  State<RecoveryEmailScreen> createState() => _RecoveryEmailScreenState();
}

class _RecoveryEmailScreenState extends State<RecoveryEmailScreen> {
  final _email = TextEditingController();
  bool _working = false;
  String? _message;

  RecoveryService get _recoveryService =>
      widget.recoveryService ?? FirebaseRecoveryService();

  @override
  void initState() {
    super.initState();
    if (widget.confirmLink) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_working || _email.text.trim().isEmpty) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await _recoveryService.requestRecoveryEmailVerification(
        _email.text.trim(),
      );
      if (mounted) {
        setState(
          () => _message =
              'Verification email sent. Open the link to confirm this address.',
        );
      }
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Configuring recovery email failed.',
      );
      if (mounted) {
        setState(
          () => _message = FirebaseErrorMessage.describe(
            error,
            fallback: 'Unable to configure recovery email.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirm() async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await _recoveryService.confirmRecoveryEmailVerification(
        tokenFromWebLocation(),
      );
      if (mounted) {
        setState(() => _message = 'Recovery email verified successfully.');
      }
    } catch (error, stackTrace) {
      FirebaseErrorMessage.log(
        error,
        stackTrace,
        area: 'Verifying recovery email failed.',
      );
      if (mounted) {
        setState(
          () => _message = FirebaseErrorMessage.describe(
            error,
            fallback: 'Unable to verify this recovery email.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.confirmLink ? 'Verify recovery email' : 'Recovery email',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!widget.confirmLink) ...[
            const Text(
              'Use a personal email you can access. It is stored privately and used only for account recovery.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Personal recovery email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _working ? null : _request,
              child: const Text('Send verification email'),
            ),
          ] else if (_working)
            const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(_message!, textAlign: TextAlign.center),
            ),
        ],
      ),
    ),
  );
}
