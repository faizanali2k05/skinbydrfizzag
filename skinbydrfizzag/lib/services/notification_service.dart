import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

/// Notification service backed by Supabase `notifications` table
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  Stream<List<NotificationModel>> getUserNotificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((event) {
      return event
          .map((e) => NotificationModel.fromMap(e, e['id'] as String))
          .toList();
    });
  }

  Stream<List<NotificationModel>> getAdminNotificationsStream() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((event) {
      return event
          .map((e) => NotificationModel.fromMap(e, e['id'] as String))
          .toList();
    });
  }

  Stream<int> getUnreadCountStream(String userId) {
    return getUserNotificationsStream(userId).map((list) {
      return list.where((n) => !n.isRead).length;
    });
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<String?> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? appointmentId,
    String? conversationId,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'appointment_id': appointmentId,
        'conversation_id': conversationId,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void startListeningForAppointments(String userId) {
    // UI components handle this via getUserNotificationsStream
  }

  void startListeningForChat(String userId) {
    // UI components handle this via getUserNotificationsStream
  }

  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required String procedureName,
    required DateTime appointmentDate,
  }) async {
    // Implementation for local notifications
  }

  Future<void> cancelAppointmentNotifications(String appointmentId) async {
    // Implementation for local notifications
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    // Implementation for local notifications
  }
}
