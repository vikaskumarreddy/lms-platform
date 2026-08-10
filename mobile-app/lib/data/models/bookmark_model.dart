class BookmarkModel {
  final int id;
  final int lessonId;
  final String lessonTitle;
  final String lessonType;
  final String? courseName;
  final String bookmarkedAt;

  BookmarkModel({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonType,
    this.courseName,
    required this.bookmarkedAt,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      lessonId: json['lessonId'] is int ? json['lessonId'] : int.tryParse(json['lessonId'].toString()) ?? 0,
      lessonTitle: json['lessonTitle']?.toString() ?? '',
      lessonType: json['lessonType']?.toString() ?? 'Lesson',
      courseName: json['courseName']?.toString(),
      bookmarkedAt: json['bookmarkedAt']?.toString() ?? '',
    );
  }
}