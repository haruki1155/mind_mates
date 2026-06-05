import 'package:flutter/material.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../routes/route_names.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CustomTextField(
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const CustomTextField(
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Login',
              onPressed: () => Navigator.of(context).pushReplacementNamed(RouteNames.home),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed(RouteNames.forgotPassword),
              child: const Text('Forgot password?'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed(RouteNames.signup),
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
