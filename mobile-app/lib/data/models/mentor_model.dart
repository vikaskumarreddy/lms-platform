/// A mentor a student can see on their dashboard.
///
/// The backend derives this from real relationships — the mentor on the student's
/// batch, plus the instructor of each course the student is on — so there is no
/// separate "mentor assignment" record to keep in sync.
class MentorModel {
  final int id;
  final String name;
  final String email;
  final String phone;

  /// Role label, e.g. "Batch Mentor" or "Course Mentor".
  final String designation;

  /// What they mentor on: the batch name, or the student's courses they teach.
  final String expertise;

  /// True for the student's own batch mentor (their primary contact).
  final bool primaryMentor;

  final int? batchId;
  final String batchName;
  final List<String> courseNames;

  MentorModel({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.designation = 'Mentor',
    this.expertise = '',
    this.primaryMentor = false,
    this.batchId,
    this.batchName = '',
    this.courseNames = const [],
  });

  factory MentorModel.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courseNames'];
    return MentorModel(
      id: _safeInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      designation: json['designation']?.toString() ?? 'Mentor',
      expertise: json['expertise']?.toString() ?? '',
      primaryMentor: json['primaryMentor'] == true,
      batchId: _safeIntNullable(json['batchId']),
      batchName: json['batchName']?.toString() ?? '',
      courseNames: rawCourses is List
          ? rawCourses.map((e) => e.toString()).toList()
          : const [],
    );
  }

  /// The single line shown under the mentor's name — what they teach, falling
  /// back to their role label so the row is never blank.
  String get subtitle {
    final text = expertise.isNotEmpty ? expertise : batchName;
    if (text.isNotEmpty) return text;
    return designation.isEmpty ? 'Mentor' : designation;
  }

  /// Initials for the avatar circle when no photo is available.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _safeIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}