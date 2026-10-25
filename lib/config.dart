// App configuration for the self-hosted Supabase instance.
//
// The anon key below is publishable by design (Supabase "anon public" key).
// It is NOT the service_role key. Never put a service_role key in an app:
// it bypasses Row Level Security and must never ship in an APK.
class AppConfig {
  static const String supabaseUrl = 'https://supabase.adoetz52.my.id';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE3ODE0MjkzOTMsImV4cCI6MjA4Mjc1ODQwMH0.qgQ3hxL9JgRhZ-0vuIAG-myu8w5UeWkG1iNrsjqDvR0';

  /// Domain used only to map a username to a Supabase Auth account.
  /// The user never sees this: the UI asks for username + password only.
  static const String authEmailDomain = 'chat.local';

  static const String storageBucket = 'chat-media';
}
