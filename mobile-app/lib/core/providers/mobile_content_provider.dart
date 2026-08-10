import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api_client.dart';
import '../../data/models/mobile_content_item.dart';
import 'subscription_plans_provider.dart';

/// Fetches all active mobile content items from the backend.
/// Used by the home screen to render banners, stats, links, and upcoming items.
final mobileContentProvider = FutureProvider<List<MobileContentItem>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('mobile-content');
    final data = response.data;
    if (data is List) {
      return data.map((e) => MobileContentItem.fromJson(e)).toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

/// Convenience: content items grouped by section.
final mobileContentBySectionProvider = Provider.family<List<MobileContentItem>, String>((ref, section) {
  final all = ref.watch(mobileContentProvider).valueOrNull ?? [];
  return all.where((c) => c.section == section).toList();
});
