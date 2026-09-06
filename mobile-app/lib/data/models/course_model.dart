import 'package:lms_student_app/data/models/course_section.dart';

class CourseModel {
  final int id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final int? planId;
  final double? progress;
  final int totalLessons;
  final int completedLessons;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailUrl = '',
    this.planId,
    this.progress,
    this.totalLessons = 0,
    this.completedLessons = 0,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: _safeInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? json['thumbnail_url']?.toString() ?? '',
      planId: _safeIntNullable(json['planId']),
      progress: _safeDouble(json['progress']),
      totalLessons: _safeInt(json['totalLessons']),
      completedLessons: _safeInt(json['completedLessons']),
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

  /// Safely parse any value to nullable int.
  static int? _safeIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Safely parse any value to nullable double.
  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String get lessonsDisplay {
    if (totalLessons == 0) return '$totalLessons';
    return '$completedLessons/$totalLessons';
  }

  int get progressPercent => ((progress ?? 0) * 100).toInt();
}
