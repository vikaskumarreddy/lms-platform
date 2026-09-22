class QuestionModel {
  final int id;
  final String title;
  final String content;
  final String category;
  final String authorName;
  final bool isAnswered;
  final int answerCount;
  final int viewCount;
  final int voteCount;
  final int? planId;
  final int? batchId;
  final int? userId;
  final bool isEscalated;
  final bool isAiAnswered;
  final String? createdAt;
  final String? updatedAt;

  QuestionModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorName,
    required this.isAnswered,
    required this.answerCount,
    required this.viewCount,
    required this.voteCount,
    this.planId,
    this.batchId,
    this.userId,
    this.isEscalated = false,
    this.isAiAnswered = false,
    this.createdAt,
    this.updatedAt,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: _safeInt(json['id']),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      authorName: json['authorName']?.toString() ?? json['author']?.toString() ?? 'Anonymous',
      isAnswered: json['isAnswered'] == true,
      answerCount: _safeInt(json['answerCount']),
      viewCount: _safeInt(json['viewCount']),
      voteCount: _safeInt(json['voteCount']),
      planId: json['planId'] != null ? _safeInt(json['planId']) : null,
      batchId: json['batchId'] != null ? _safeInt(json['batchId']) : null,
      userId: json['userId'] != null ? _safeInt(json['userId']) : null,
      isEscalated: json['isEscalated'] == true,
      isAiAnswered: json['isAiAnswered'] == true,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'authorName': authorName,
      'isAnswered': isAnswered,
      'answerCount': answerCount,
      'viewCount': viewCount,
      'voteCount': voteCount,
      'planId': planId,
      'batchId': batchId,
      'userId': userId,
      'isEscalated': isEscalated,
      'isAiAnswered': isAiAnswered,
    };
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  QuestionModel copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    String? authorName,
    bool? isAnswered,
    int? answerCount,
    int? viewCount,
    int? voteCount,
    int? planId,
    int? batchId,
    int? userId,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      authorName: authorName ?? this.authorName,
      isAnswered: isAnswered ?? this.isAnswered,
      answerCount: answerCount ?? this.answerCount,
      viewCount: viewCount ?? this.viewCount,
      voteCount: voteCount ?? this.voteCount,
      planId: planId ?? this.planId,
      batchId: batchId ?? this.batchId,
      userId: userId ?? this.userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class AnswerModel {
  final int id;
  final String content;
  final String authorName;
  final bool isAccepted;
  final int voteCount;
  final int? userId;
  final int questionId;
  final bool isAiGenerated;
  final String? createdAt;
  final String? updatedAt;

  AnswerModel({
    required this.id,
    required this.content,
    required this.authorName,
    required this.isAccepted,
    required this.voteCount,
    this.userId,
    required this.questionId,
    this.isAiGenerated = false,
    this.createdAt,
    this.updatedAt,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      id: _safeInt(json['id']),
      content: json['content']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? json['author']?.toString() ?? 'Anonymous',
      isAccepted: json['isAccepted'] == true,
      voteCount: _safeInt(json['voteCount']),
      userId: json['userId'] != null ? _safeInt(json['userId']) : null,
      questionId: _safeInt(json['questionId'] ?? json['question_id']),
      isAiGenerated: json['isAiGenerated'] == true || (json['authorName']?.toString() ?? '').contains('AI'),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'authorName': authorName,
      'isAccepted': isAccepted,
      'voteCount': voteCount,
      'userId': userId,
      'questionId': questionId,
      'isAiGenerated': isAiGenerated,
    };
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}