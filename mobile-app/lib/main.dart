import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/router_provider.dart';
import 'core/services/app_messenger.dart';
import 'core/services/push_notification_service.dart';
import 'firebase_options.dart';

bool _firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase credentials are admin-managed (System Config screen in the admin portal)
  // rather than hardcoded in firebase_options.dart. If they haven't been configured yet
  // or the backend is unreachable, skip Firebase init so the app still starts normally.
  try {
    final options = await DefaultFirebaseOptions.fetchFromBackend();
    if (options != null) {
      await Firebase.initializeApp(options: options);
      _firebaseReady = true;
    }
  } catch (e) {
    print('Firebase initialization skipped: $e');
  }

  runApp(const ProviderScope(child: LmsApp()));
}

class LmsApp extends ConsumerWidget {
  const LmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Push notifications only start doing anything once Firebase is actually
    // configured (admin has filled in System Config) -- this call is safe
    // and inert otherwise. Runs once per router instance.
    debugPrint('FCM: _firebaseReady = $_firebaseReady');
    if (_firebaseReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('FCM: calling PushNotificationService().initialize()');
        PushNotificationService().initialize(router);
      });
    } else {
      debugPrint('FCM: Firebase not ready, skipping push initialization');
    }

    return MaterialApp.router(
      title: 'Axisora Forge Academy',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      supportedLocales: const [
        Locale('en'),
      ],
    );
  }
}