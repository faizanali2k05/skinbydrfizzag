/// Centralized runtime configuration.
///
/// Every value can be overridden at build time with `--dart-define`, e.g.
///   flutter build apk --dart-define=BACKEND_BASE_URL=https://staging.example.com
///
/// The defaults match the current production deployment so existing builds
/// keep working without any extra flags, while staging / future environments
/// can be pointed elsewhere without touching source.
class AppConfig {
  AppConfig._();

  /// Base URL of the Flask backend (AI chat, WhatsApp relay, admin APIs).
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://skinbydrfizzag.onrender.com',
  );

  /// Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lewjpfvgeresrloigzyi.supabase.co',
  );

  /// Supabase anon (publishable) key — designed to be shipped in clients;
  /// row-level security, not secrecy, protects the data.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxld2pwZnZnZXJlc3Jsb2lnenlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0NjUxMjMsImV4cCI6MjA4ODA0MTEyM30.W4A5I_2D7WtP2Tw8tz_3GjYHR2JFehTp7GSKKsMwLL8',
  );
}
