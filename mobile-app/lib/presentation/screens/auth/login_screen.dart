import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/widgets/common_header.dart';
import '../../../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  final _emailController = TextEditingController(text: 'student@axisora.com');
  final _passwordController = TextEditingController(text: 'student123');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Login'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleLogin,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go(AppRoutes.register), child: const Text("Don't have an account? Register")),
            TextButton(onPressed: () => context.go(AppRoutes.forgotPassword), child: const Text('Forgot Password?')),
          ],
        ),
      ),
    );
  }

  void _handleLogin() async {
    setState(() => _loading = true);
    final success = await ref.read(mobileAuthProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    setState(() => _loading = false);
    if (success) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Check your credentials.'), backgroundColor: Colors.red),
      );
    }
  }
}
