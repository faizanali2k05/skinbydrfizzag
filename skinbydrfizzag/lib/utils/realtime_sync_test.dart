import '../services/appointment_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import 'package:flutter/foundation.dart';

/// Test utility to verify real-time synchronization functionality
class RealtimeSyncTester {
  static final AppointmentService _appointmentService = AppointmentService();
  static final ChatService _chatService = ChatService();
  static final NotificationService _notificationService = NotificationService();

  /// Test appointment real-time updates
  static void testAppointmentSync() {
    debugPrint('Testing Appointment Real-time Synchronization...');

    // Listen to all appointments stream
    _appointmentService.getAllAppointmentsStream().listen((appointments) {
      debugPrint(
        'Received ${appointments.length} appointments from real-time stream',
      );
    });
  }

  /// Test chat real-time updates
  static void testChatSync(String adminId) {
    debugPrint('Testing Chat Real-time Synchronization...');

    // Listen to admin conversations
    _chatService.getAdminConversationsStream(adminId).listen((conversations) {
      debugPrint(
        'Received ${conversations.length} conversations from real-time stream',
      );
    });
  }

  /// Test notification real-time updates
  static void testNotificationSync(String userId) {
    debugPrint('Testing Notification Real-time Synchronization...');

    // Listen to user notifications
    _notificationService.getUserNotificationsStream(userId).listen((
      notifications,
    ) {
      debugPrint(
        'Received ${notifications.length} notifications from real-time stream',
      );
    });
  }
}
