/// Represents an authenticated user on the mobile app.
/// Fields are populated from the backend's AuthResponse.userInfo payload.
class AuthUser {
  final int? id;
  final String email;
  final String fullName;
  final String? role;
  final int? planId;
  final int? batchId;
  /// True when the student was created with ONLINE payment and hasn't paid yet.
  /// Drives the post-login redirect to the payment screen.
  final bool paymentRequired;
  final String? paymentMethod; // CASH | ONLINE
  final String? paymentStatus; // PENDING | COMPLETED | FAILED
  final int? amountDue; // paise

  AuthUser({
    this.id,
    required this.email,
    required this.fullName,
    this.role,
    this.planId,
    this.batchId,
    this.paymentRequired = false,
    this.paymentMethod,
    this.paymentStatus,
    this.amountDue,
  });

  /// Builds an [AuthUser] from the nested `user` object in the auth response.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      role: json['role'] as String?,
      planId: json['planId'] is int
          ? json['planId']
          : int.tryParse(json['planId']?.toString() ?? ''),
      batchId: json['batchId'] is int
          ? json['batchId']
          : int.tryParse(json['batchId']?.toString() ?? ''),
      paymentRequired: json['paymentRequired'] == true,
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
      amountDue: json['amountDue'] is int
          ? json['amountDue']
          : int.tryParse(json['amountDue']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role,
      'planId': planId,
      'batchId': batchId,
      'paymentRequired': paymentRequired,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'amountDue': amountDue,
    };
  }

  AuthUser copyWith({
    int? id,
    String? email,
    String? fullName,
    String? role,
    int? planId,
    int? batchId,
    bool? paymentRequired,
    String? paymentMethod,
    String? paymentStatus,
    int? amountDue,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      planId: planId ?? this.planId,
      batchId: batchId ?? this.batchId,
      paymentRequired: paymentRequired ?? this.paymentRequired,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountDue: amountDue ?? this.amountDue,
    );
  }
}
