import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/org_theme_provider.dart';
import '../../../../core/widgets/glass_widgets.dart';

/// A premium, glossy login screen: an aurora gradient backdrop (derived from the
/// org's theme) with soft glowing orbs, a floating glass card for the form, and a
/// gradient CTA button — replacing the old plain white form. No hardcoded brand
/// colors: everything reads from `orgThemeProvider`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                  stops: const [0.0, 0.45, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(top: -60, right: -40, child: GlowOrb(color: theme.accent, size: 220)),
          Positioned(top: 160, left: -70, child: GlowOrb(color: theme.primary, size: 180)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(child: LogoBadge(theme: theme)),
                  const SizedBox(height: 20),
                  Text(
                    'Master Skills, Crack Placements,\nBuild Your Future',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Welcome back', style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Sign in to continue your journey', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 24),
                        GlassField(controller: _emailController, label: 'Email', icon: Icons.email_outlined, theme: theme, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        GlassField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          theme: theme,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _handleLogin(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.textSecondary, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(theme: theme, loading: _loading, label: 'Login', onPressed: _loading ? null : _handleLogin),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.register),
                          child: Text("Don't have an account? Register", style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.forgotPassword),
                          child: Text('Forgot Password?', style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    if (!mounted) return;
    if (success) {
      final user = ref.read(mobileAuthProvider).user;
      final needsPayment = user != null &&
          user.role == 'STUDENT' &&
          user.paymentMethod == 'ONLINE' &&
          user.paymentStatus != 'COMPLETED' &&
          user.planId != null;
      context.go(needsPayment ? AppRoutes.paymentFor(user!.planId!) : AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Check your credentials.'), backgroundColor: Colors.red),
      );
    }
  }
}
