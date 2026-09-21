import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/org_theme_provider.dart';
import '../../../../core/widgets/glass_widgets.dart';

/// Registration screen, restyled to match the glossy Login screen: aurora gradient
/// backdrop + glowing orbs + a floating glass card, all themed from the org's colors.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  bool _loading = false;
  bool _obscurePassword = true;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
          Positioned(top: -50, left: -50, child: GlowOrb(color: theme.accent, size: 200)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
                      ),
                      Text('Create Account', style: TextStyle(color: theme.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GlassField(controller: _nameController, label: 'Full Name', icon: Icons.person_outline_rounded, theme: theme),
                          const SizedBox(height: 14),
                          GlassField(controller: _emailController, label: 'Email', icon: Icons.email_outlined, theme: theme, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          GlassField(controller: _phoneController, label: 'Phone', icon: Icons.phone_outlined, theme: theme, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          GlassField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            theme: theme,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.textSecondary, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: 24),
                          GradientButton(theme: theme, loading: _loading, label: 'Register', onPressed: _loading ? null : _handleRegister),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.login),
                            child: Text('Already have an account? Login', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleRegister() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name, email, and password.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _loading = true);
    final success = await ref.read(mobileAuthProvider.notifier).register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }
}
