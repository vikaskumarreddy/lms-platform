import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:lms_student_app/data/models/notification_item.dart';
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

  @override
  void initState() {
    super.initState();
    ref.read(unreadCountProvider.future);
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _api.put('notifications/$id/read');
    } catch (_) {}
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _api.delete('notifications/clear');
    } catch (_) {}
    if (mounted) {
      ref.refresh(notificationsProvider.future);
      ref.refresh(unreadCountProvider.future);
    }
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will remove all notifications. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearAllNotifications();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: const CommonHeader(title: 'Notifications'),
      body: asyncNotifications.when(
        data: (items) {
          if (items.isEmpty) return _emptyState();

          final filtered = _selectedFilter == 'All'
              ? items
              : items.where((n) => n.type == _selectedFilter).toList();

          return Column(
            children: [
              _filterChips(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(notificationsProvider.future);
                    ref.refresh(unreadCountProvider.future);
                  },
                  child: filtered.isEmpty
                      ? _noResultsState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _notificationCard(filtered[index]);
                          },
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _errorState(),
      ),
    );
  }

  Widget _filterChips() {
    final types = ['All', 'chat', 'qa', 'assignment', 'placement', 'attendance', 'exam', 'course', 'info'];
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = types[index];
          final selected = _selectedFilter == type;
          return FilterChip(
            label: Text(type[0].toUpperCase() + type.substring(1)),
            selected: selected,
            onSelected: (_) => setState(() => _selectedFilter = type),
            selectedColor: Theme.of(context).colorScheme.secondary,
            checkmarkColor: Colors.black,
            labelStyle: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : AppTheme.textSecondary,
            ),
            backgroundColor: Colors.white,
            side: BorderSide(color: selected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.outline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _notificationCard(NotificationItem n) {
    final typeColor = _getNotificationColor(n.type);
    final typeIcon = _getNotificationIcon(n.type);
    final details = n.detailFields;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: n.isRead ? Theme.of(context).colorScheme.outline : typeColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Institution header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(typeIcon, color: Theme.of(context).colorScheme.secondary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    NotificationItem.institutionName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!n.isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NEW',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (n.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Column(
                      children: details.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 75,
                                child: Text(
                                  '${entry.key}:',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      n.createdAt ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (!n.isRead)
                      TextButton(
                        onPressed: () {
                          _markAsRead(n.id);
                          ref.refresh(notificationsProvider.future);
                          ref.refresh(unreadCountProvider.future);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          'Mark Read',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ),
                    if (n.actionUrl != null && n.actionUrl!.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _markAsRead(n.id);
                          ref.refresh(notificationsProvider.future);
                          ref.refresh(unreadCountProvider.future);
                          final url = n.actionUrl ?? '';
                          if (url.isNotEmpty && url.startsWith('/')) {
                            context.push(url);
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          'VIEW',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No notifications yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text('You will see notifications from admin here', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => ref.refresh(notificationsProvider.future), child: const Text('Refresh')),
      ]),
    );
  }

  Widget _noResultsState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.filter_list_off, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No notifications in this filter', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _errorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Failed to load notifications', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => ref.refresh(notificationsProvider.future), child: const Text('Retry')),
      ]),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat': return Icons.chat_bubble_outline;
      case 'qa': return Icons.forum_outlined;
      case 'assignment': return Icons.assignment;
      case 'placement': return Icons.work;
      case 'attendance': return Icons.fact_check;
      case 'exam': return Icons.quiz;
      case 'course': return Icons.menu_book;
      case 'success': return Icons.check_circle;
      case 'warning': return Icons.warning;
      case 'error': return Icons.error;
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'chat': return const Color(0xFF27D9D3);
      case 'qa': return const Color(0xFF6366F1);
      case 'assignment': return Colors.blue;
      case 'placement': return Colors.green;
      case 'attendance': return Colors.orange;
      case 'exam': return Colors.purple;
      case 'course': return Colors.teal;
      case 'success': return Colors.green;
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      default: return Theme.of(context).colorScheme.primary;
    }
  }
}