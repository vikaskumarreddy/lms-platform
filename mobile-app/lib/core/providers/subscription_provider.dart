import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms_student_app/data/models/subscription_plan.dart';
import 'package:lms_student_app/core/services/api_service.dart';

/// Represents the subscription plan the user is currently on.
enum SubscriptionPlan {
  free('Free'),
  javaFullStack('Java Full Stack'),
  placement('Placement Pro'),
  allAccess('All Access');

  final String label;
  const SubscriptionPlan(this.label);

  /// Whether this plan grants access to the course with the given id.
  bool canAccessCourse(int courseId) {
    switch (this) {
      case SubscriptionPlan.free:
        return false;
      case SubscriptionPlan.javaFullStack:
        // Java Full Stack plan gives access to course 1 and 2
        return courseId == 1 || courseId == 2;
      case SubscriptionPlan.placement:
        // Placement plan gives access to course 1 only
        return courseId == 1;
      case SubscriptionPlan.allAccess:
        return true;
    }
  }
}

/// Holds the user's current subscription plan.
class SubscriptionState {
  final SubscriptionPlan plan;
  final List<SubscriptionPlanModel> availablePlans;
  final int? userPlanId;

  const SubscriptionState({
    this.plan = SubscriptionPlan.free,
    this.availablePlans = const [],
    this.userPlanId,
  });

  SubscriptionState copyWith({
    SubscriptionPlan? plan,
    List<SubscriptionPlanModel>? availablePlans,
    int? userPlanId,
  }) {
    return SubscriptionState(
      plan: plan ?? this.plan,
      availablePlans: availablePlans ?? this.availablePlans,
      userPlanId: userPlanId ?? this.userPlanId,
    );
  }

  /// Returns the set of plan IDs the user has access to.
  /// Used for plan-based access control on courses and placement drives.
  /// Uses the actual planId from the user's profile when available.
  Set<int> get activePlanIds {
    if (userPlanId != null) {
      return {userPlanId!};
    }
    switch (plan) {
      case SubscriptionPlan.free:
        return {};
      case SubscriptionPlan.javaFullStack:
        return {1}; // Java Full Stack plan ID
      case SubscriptionPlan.placement:
        return {2}; // Placement Pro plan ID
      case SubscriptionPlan.allAccess:
        return {1, 2, 3}; // All Access plan ID
    }
  }

  /// Get plan by ID from available plans
  SubscriptionPlanModel? getPlanById(int planId) {
    try {
      return availablePlans.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }
}

/// Global provider for the user's subscription state.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState());

  void setPlan(SubscriptionPlan plan) {
    state = state.copyWith(plan: plan);
  }

  /// Clears the subscription state (used on logout) so a new session
  /// doesn't briefly show the previous user's plan/access.
  void reset() {
    state = const SubscriptionState();
  }

  /// Sync the user's subscription plan from the backend profile.
  /// The profile response contains `planId` and `planName`.
  Future<void> syncFromProfile(Map<String, dynamic>? profile) async {
    if (profile == null) return;
    final planId = profile['planId'];
    final planName = profile['planName'];

    if (planId == null) {
      state = state.copyWith(plan: SubscriptionPlan.free, userPlanId: null);
      return;
    }

    final actualPlanId = (planId is int) ? planId : int.tryParse(planId.toString());

    // Map backend plan to local enum based on plan name
    SubscriptionPlan newPlan;
    final name = (planName ?? '').toString().toLowerCase();
    if (name.contains('all access') || name.contains('all-access')) {
      newPlan = SubscriptionPlan.allAccess;
    } else if (name.contains('placement')) {
      newPlan = SubscriptionPlan.placement;
    } else if (name.contains('java') || name.contains('full stack')) {
      newPlan = SubscriptionPlan.javaFullStack;
    } else {
      newPlan = SubscriptionPlan.free;
    }
    state = state.copyWith(plan: newPlan, userPlanId: actualPlanId);
  }

  /// Load available subscription plans from backend
  Future<void> loadSubscriptionPlans() async {
    try {
      final apiService = ApiService();
      final plans = await apiService.getSubscriptionPlans();
      state = state.copyWith(availablePlans: plans);
    } catch (e) {
      print('Failed to load subscription plans: $e');
    }
  }

  /// Update user's subscription plan
  Future<void> updateUserPlan(int planId) async {
    try {
      final apiService = ApiService();
      final success = await apiService.updateUserPlan(planId);
      
      if (success) {
        final planModel = state.getPlanById(planId);
        if (planModel != null) {
          // Map backend plan to local enum
          SubscriptionPlan newPlan;
          switch (planModel.name.toLowerCase()) {
            case 'java full stack':
              newPlan = SubscriptionPlan.javaFullStack;
              break;
            case 'placement pro':
              newPlan = SubscriptionPlan.placement;
              break;
            case 'all access':
              newPlan = SubscriptionPlan.allAccess;
              break;
            default:
              newPlan = SubscriptionPlan.free;
          }
          state = state.copyWith(plan: newPlan);
        }
      }
    } catch (e) {
      print('Failed to update user plan: $e');
    }
  }
}