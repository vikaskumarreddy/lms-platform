import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Onboarding'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 64, color: Color(0xFFEAB308)),
            const SizedBox(height: 16),
            Text('OnboardingScreen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Coming Soon', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

