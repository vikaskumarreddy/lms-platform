import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/widgets/common_header.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Create Account'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 16),
              TextField(decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email))),
              const SizedBox(height: 16),
              TextField(decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone))),
              const SizedBox(height: 16),
              TextField(decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)), obscureText: true),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { context.go(AppRoutes.home); }, child: const Text('Register'))),
              TextButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Already have an account? Login')),
            ],
          ),
        ),
      ),
    );
  }
}