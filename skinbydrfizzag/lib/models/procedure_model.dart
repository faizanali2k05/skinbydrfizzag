class ProcedureModel {
  final String id;
  final String title;
  final String name;
  final String description;
  final String category;
  final int duration; // in minutes
  final int sessions;
  final int visitsPerSession;
  final List<String> keyFeatures;
  final double price;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProcedureModel({
    required this.id,
    this.title = '',
    required this.name,
    required this.description,
    this.category = 'GENERAL',
    this.duration = 0,
    this.sessions = 1,
    this.visitsPerSession = 1,
    this.keyFeatures = const [],
    this.price = 0.0,
    this.imageUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'name': name,
      'description': description,
      'category': category,
      'duration': duration,
      'sessions': sessions,
      'visits_per_session': visitsPerSession,
      'key_features': keyFeatures,
      'price': price,
      'image_url': imageUrl,
      'created_at': createdAt ?? DateTime.now(),
      'updated_at': updatedAt ?? DateTime.now(),
    };
  }

  /// Create from Map
  factory ProcedureModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ProcedureModel(
      id: documentId,
      title: data['title'] ?? data['name'] ?? '',
      name: data['name'] ?? data['name'] ?? '',
      description: data['description'] ?? data['description'] ?? '',
      category: data['category'] ?? 'GENERAL',
      duration: data['duration'] ?? 0,
      sessions: data['sessions'] ?? 1,
      visitsPerSession: data['visits_per_session'] ?? data['visitsPerSession'] ?? 1,
      keyFeatures: List<String>.from(data['key_features'] ?? data['keyFeatures'] ?? []),
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['image_url'] ?? data['imageUrl'] ?? '',
      createdAt: data['created_at'] is DateTime
          ? data['created_at'] as DateTime
          : null,
      updatedAt: data['updated_at'] is DateTime
          ? data['updated_at'] as DateTime
          : null,
    );
  }

  /// CopyWith method
  ProcedureModel copyWith({
    String? id,
    String? name,
    String? description,
    int? duration,
    double? price,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcedureModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ProcedureModel(id: $id, name: $name, price: $price)';
}