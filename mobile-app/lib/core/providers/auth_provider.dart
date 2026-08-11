import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mobile_auth_service.dart';
import '../services/api_service.dart';
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

  MobileAuthState copyWith({bool? isLoggedIn, AuthUser? user, bool? isLoading}) {
    return MobileAuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
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
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    state = state.copyWith(isLoggedIn: false, user: null);
    _ref.read(subscriptionProvider.notifier).reset();
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
