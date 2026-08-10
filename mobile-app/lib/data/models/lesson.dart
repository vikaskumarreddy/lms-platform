class Lesson {
  final int id;
  final String title;
  final String heading;
  final String duration;
  final bool completed;
  final bool isLocked;
  final bool isMandatory;
  final String videoUrl;
  final String thumbnailUrl;
  final String pdfNotesUrl;
  final String notes;

  Lesson({
    required this.id,
    required this.title,
    this.heading = '',
    required this.duration,
    this.completed = false,
    this.isLocked = false,
    this.isMandatory = true,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.pdfNotesUrl = '',
    required this.notes,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    // Backend sends durationMinutes as an int; fall back to 'duration' key
    final rawDuration = json['durationMinutes'] ?? json['duration'];
    final durationStr = rawDuration != null ? '$rawDuration min' : '0 min';

    return Lesson(
      id: _safeInt(json['id']),
      title: json['title']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      duration: durationStr,
      completed: json['completed'] == true,
      isLocked: json['isLocked'] == true || json['locked'] == true,
      isMandatory: json['isMandatory'] != false,
      videoUrl: json['videoUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      pdfNotesUrl: json['pdfNotesUrl']?.toString() ?? '',
      notes: json['content']?.toString() ?? json['notes']?.toString() ?? '',
    );
  }

  /// Safely parse any value to int, defaulting to 0.
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
