class Lesson {
  final int id;
  final String title;
  final String heading;
  final String duration;
  final bool completed;
  final bool isLocked;
  final bool isMandatory;
  final String videoUrl;
  /// "URL" (external, e.g. YouTube) or "SELF" (uploaded via Media & Files) —
  /// tells the player whether to embed a YouTube iframe or play videoUrl
  /// natively as a direct video file.
  final String videoSource;
  final String thumbnailUrl;
  final String pdfNotesUrl;
  final String notesType;
  final String notes;
  final int? nextLessonId;
  final String? nextLessonTitle;

  Lesson({
    required this.id,
    required this.title,
    this.heading = '',
    required this.duration,
    this.completed = false,
    this.isLocked = false,
    this.isMandatory = true,
    required this.videoUrl,
    this.videoSource = 'URL',
    this.thumbnailUrl = '',
    this.pdfNotesUrl = '',
    this.notesType = 'PDF',
    required this.notes,
    this.nextLessonId,
    this.nextLessonTitle,
  });

  bool get isHtmlNotes {
    if (notesType.toUpperCase() == 'HTML') return true;
    final trimmed = notes.trim();
    if (trimmed.startsWith('b64:')) return true;
    final lower = trimmed.toLowerCase();
    return lower.startsWith('<!doctype') ||
        lower.startsWith('<html') ||
        lower.startsWith('<div') ||
        lower.startsWith('<p>') ||
        lower.startsWith('<p ') ||
        lower.startsWith('<h1') ||
        lower.startsWith('<h2') ||
        lower.startsWith('<h3') ||
        lower.startsWith('<section') ||
        lower.startsWith('<article') ||
        lower.startsWith('<table');
  }

  factory Lesson.fromJson(Map<String, dynamic> json) {
    // Backend sends durationMinutes as an int; fall back to 'duration' key
    final rawDuration = json['durationMinutes'] ?? json['duration'];
    final durationStr = rawDuration != null ? '$rawDuration min' : '0 min';

    final rawType = (json['notesType'] ?? json['notes_type'])?.toString().toUpperCase();
    final rawNotes = (json['content'] ?? json['notes'])?.toString() ?? '';
    final trimmedNotes = rawNotes.trim();
    final lowerNotes = trimmedNotes.toLowerCase();

    final isHtmlDetected = rawType == 'HTML' ||
        trimmedNotes.startsWith('b64:') ||
        lowerNotes.startsWith('<!doctype') ||
        lowerNotes.startsWith('<html') ||
        lowerNotes.startsWith('<div') ||
        lowerNotes.startsWith('<p>') ||
        lowerNotes.startsWith('<p ') ||
        lowerNotes.startsWith('<h1') ||
        lowerNotes.startsWith('<h2') ||
        lowerNotes.startsWith('<h3') ||
        lowerNotes.startsWith('<section') ||
        lowerNotes.startsWith('<article') ||
        lowerNotes.startsWith('<table');

    return Lesson(
      id: _safeInt(json['id']),
      title: json['title']?.toString() ?? '',
      heading: json['heading']?.toString() ?? '',
      duration: durationStr,
      completed: json['completed'] == true,
      isLocked: json['isLocked'] == true || json['locked'] == true,
      isMandatory: json['isMandatory'] != false,
      videoUrl: json['videoUrl']?.toString() ?? '',
      videoSource: json['videoSource']?.toString() ?? 'URL',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      pdfNotesUrl: json['pdfNotesUrl']?.toString() ?? '',
      notesType: isHtmlDetected ? 'HTML' : 'PDF',
      notes: rawNotes,
      nextLessonId: json['nextLessonId'] != null ? _safeInt(json['nextLessonId']) : null,
      nextLessonTitle: json['nextLessonTitle']?.toString(),
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
