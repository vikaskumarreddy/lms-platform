/// Represents an authenticated user on the mobile app.
/// Fields are populated from the backend's AuthResponse.userInfo payload.
class AuthUser {
  final int? id;
  final String email;
  final String fullName;
  final String? role;
  final int? planId;
  final int? batchId;

  AuthUser({
    this.id,
    required this.email,
    required this.fullName,
    this.role,
    this.planId,
    this.batchId,
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
    };
  }
}
