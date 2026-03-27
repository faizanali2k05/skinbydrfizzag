class AppointmentModel {
  final String id;
  final String userId;
  final String userName; // Added userName
  final String doctorId;
  final String procedureId;
  final String procedureName;
  final String appointmentDate; // YYYY-MM-DD
  final String appointmentTime; // HH:mm
  final String status; // 'pending','confirmed','completed','cancelled'
  final String notes;
  final String adminNotes;
  final int sessionNumber; // Added sessionNumber
  final int visitNumber; // Added visitNumber
  final String clinicLocation; // Added clinicLocation
  final String? originalScheduledAt; // Added originalScheduledAt for reschedules
  final DateTime? createdAt;
  final DateTime? updatedAt;
  String get scheduledAt => '$appointmentDate $appointmentTime';


  AppointmentModel({
    required this.id,
    required this.userId,
    this.userName = '',
    this.doctorId = '',
    required this.procedureId,
    required this.procedureName,
    required this.appointmentDate,
    required this.appointmentTime,
    this.status = 'pending',
    this.notes = '',
    this.adminNotes = '',
    this.sessionNumber = 1,
    this.visitNumber = 1,
    this.clinicLocation = '',
    this.originalScheduledAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Empty convenience constructor used by callers that need a sentinel value
  factory AppointmentModel.empty() {
    return AppointmentModel(
      id: '',
      userId: '',
      userName: '',
      doctorId: '',
      procedureId: '',
      procedureName: '',
      appointmentDate: '',
      appointmentTime: '',
      status: 'pending',
      notes: '',
      adminNotes: '',
      sessionNumber: 1,
      visitNumber: 1,
      clinicLocation: '',
      originalScheduledAt: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  /// Convert to Map (only include DB columns)
  Map<String, dynamic> toMap() {
    final scheduled = '$appointmentDate $appointmentTime';
    return {
      'user_id': userId,
      'user_name': userName,
      'procedure_id': procedureId.isEmpty ? null : procedureId,
      'procedure_name': procedureName,
      'scheduled_at': scheduled,
      'status': status,
      'notes': notes,
      'admin_notes': adminNotes,
      'session_number': sessionNumber,
      'visit_number': visitNumber,
      'clinic_location': clinicLocation,
      'original_scheduled_at': originalScheduledAt,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  /// Create from Map
  factory AppointmentModel.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime? scheduledAt;
    if (data['scheduled_at'] is DateTime) {
      scheduledAt = data['scheduled_at'] as DateTime;
    } else if (data['scheduled_at'] is String && (data['scheduled_at'] as String).isNotEmpty) {
      try {
        scheduledAt = DateTime.parse(data['scheduled_at'] as String);
      } catch (_) {}
    }

    String date = '';
    String time = '';
    if (scheduledAt != null) {
      final iso = scheduledAt.toIso8601String();
      final parts = iso.split('T');
      date = parts[0];
      time = parts.length > 1 ? parts[1].split('.').first : '';
    } else {
      final scheduled = data['scheduled_at'] ?? '';
      if (scheduled is String && scheduled.contains(' ')) {
        final parts = scheduled.split(' ');
        date = parts[0];
        time = parts[1];
      }
    }

    return AppointmentModel(
      id: documentId,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      doctorId: data['doctor_id'] ?? '',
      procedureId: data['procedure_id'] ?? '',
      procedureName: data['procedure_name'] ?? '',
      appointmentDate: date,
      appointmentTime: time,
      status: data['status'] ?? 'pending',
      notes: data['notes'] ?? '',
      adminNotes: data['admin_notes'] ?? '',
      sessionNumber: data['session_number'] ?? 1,
      visitNumber: data['visit_number'] ?? 1,
      clinicLocation: data['clinic_location'] ?? '',
      originalScheduledAt: data['original_scheduled_at'],
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'].toString()) : null,
      updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'].toString()) : null,
    );
  }

  /// CopyWith method
  AppointmentModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? doctorId,
    String? procedureId,
    String? procedureName,
    String? appointmentDate,
    String? appointmentTime,
    String? status,
    String? notes,
    String? adminNotes,
    int? sessionNumber,
    int? visitNumber,
    String? clinicLocation,
    String? originalScheduledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      doctorId: doctorId ?? this.doctorId,
      procedureId: procedureId ?? this.procedureId,
      procedureName: procedureName ?? this.procedureName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      adminNotes: adminNotes ?? this.adminNotes,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      visitNumber: visitNumber ?? this.visitNumber,
      clinicLocation: clinicLocation ?? this.clinicLocation,
      originalScheduledAt: originalScheduledAt ?? this.originalScheduledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AppointmentModel(id: $id, userId: $userId, userName: $userName, procedureName: $procedureName, date: $appointmentDate)';
}