import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mobile_auth_service.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../models/auth_user.dart';
import 'data_providers.dart';
import 'subscription_provider.dart';
import 'org_theme_provider.dart';

/// Tracks whether the user is logged in and holds the auth user info.
final mobileAuthProvider = StateNotifierProvider<MobileAuthNotifier, MobileAuthState>((ref) {
  return MobileAuthNotifier(ref);
});

class MobileAuthState {
  final bool isLoggedIn;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  MobileAuthState({this.isLoggedIn = false, this.user, this.isLoading = false, this.errorMessage});

  MobileAuthState copyWith({
    bool? isLoggedIn,
    AuthUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return MobileAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class MobileAuthNotifier extends StateNotifier<MobileAuthState> {
  final MobileAuthService _auth = MobileAuthService();
  final Ref _ref;

  MobileAuthNotifier(this._ref) : super(MobileAuthState()) {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    state = state.copyWith(isLoading: true);
    final loggedIn = await _auth.isLoggedIn();
    final user = loggedIn ? await _auth.getUser() : null;
    state = state.copyWith(isLoggedIn: loggedIn, user: user, isLoading: false);
    if (loggedIn) {
      try {
        await _syncSubscription();
      } catch (_) {}
      try {
        await _ref.read(orgThemeProvider.notifier).refresh();
      } catch (_) {}
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _auth.login(email, password);
      state = state.copyWith(isLoggedIn: true, user: response.user, isLoading: false);
      invalidateAllUserData(_ref);

      // Post-login background tasks should never fail the user's login
      try {
        await _syncSubscription();
      } catch (e) {
        debugPrint('Sync subscription error: $e');
      }
      try {
        await _registerPushToken();
      } catch (e) {
        debugPrint('Push token error: $e');
      }
      try {
        await _ref.read(orgThemeProvider.notifier).refresh();
      } catch (e) {
        debugPrint('Theme refresh error: $e');
      }
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoggedIn: false, isLoading: false, errorMessage: message);
      return false;
    }
  }

  Future<bool> register(String fullName, String email, String password, [String? phone]) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _auth.register(fullName, email, password, phone);
      state = state.copyWith(isLoggedIn: true, user: response.user, isLoading: false);
      invalidateAllUserData(_ref);

      try {
        await _syncSubscription();
      } catch (e) {
        debugPrint('Sync subscription error: $e');
      }
      try {
        await _registerPushToken();
      } catch (e) {
        debugPrint('Push token error: $e');
      }
      try {
        await _ref.read(orgThemeProvider.notifier).refresh();
      } catch (e) {
        debugPrint('Theme refresh error: $e');
      }
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoggedIn: false, isLoading: false, errorMessage: message);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await PushNotificationService().clearToken();
    } catch (_) {}
    await _auth.logout();
    invalidateAllUserData(_ref);
    state = state.copyWith(isLoggedIn: false, clearUser: true);
    _ref.read(subscriptionProvider.notifier).reset();
    try {
      await _ref.read(orgThemeProvider.notifier).reset();
    } catch (_) {}
  }

  void markPaymentCompleted() {
    final user = state.user;
    if (user == null) return;
    final updated = AuthUser(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
      planId: user.planId,
      batchId: user.batchId,
      paymentRequired: false,
      paymentMethod: user.paymentMethod,
      paymentStatus: 'COMPLETED',
      amountDue: user.amountDue,
    );
    state = state.copyWith(user: updated);
  }

  Future<void> _registerPushToken() async {
    if (kIsWeb) return; // Push tokens via FCM are handled natively on mobile
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final apiService = ApiService();
      await apiService.updateFcmToken(token);
    } catch (e) {
      debugPrint('Failed to register push token after login: $e');
    }
  }

  Future<void> _syncSubscription() async {
    try {
      final apiService = ApiService();
      final profile = await apiService.getUserProfile();
      if (profile != null) {
        await _ref.read(subscriptionProvider.notifier).syncFromProfile(profile);
      }
    } catch (e) {
      debugPrint('Failed to sync subscription: $e');
    }
  }
}
