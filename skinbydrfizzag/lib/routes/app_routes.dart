import 'package:flutter/material.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/auth/password_recovery_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/procedures/procedures_list_screen.dart';
import '../screens/chat/unified_chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/admin/simple_admin_screen.dart';
import '../screens/appointments/appointments_list_screen.dart';
import '../screens/appointments/book_appointment_screen.dart';
import '../screens/profile/about_us_screen.dart';


class AppRoutes {
  // The welcome route is now handled by the AuthWrapper, so it's removed from here.
  static const String signIn = '/sign_in';
  static const String signUp = '/sign_up';
  static const String passwordRecovery = '/password_recovery';
  static const String home = '/home';
  static const String procedures = '/procedures';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String adminPanel = '/admin_panel';
  static const String appointments = '/appointments';
  static const String bookAppointment = '/book_appointment';
  static const String aboutUs = '/about_us';


  static Map<String, WidgetBuilder> get routes => {
    signIn: (context) => const SignInScreen(),
    signUp: (context) => const SignUpScreen(),
    passwordRecovery: (context) => const PasswordRecoveryScreen(),
    home: (context) => const HomeScreen(),
    procedures: (context) => const ProceduresListScreen(),
    chat: (context) => const UnifiedChatScreen(),
    profile: (context) => const ProfileScreen(),
    adminPanel: (context) => const SimpleAdminScreen(),
    appointments: (context) => const AppointmentsListScreen(),
    bookAppointment: (context) => const BookAppointmentScreen(),
    aboutUs: (context) => const AboutUsScreen(),

  };
}