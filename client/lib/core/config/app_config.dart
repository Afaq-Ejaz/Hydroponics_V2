/// App-wide configuration constants.
///
/// All environment-specific values live here so switching between
/// development / staging / production is a single-file change.
class AppConfig {
  AppConfig._(); // prevent instantiation

  // ── Supabase ──────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://vijkujtwbotqcnoviodd.supabase.co';

  /// The **anon (public)** key — safe to embed in client apps.
  /// It respects RLS policies. NEVER use the service_role key here.
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpamt1anR3Ym90cWNub3Zpb2RkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NzQxMDIsImV4cCI6MjEwNDM1MDEwMn0.QEgIkflqqrx6rxe-jwZ88de458TyoJD3FmA8aj1ND34';

  // ── FastAPI Backend ───────────────────────────────────────────────────
  /// Base URL for REST API calls. When debugging on a physical device,
  /// this must be the LAN IP of the machine running the backend.
  static const String backendBaseUrl = 'http://10.9.26.152:8000';

  // ── Timeouts ──────────────────────────────────────────────────────────
  static const Duration httpTimeout = Duration(seconds: 15);

  // ── Device Health ─────────────────────────────────────────────────────
  static const int deviceOfflineThresholdMinutes = 5;
  static const Duration deviceStatusPollInterval = Duration(seconds: 60);
}
