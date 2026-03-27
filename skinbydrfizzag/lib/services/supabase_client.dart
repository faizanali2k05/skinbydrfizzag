import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialize this in main() before running the app.
class SupabaseClientManager {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://lewjpfvgeresrloigzyi.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxld2pwZnZnZXJlc3Jsb2lnenlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0NjUxMjMsImV4cCI6MjA4ODA0MTEyM30.W4A5I_2D7WtP2Tw8tz_3GjYHR2JFehTp7GSKKsMwLL8',
      // optionally include auth or storage settings
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
