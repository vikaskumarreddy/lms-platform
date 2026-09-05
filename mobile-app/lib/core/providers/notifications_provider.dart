import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/api_client.dart';
import '../../data/models/notification_item.dart';

/// Fetches all notifications for the current user from the backend.
final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  try {
    final api = ApiClient();
    final response = await api.get('notifications');
    final data = response.data;
    if (data is List) {
      return data
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

/// Fetches the count of unread notifications from the backend.
final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final api = ApiClient();
    final response = await api.get('notifications/unread-count');
    if (response.data is Map) {
      final count = (response.data as Map)['count'];
      if (count is int) return count;
      return int.tryParse(count?.toString() ?? '') ?? 0;
    }
    return 0;
  } catch (e) {
    return 0;
  }
});
