import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../data/services/api_client.dart';
import '../../../core/widgets/common_header.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';
  final ApiClient _api = ApiClient();

  List<Map<String, dynamic>> _allNotifications = [];

  @override
  void initState() {
    super.initState();
    // Fetch unread count on init
    ref.read(unreadCountProvider.future);
  }

  void _markAsRead(int id) {
    _api.put('notifications/$id/read').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: const CommonHeader(title: 'Notifications'),
      body: asyncNotifications.when(
        data: (items) {
          _allNotifications = items.asMap().map((i, n) => MapEntry(i, {
            'id': n.id, 'title': n.title, 'message': n.message,
            'type': n.type, 'isRead': n.isRead, 'time': n.createdAt ?? '',
            'actionUrl': n.actionUrl ?? '',
          })).values.toList();

          final filtered = _selectedFilter == 'All'
              ? _allNotifications
              : _allNotifications.where((n) => n['type'] == _selectedFilter).toList();

          if (_allNotifications.isEmpty) {
            return _emptyState();
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search notifications...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ]),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: ['All', 'info', 'success', 'warning', 'error'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter == 'All' ? 'All' : filter[0].toUpperCase() + filter.substring(1)),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        selectedColor: const Color(0xFFEAB308),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.grey.shade700),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No notifications in this category', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final notification = filtered[index];
                          final isRead = notification['isRead'] as bool;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: isRead ? Colors.white : const Color(0xFFFEF3C7),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getNotificationColor(notification['type']),
                                child: Icon(_getNotificationIcon(notification['type']), color: Colors.white, size: 20),
                              ),
                              title: Text(
                                notification['title'],
                                style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(notification['message'], maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(notification['time'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () {
                                if (!isRead) {
                                  _markAsRead(notification['id']);
                                  setState(() => notification['isRead'] = true);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _emptyState(),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text('You will see notifications from admin here', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => ref.refresh(notificationsProvider.future), child: const Text('Refresh')),
      ]),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'assignment': return Icons.assignment;
      case 'placement': return Icons.work;
      case 'attendance': return Icons.fact_check;
      case 'exam': return Icons.quiz;
      case 'course': return Icons.book;
      case 'success': return Icons.check_circle;
      case 'warning': return Icons.warning;
      case 'error': return Icons.error;
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'assignment': return Colors.blue;
      case 'placement': return Colors.green;
      case 'attendance': return Colors.orange;
      case 'exam': return Colors.purple;
      case 'course': return Colors.teal;
      case 'success': return Colors.green;
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      default: return Colors.grey;
    }
  }
}
