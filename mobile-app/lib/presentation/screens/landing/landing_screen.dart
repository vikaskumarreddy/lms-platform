import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/widgets/app_logo.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 80),
              const SizedBox(height: 24),
              //Text('Axisora Forge Academy', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
              //const SizedBox(height: 12),
              Text('Master Skills, Crack Placements, Build Your Future', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 48),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Login'))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => context.go(AppRoutes.register), child: const Text('Create Account'))),
              const SizedBox(height: 24),
              //TextButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Skip for now')),
            ],
          ),
        ),
      ),
    );
  }
}