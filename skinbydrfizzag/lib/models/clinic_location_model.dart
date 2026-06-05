class ClinicLocationModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String mapUrl;
  final int sortOrder;
  final bool isActive;

  const ClinicLocationModel({
    required this.id,
    required this.name,
    required this.address,
    this.phone = '',
    this.email = '',
    this.mapUrl = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  String get displayLabel {
    if (name.trim().isEmpty) return address;
    if (address.trim().isEmpty) return name;
    return '$name - $address';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'map_url': mapUrl.trim(),
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  factory ClinicLocationModel.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return ClinicLocationModel(
      id: documentId,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      mapUrl: data['map_url'] ?? data['mapUrl'] ?? '',
      sortOrder: data['sort_order'] ?? data['sortOrder'] ?? 0,
      isActive: data['is_active'] ?? data['isActive'] ?? true,
    );
  }
}
