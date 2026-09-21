class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? actionUrl;
  final String? createdAt;
  // Rich data fields for detailed notifications
  final String? date;
  final String? time;
  final String? name;
  final String? venue;
  final String? criteria;
  final String? description;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.actionUrl,
    this.createdAt,
    this.date,
    this.time,
    this.name,
    this.venue,
    this.criteria,
    this.description,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['isRead'] ?? json['read'] ?? false,
      actionUrl: json['actionUrl'],
      createdAt: json['createdAt'],
      date: json['date'],
      time: json['time'],
      name: json['name'],
      venue: json['venue'],
      criteria: json['criteria'],
      description: json['description'],
    );
  }

  /// Returns the institution name for display in notification headers
  static const String institutionName = 'Axisora Forge Academy';

  /// Returns a map of extra fields for display in the notification card
  Map<String, String?> get detailFields {
    final fields = <String, String?>{};
    if (name != null && name!.isNotEmpty) fields['Name'] = name;
    if (date != null && date!.isNotEmpty) fields['Date'] = date;
    if (time != null && time!.isNotEmpty) fields['Time'] = time;
    if (venue != null && venue!.isNotEmpty) fields['Venue'] = venue;
    if (criteria != null && criteria!.isNotEmpty) fields['Criteria'] = criteria;
    if (description != null && description!.isNotEmpty) fields['Description'] = description;
    return fields;
  }

  bool get isReminder =>
      type.toLowerCase() == 'reminder' ||
      title.toLowerCase().contains('reminder') ||
      (actionUrl != null && actionUrl!.contains('reminders'));

  bool get isPlacement =>
      type.toLowerCase() == 'placement' ||
      title.toLowerCase().contains('placement') ||
      title.toLowerCase().contains('drive') ||
      (actionUrl != null && actionUrl!.contains('placement'));

  bool get isExam =>
      type.toLowerCase() == 'exam' ||
      title.toLowerCase().contains('exam') ||
      (actionUrl != null && actionUrl!.contains('exam'));

  bool get isAssignment =>
      type.toLowerCase() == 'assignment' ||
      title.toLowerCase().contains('assignment') ||
      (actionUrl != null && actionUrl!.contains('assignment'));

  bool get isCourse =>
      type.toLowerCase() == 'course' ||
      title.toLowerCase().contains('course') ||
      (actionUrl != null && actionUrl!.contains('course'));

  String get categoryBadgeText {
    if (isReminder) return 'REMINDER';
    if (isPlacement) return 'PLACEMENT DRIVE';
    if (isExam) return 'EXAM ALERT';
    if (isAssignment) return 'ASSIGNMENT';
    if (isCourse) return 'COURSE UPDATE';
    if (type.toLowerCase() == 'announcement') return 'ANNOUNCEMENT';
    return 'LMS NOTIFICATION';
  }
}

/// Extension to ensure category getters are accessible across all compilation modes and hot restarts
extension NotificationItemCategory on NotificationItem {
  bool get isReminderItem =>
      type.toLowerCase() == 'reminder' ||
      title.toLowerCase().contains('reminder') ||
      (actionUrl != null && actionUrl!.contains('reminders'));

  bool get isPlacementItem =>
      type.toLowerCase() == 'placement' ||
      title.toLowerCase().contains('placement') ||
      title.toLowerCase().contains('drive') ||
      (actionUrl != null && actionUrl!.contains('placement'));

  bool get isExamItem =>
      type.toLowerCase() == 'exam' ||
      title.toLowerCase().contains('exam') ||
      (actionUrl != null && actionUrl!.contains('exam'));

  bool get isAssignmentItem =>
      type.toLowerCase() == 'assignment' ||
      title.toLowerCase().contains('assignment') ||
      (actionUrl != null && actionUrl!.contains('assignment'));

  bool get isCourseItem =>
      type.toLowerCase() == 'course' ||
      title.toLowerCase().contains('course') ||
      (actionUrl != null && actionUrl!.contains('course'));

  String get badgeText {
    if (isReminder) return 'REMINDER';
    if (isPlacement) return 'PLACEMENT DRIVE';
    if (isExam) return 'EXAM ALERT';
    if (isAssignment) return 'ASSIGNMENT';
    if (isCourse) return 'COURSE UPDATE';
    if (type.toLowerCase() == 'announcement') return 'ANNOUNCEMENT';
    return 'LMS NOTIFICATION';
  }
}
