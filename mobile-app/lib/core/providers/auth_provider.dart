import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mobile_auth_service.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../models/auth_user.dart';
import 'subscription_provider.dart';

/// Tracks whether the user is logged in and holds the auth user info.
final mobileAuthProvider = StateNotifierProvider<MobileAuthNotifier, MobileAuthState>((ref) {
  return MobileAuthNotifier(ref);
});

class MobileAuthState {
  final bool isLoggedIn;
  final AuthUser? user;
  final bool isLoading;

  MobileAuthState({this.isLoggedIn = false, this.user, this.isLoading = false});

  MobileAuthState copyWith({bool? isLoggedIn, AuthUser? user, bool? isLoading, bool clearUser = false}) {
    return MobileAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      // `clearUser` lets logout() actually null the cached user — a plain
      // `user ?? this.user` fallback can never clear it.
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
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
    // Re-sync the subscription plan from the backend whenever a persisted
    // session is restored (e.g. app restart), otherwise the subscription
    // state resets to Free and previously-unlocked courses appear locked.
    if (loggedIn) {
      await _syncSubscription();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _auth.login(email, password);
      state = state.copyWith(isLoggedIn: true, user: response.user);
      // Sync subscription from backend profile
      await _syncSubscription();
      await _registerPushToken();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String fullName, String email, String password, [String? phone]) async {
    try {
      final response = await _auth.register(fullName, email, password, phone);
      state = state.copyWith(isLoggedIn: true, user: response.user);
      // Sync subscription from backend profile
      await _syncSubscription();
      await _registerPushToken();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await PushNotificationService().clearToken();
    await _auth.logout();
    state = state.copyWith(isLoggedIn: false, clearUser: true);
    _ref.read(subscriptionProvider.notifier).reset();
  }

  /// Flips the cached user's payment flag to COMPLETED so the router redirect
  /// (which guards every authenticated route) stops forcing the student back
  /// to the payment screen after a successful payment.
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

  /// Registers this device's current FCM token (if any) with the backend
  /// right after login/register, so the very first session on a device
  /// starts receiving push notifications without waiting for a token
  /// refresh event.
  Future<void> _registerPushToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final apiService = ApiService();
      await apiService.updateFcmToken(token);
    } catch (e) {
      print('Failed to register push token after login: $e');
    }
  }

  /// Fetch the user profile from backend and sync the subscription plan.
  Future<void> _syncSubscription() async {
    try {
      final apiService = ApiService();
      final profile = await apiService.getUserProfile();
      if (profile != null) {
        // Use the global subscription notifier to sync the plan
        await _ref.read(subscriptionProvider.notifier).syncFromProfile(profile);
      }
    } catch (e) {
      print('Failed to sync subscription: $e');
    }
  }
}
