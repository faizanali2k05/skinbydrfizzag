import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_model.dart';

/// Appointment service backed by Supabase `appointments` table
class AppointmentService {
  final _supabase = Supabase.instance.client;

  Stream<List<AppointmentModel>> getUserAppointmentsStream() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return Stream.value([]);
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('scheduled_at', ascending: true)
        .map((event) {
          return event
              .map((e) => AppointmentModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }

  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final data = await _supabase
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .single();
      return AppointmentModel.fromMap(data, data['id'] as String);
    } catch (e) {
      return null;
    }
  }

  Future<String?> bookAppointment({
    required String procedureId,
    required String procedureName,
    required String appointmentDate,
    required String appointmentTime,
    String notes = '',
    String userName = '',
    int sessionNumber = 1,
    int visitNumber = 1,
    String clinicLocation = '',
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 'Not authenticated';
    try {
      await _supabase.from('appointments').insert({
        'user_id': uid,
        'user_name': userName,
        'procedure_id': procedureId,
        'procedure_name': procedureName,
        'scheduled_at': '$appointmentDate $appointmentTime',
        'notes': notes,
        'status': 'pending',
        'session_number': sessionNumber,
        'visit_number': visitNumber,
        'clinic_location': clinicLocation,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<List<AppointmentModel>> getAllAppointmentsStream() {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .order('scheduled_at', ascending: true)
        .map((event) {
          return event
              .map((e) => AppointmentModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }

  Stream<List<AppointmentModel>> getAppointmentsByStatusStream(String status) {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('status', status)
        .order('scheduled_at', ascending: true)
        .map((event) {
          return event
              .map((e) => AppointmentModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }

  Future<String?> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    try {
      await _supabase
          .from('appointments')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', appointmentId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateAppointmentNotes({
    required String appointmentId,
    required String notes,
  }) async {
    try {
      await _supabase
          .from('appointments')
          .update({
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', appointmentId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cancelAppointment(String appointmentId) async {
    return updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'cancelled',
    );
  }

  Future<String?> rescheduleAppointment(
    String appointmentId,
    String newDate,
    String newTime,
    String? oldScheduledAt,
  ) async {
    final scheduledAt = '$newDate $newTime';
    try {
      await _supabase
          .from('appointments')
          .update({
            'scheduled_at': scheduledAt,
            'original_scheduled_at': oldScheduledAt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', appointmentId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteAppointment(String appointmentId) async {
    try {
      await _supabase.from('appointments').delete().eq('id', appointmentId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<AppointmentModel>> getAllAppointments() async {
    try {
      final List<dynamic> data = await _supabase
          .from('appointments')
          .select()
          .order('scheduled_at', ascending: true);
      return data
          .map((e) => AppointmentModel.fromMap(e, e['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AppointmentModel>> getUserAppointments(String userId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('appointments')
          .select()
          .eq('user_id', userId)
          .order('scheduled_at', ascending: true);
      return data
          .map((e) => AppointmentModel.fromMap(e, e['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> assignAppointment({
    required String userId,
    required String userName,
    required String procedureId,
    required String procedureName,
    required String appointmentDate,
    required String appointmentTime,
    String notes = '',
    int sessionNumber = 1,
    int visitNumber = 1,
    String clinicLocation = '',
  }) async {
    try {
      await _supabase.from('appointments').insert({
        'user_id': userId,
        'user_name': userName,
        'procedure_id': procedureId,
        'procedure_name': procedureName,
        'scheduled_at': '$appointmentDate $appointmentTime',
        'notes': notes,
        'status': 'confirmed',
        'session_number': sessionNumber,
        'visit_number': visitNumber,
        'clinic_location': clinicLocation,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }


  Future<AppointmentModel?> getAppointment(String appointmentId) async {
    return getAppointmentById(appointmentId);
  }
}
