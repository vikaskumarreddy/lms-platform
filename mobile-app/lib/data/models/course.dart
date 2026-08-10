class Course {
  final int id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final double progress;
  final int totalLessons;
  final int completedLessons;
  final int? planId;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    this.progress = 0.0,
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.planId,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      progress: (json['progress'] ?? 0.0).toDouble(),
      totalLessons: json['totalLessons'] ?? 0,
      completedLessons: json['completedLessons'] ?? 0,
      planId: json['planId'],
    );
  }

  /// Returns true if the course is free (no plan required) or
  /// the user has an active subscription for the required plan.
  bool isAccessible(Set<int>? activePlanIds) {
    if (planId == null) return true;
    if (activePlanIds == null) return false;
    return activePlanIds.contains(planId);
  }
}