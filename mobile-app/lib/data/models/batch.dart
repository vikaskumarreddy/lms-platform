class Batch {
  final int id;
  final String name;
  final String? description;
  final int? planId;
  final String? startDate;
  final String? endDate;
  final bool isActive;
  final int? maxStudents;
  final String? schedule;

  Batch({
    required this.id,
    required this.name,
    this.description,
    this.planId,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.maxStudents,
    this.schedule,
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      planId: json['planId'] as int?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      maxStudents: json['maxStudents'] as int?,
      schedule: json['schedule'] as String?,
    );
  }
}