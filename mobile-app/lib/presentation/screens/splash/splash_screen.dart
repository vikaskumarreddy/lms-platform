import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/org_theme_provider.dart';
import '../../../core/widgets/glass_widgets.dart';

/// Splash screen, restyled with the same aurora-gradient + glowing-orb + glossy
/// badge look as Login. Reads the *cached* org theme (from the last session on
/// this device) so returning users see their tenant's colors immediately, before
/// the network call in [MobileAuthNotifier] even resolves.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(mobileAuthProvider.notifier);
    Future.delayed(const Duration(milliseconds: 1600), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
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
    final user = state.user;
    final needsPayment = user != null &&
        user.role == 'STUDENT' &&
        (user.paymentRequired ||
            (user.paymentMethod == 'ONLINE' &&
             user.paymentStatus != 'COMPLETED'));
    context.go(needsPayment ? AppRoutes.paymentFor(user.planId ?? 0) : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(orgThemeProvider);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [...theme.primaryGradient, theme.background],
                  stops: const [0.0, 0.6, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(top: -60, right: -50, child: GlowOrb(color: theme.accent, size: 220)),
          Positioned(bottom: 80, left: -60, child: GlowOrb(color: theme.primary, size: 200)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LogoBadge(theme: theme, size: 96),
                const SizedBox(height: 20),
                Text(
                  'Welcome',
                  style: TextStyle(color: theme.onPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Empowering Your Future', style: TextStyle(color: theme.onPrimary.withOpacity(0.75), fontSize: 14)),
                const SizedBox(height: 28),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
