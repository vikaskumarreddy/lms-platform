class CourseSection {
  final int id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final int totalLessons;
  final int completedLessons;
  final bool isLocked;

  CourseSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.isLocked = false,
  });

  factory CourseSection.fromJson(Map<String, dynamic> json) {
    return CourseSection(
      id: _safeInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      totalLessons: _safeInt(json['totalLessons']),
      completedLessons: _safeInt(json['completedLessons']),
      isLocked: json['isLocked'] == true || json['locked'] == true,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'color': color,
        'totalLessons': totalLessons,
        'completedLessons': completedLessons,
        'isLocked': isLocked,
      };
}
