class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? actionUrl;
  final String? createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.actionUrl,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['read'] ?? false,
      actionUrl: json['actionUrl'],
      createdAt: json['createdAt'],
    );
  }
}
