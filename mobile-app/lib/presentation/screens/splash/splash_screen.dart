import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the persisted-login check as early as possible.
    ref.read(mobileAuthProvider.notifier);
    Future.delayed(const Duration(milliseconds: 1600), _navigate);
  }

  /// Route to Home if a valid session is already stored, otherwise to Landing.
  Future<void> _navigate() async {
    if (!mounted) return;
    // If the async check hasn't finished yet, wait briefly for it.
    var state = ref.read(mobileAuthProvider);
    final started = DateTime.now();
    while (state.isLoading && DateTime.now().difference(started).inMilliseconds < 4000) {
      await Future.delayed(const Duration(milliseconds: 100));
      state = ref.read(mobileAuthProvider);
    }
    if (!mounted) return;
    if (!state.isLoggedIn) {
      context.go(AppRoutes.login);
      return;
    }
    // Persisted sessions for ONLINE-payment students that are still unpaid are
    // sent to the payment screen too, not just fresh logins.
    final user = state.user;
    final needsPayment = user != null &&
        user.role == 'STUDENT' &&
        user.paymentMethod == 'ONLINE' &&
        user.paymentStatus != 'COMPLETED' &&
        user.planId != null;
    context.go(needsPayment ? AppRoutes.paymentFor(user.planId!) : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 80, color: Color(0xFFEAB308)),
            const SizedBox(height: 16),
            Text('Axisora Forge Academy', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Empowering Your Future', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}