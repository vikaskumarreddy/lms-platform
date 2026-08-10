import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api_client.dart';
import '../../data/models/subscription_plan.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Fetches available subscription plans from the backend.
/// If the API fails, returns an empty list (screens fall back to defaults).
final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('subscription-plans');
    final data = response.data;
    if (data is List) {
      return data.map((e) => SubscriptionPlanModel.fromJson(e)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});
