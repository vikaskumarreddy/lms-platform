class PlacementDriveModel {
  final int id;
  final String companyName;
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

  PlacementDriveModel({
    required this.id,
    required this.companyName,
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
  });

  bool get isInternal => driveType == 'INTERNAL';

  factory PlacementDriveModel.fromJson(Map<String, dynamic> json) {
    return PlacementDriveModel(
      id: json['id'] ?? 0,
      companyName: json['companyName'] ?? '',
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
    );
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