class UserModel {
  final String uid;
  final String name;
  final String displayName;
  final String email;
  final String phone;
  final String phoneNumber;
  final String role; // 'user' or 'admin'
  final String photoUrl;
  final String status;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    this.displayName = '',
    required this.email,
    required this.phone,
    this.phoneNumber = '',
    this.role = 'user',
    this.photoUrl = '',
    this.status = 'active',
    this.createdAt,
  });

  /// Convert UserModel to Map
  Map<String, dynamic> toMap() {
    return {
      'full_name': name,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'phone_number': phoneNumber,
      'role': role,
      'photo_url': photoUrl,
      'status': status,
      'created_at': createdAt ?? DateTime.now(),
    };
  }

  /// Create UserModel from Map
  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      name: data['full_name'] ?? data['name'] ?? '',
      displayName: data['display_name'] ?? data['displayName'] ?? data['full_name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      phoneNumber: data['phone_number'] ?? data['phoneNumber'] ?? data['phone'] ?? '',
      role: data['role'] ?? 'user',
      photoUrl: data['photo_url'] ?? data['photoUrl'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: data['created_at'] != null
          ? (data['created_at'] is DateTime
              ? data['created_at'] as DateTime
              : DateTime.tryParse(data['created_at'].toString()))
          : null,
    );
  }

  /// CopyWith method for immutability
  UserModel copyWith({
    String? uid,
    String? name,
    String? displayName,
    String? email,
    String? phone,
    String? phoneNumber,
    String? role,
    String? photoUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, email: $email, role: $role)';
}
