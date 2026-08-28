class AssignmentModel {
  final int id;
  final String title;
  final String description;
  final String? dueDate;
  final int? totalMarks;
  final int? batchId;
  final int? courseId;
  final bool? isActive;
  final String? status;
  final int? submissionId;
  final String? submittedAt;
  final int? marksObtained;
  final bool? isGraded;
  /// WEB opens [links]['details'] in the embedded browser; IN_APP means the paper
  /// authored in the admin portal is answered inside the app.
  final String deliveryMode;
  final int questionCount;
  final Map<String, String>? links;

  AssignmentModel({
    required this.id,
    required this.title,
    required this.description,
    this.dueDate,
    this.totalMarks,
    this.batchId,
    this.courseId,
    this.isActive,
    this.status,
    this.submissionId,
    this.submittedAt,
    this.marksObtained,
    this.isGraded,
    this.deliveryMode = 'WEB',
    this.questionCount = 0,
    this.links,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    Map<String, String>? links;
    if (json['_links'] != null) {
      links = Map<String, String>.from(json['_links']);
    }

    return AssignmentModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dueDate: json['dueDate'],
      totalMarks: json['totalMarks'],
      batchId: json['batchId'],
      courseId: json['courseId'],
      isActive: json['isActive'],
      status: json['status'],
      submissionId: json['submissionId'],
      submittedAt: json['submittedAt'],
      marksObtained: json['marksObtained'],
      isGraded: json['isGraded'],
      deliveryMode: json['deliveryMode'] ?? 'WEB',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      links: links,
    );
  }

  bool get isInApp => deliveryMode == 'IN_APP';

  String get formattedDueDate {
    final due = dueDate;
    if (due == null || due.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(due);
    if (dt == null) return due;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  bool get isOverdue {
    if (dueDate == null || dueDate!.isEmpty) return false;
    final dt = DateTime.tryParse(dueDate!);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now()) && status != 'Submitted';
  }
}
