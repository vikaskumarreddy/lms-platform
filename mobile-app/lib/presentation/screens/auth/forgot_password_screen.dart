import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/widgets/common_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _sent = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Reset Password'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 64, color: Color(0xFFEAB308)),
            const SizedBox(height: 16),
            const Text('Enter your email to receive reset instructions'),
            const SizedBox(height: 16),
            TextField(decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => setState(() => _sent = true),
              child: const Text('Send Reset Link'),
            )),
            if (_sent) ...[
              const SizedBox(height: 16),
              const Text('Check your email for reset instructions', style: TextStyle(color: Colors.green)),
            ],
            TextButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Back to Login')),
          ],
        ),
      ),
    );
  }
}