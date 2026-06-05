import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/config.dart';

/// Initialize this in main() before running the app.
class SupabaseClientManager {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      // optionally include auth or storage settings
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
