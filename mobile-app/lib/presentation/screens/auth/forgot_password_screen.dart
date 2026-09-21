import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/providers/org_theme_provider.dart';
import '../../../../core/widgets/glass_widgets.dart';

/// Password-reset screen, restyled to match Login/Register's glossy glass look.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  bool _sent = false;
  final _emailController = TextEditingController();

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
          Positioned(top: -40, right: -50, child: GlowOrb(color: theme.accent, size: 190)),
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
                      Text('Reset Password', style: TextStyle(color: theme.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Center(
                      child: SingleChildScrollView(
                        child: GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.accent.withOpacity(0.15)),
                                  child: Icon(Icons.lock_reset_rounded, size: 44, color: theme.accent),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Enter your email to receive reset instructions',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.textSecondary),
                              ),
                              const SizedBox(height: 20),
                              GlassField(controller: _emailController, label: 'Email', icon: Icons.email_outlined, theme: theme, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 24),
                              GradientButton(theme: theme, loading: false, label: 'Send Reset Link', onPressed: () => setState(() => _sent = true)),
                              if (_sent) ...[
                                const SizedBox(height: 16),
                                Text('Check your email for reset instructions', textAlign: TextAlign.center, style: TextStyle(color: theme.success)),
                              ],
                              TextButton(
                                onPressed: () => context.go(AppRoutes.login),
                                child: Text('Back to Login', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
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
}
