class PlacementDriveModel {
  final int id;
  final String companyName;
  final String? companyLogoUrl;
  final String role;
  final double? packageAmount;
  final String? location;
  final String? eligibility;
  final String? description;
  final String? applyLink;
  final String? deadline;
  final bool? isActive;
  final int? planId;
  final String driveType;
  final double? minAttendancePercent;
  final double? minCourseCompletionPercent;
  final double? minAssignmentAvgPercent;
  final double? minExamAvgPercent;

  PlacementDriveModel({
    required this.id,
    required this.companyName,
    this.companyLogoUrl,
    required this.role,
    this.packageAmount,
    this.location,
    this.eligibility,
    this.description,
    this.applyLink,
    this.deadline,
    this.isActive,
    this.planId,
    this.driveType = 'EXTERNAL',
    this.minAttendancePercent,
    this.minCourseCompletionPercent,
    this.minAssignmentAvgPercent,
    this.minExamAvgPercent,
  });

  bool get isInternal => driveType == 'INTERNAL';

  /// True when the admin has supplied a company logo image URL to show.
  bool get hasCompanyLogo => (companyLogoUrl ?? '').trim().isNotEmpty;

  factory PlacementDriveModel.fromJson(Map<String, dynamic> json) {
    return PlacementDriveModel(
      id: json['id'] ?? 0,
      companyName: json['companyName'] ?? '',
      companyLogoUrl: json['companyLogoUrl'],
      role: json['role'] ?? '',
      packageAmount: (json['packageAmount'] is int)
          ? (json['packageAmount'] as int).toDouble()
          : json['packageAmount']?.toDouble(),
      location: json['location'],
      eligibility: json['eligibility'],
      description: json['description'],
      applyLink: json['applyLink'],
      deadline: json['deadline'],
      isActive: json['isActive'],
      planId: json['planId'],
      driveType: json['driveType'] ?? 'EXTERNAL',
      minAttendancePercent: (json['minAttendancePercent'] as num?)?.toDouble(),
      minCourseCompletionPercent: (json['minCourseCompletionPercent'] as num?)?.toDouble(),
      minAssignmentAvgPercent: (json['minAssignmentAvgPercent'] as num?)?.toDouble(),
      minExamAvgPercent: (json['minExamAvgPercent'] as num?)?.toDouble(),
    );
  }

  /// True when the drive defines at least one eligibility threshold.
  bool get hasCriteria =>
      minAttendancePercent != null ||
      minCourseCompletionPercent != null ||
      minAssignmentAvgPercent != null ||
      minExamAvgPercent != null;

  /// Evaluates the drive's minimum criteria against the student's metrics
  /// (all expressed as percentages). A criterion that is null is not enforced.
  /// Returns false when criteria exist but cannot be verified (missing metrics).
  bool isEligibleFor(Map<String, double> metrics) {
    if (!hasCriteria) return true;

    final attendance = metrics['attendancePercentage'];
    if (minAttendancePercent != null &&
        (attendance == null || attendance < minAttendancePercent!)) {
      return false;
    }

    final courseCompletion = metrics['courseCompletionPercentage'];
    if (minCourseCompletionPercent != null &&
        (courseCompletion == null || courseCompletion < minCourseCompletionPercent!)) {
      return false;
    }

    final assignmentAvg = metrics['assignmentAveragePercentage'];
    if (minAssignmentAvgPercent != null &&
        (assignmentAvg == null || assignmentAvg < minAssignmentAvgPercent!)) {
      return false;
    }

    final examAvg = metrics['examAveragePercentage'];
    if (minExamAvgPercent != null &&
        (examAvg == null || examAvg < minExamAvgPercent!)) {
      return false;
    }

    return true;
  }

  String get packageDisplay {
    final p = packageAmount;
    if (p == null) return 'N/A';
    if (p >= 10000000) return '₹${(p / 10000000).toStringAsFixed(1)} Cr';
    if (p >= 100000) return '₹${(p / 100000).toStringAsFixed(1)} LPA';
    return '₹${p.toStringAsFixed(0)}';
  }

  String get logoInitial => companyName.isNotEmpty ? companyName[0].toUpperCase() : '?';

  String get category {
    final roleLower = role.toLowerCase();
    if (roleLower.contains('software') || roleLower.contains('developer') || roleLower.contains('engineer')) return 'IT';
    if (roleLower.contains('embedded') || roleLower.contains('hardware')) return 'Core';
    if (roleLower.contains('product')) return 'Product';
    return 'Service';
  }

  String get formattedDeadline {
    final d = deadline;
    if (d == null || d.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}