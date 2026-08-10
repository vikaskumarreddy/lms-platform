class ExamModel {
  final int id;
  final String title;
  final String description;
  final String? examDate;
  final int? durationMinutes;
  final int? totalMarks;
  final int? passingMarks;
  final int? batchId;
  final int? courseId;
  final bool? isActive;
  final String? status;
  final int? submissionId;
  final String? submittedAt;
  final int? marksObtained;
  final bool? isGraded;
  final Map<String, String>? links;

  ExamModel({
    required this.id,
    required this.title,
    required this.description,
    this.examDate,
    this.durationMinutes,
    this.totalMarks,
    this.passingMarks,
    this.batchId,
    this.courseId,
    this.isActive,
    this.status,
    this.submissionId,
    this.submittedAt,
    this.marksObtained,
    this.isGraded,
    this.links,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    Map<String, String>? links;
    if (json['_links'] != null) {
      links = Map<String, String>.from(json['_links']);
    }

    return ExamModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      examDate: json['examDate'],
      durationMinutes: json['durationMinutes'],
      totalMarks: json['totalMarks'],
      passingMarks: json['passingMarks'],
      batchId: json['batchId'],
      courseId: json['courseId'],
      isActive: json['isActive'],
      status: json['status'],
      submissionId: json['submissionId'],
      submittedAt: json['submittedAt'],
      marksObtained: json['marksObtained'],
      isGraded: json['isGraded'],
      links: links,
    );
  }

  String get formattedDate {
    final date = examDate;
    if (date == null || date.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String get formattedTime {
    final date = examDate;
    if (date == null || date.isEmpty) return '';
    final dt = DateTime.tryParse(date);
    if (dt == null) return '';
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $ampm';
  }

  String get durationDisplay {
    final d = durationMinutes;
    if (d == null) return 'N/A';
    if (d < 60) return '$d min';
    final h = d ~/ 60;
    final m = d % 60;
    return m == 0 ? '$h hour${h > 1 ? 's' : ''}' : '$h hour${h > 1 ? 's' : ''} $m min';
  }

  bool get isPassed {
    if (marksObtained == null || passingMarks == null) return false;
    return marksObtained! >= passingMarks!;
  }
}