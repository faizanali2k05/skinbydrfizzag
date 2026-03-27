import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_client.dart';
import 'services/auth_service.dart';
import 'services/procedure_service.dart';
import 'services/appointment_service.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseClientManager.initialize();

  // Initialize Firebase (Requires google-services.json / GoogleService-Info.plist)
  try {
    await Firebase.initializeApp();
    await NotificationManager.initialize();
  } catch (e) {
    debugPrint(
      'Firebase initialization failed: $e. Did you add google-services.json?',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        Provider(create: (context) => ProcedureService()),
        Provider(create: (context) => AppointmentService()),
        Provider(create: (context) => ChatService()),
        Provider(create: (context) => NotificationService()),
      ],
      child: const SkinbyFizaApp(),
    ),
  );
}
