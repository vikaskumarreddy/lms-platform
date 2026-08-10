class EventModel {
  final int id;
  final String title;
  final String description;
  final String? eventType;
  final String? startTime;
  final String? endTime;
  final String? venue;
  final String? meetLink;
  final bool? attendanceRequired;
  final int? batchId;
  final int? planId;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    this.eventType,
    this.startTime,
    this.endTime,
    this.venue,
    this.meetLink,
    this.attendanceRequired,
    this.batchId,
    this.planId,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      eventType: json['eventType'],
      startTime: json['startTime'],
      endTime: json['endTime'],
      venue: json['venue'],
      meetLink: json['meetLink'],
      attendanceRequired: json['attendanceRequired'],
      batchId: json['batchId'],
      planId: json['planId'],
    );
  }

  String get date {
    final s = startTime ?? '';
    if (s.isEmpty) return '';
    final parts = s.split('T');
    if (parts.isEmpty) return s;
    final datePart = parts[0];
    final d = datePart.split('-');
    if (d.length != 3) return datePart;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(d[1]) ?? 1;
    final day = int.tryParse(d[2]) ?? 1;
    return '$day ${months[month - 1]} ${d[0]}';
  }

  String get time {
    final s = startTime ?? '';
    if (s.isEmpty) return '';
    final parts = s.split('T');
    if (parts.length < 2) return '';
    final timePart = parts[1].substring(0, 5);
    final t = timePart.split(':');
    if (t.length != 2) return timePart;
    final hour = int.tryParse(t[0]) ?? 0;
    final minute = t[1];
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $ampm';
  }

  String get category => eventType ?? 'General';
}