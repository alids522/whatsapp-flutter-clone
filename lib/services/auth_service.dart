import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

/// Username + password auth — HARD REQUIREMENT (confirmed):
/// * The UI asks for username and password ONLY. No email field,
///   no phone field, no extra step.
/// * After tapping Sign Up the user goes straight into the app
///   (the chats list). There is no email-verification screen and
///   no "check your inbox" blocker.
/// * Supabase Auth itself is email-based under the hood, so a
///   username is mapped to a derived email (username@chat.local).
///   That derived email is never shown to the user.
/// * If Supabase returns a user with no session (email confirmation
///   is ON on the server), this code immediately signs the user in
///   with the same username/password. Only if that sign-in fails
///   is a clear in-app error shown.
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Normalised username: lower-cased, trimmed.
  /// Valid usernames: 3-20 chars, letters, digits, dot, underscore, dash.
  static String normalizeUsername(String raw) => raw.trim().toLowerCase();

  static String? validateUsername(String raw) {
    final username = normalizeUsername(raw);
    if (username.length < 3 || username.length > 20) {
      return 'Username must be 3-20 characters.';
    }
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(username)) {
      return 'Use only letters, numbers, dot, underscore or dash.';
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  /// The derived Supabase Auth email for a username. Internal only.
  static String derivedEmail(String username) =>
      '${normalizeUsername(username)}@${AppConfig.authEmailDomain}';

  /// Check the profiles table for a taken username BEFORE signup.
  /// Returns true when the username is already taken.
  ///
  /// The schema grants SELECT on profiles to anon (profiles hold no
  /// secrets — only id, username, display name, avatar URL), precisely
  /// so this pre-signup check and user search can work.
  static Future<bool> isUsernameTaken(String username) async {
    final name = normalizeUsername(username);
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', name)
        .maybeSingle();
    return row != null;
  }

  static Future<void> _ensureProfile(String userId, String username) async {
    final name = normalizeUsername(username);
    await _client.from('profiles').upsert({
      'id': userId,
      'username': name,
      'display_name': name,
    });
  }

  static bool _looksLikeAlreadyRegistered(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('user already') ||
        msg.contains('duplicate key');
  }

  /// Sign up with username + password only.
  /// On success the caller can rely on a live session: this method
  /// throws if no session could be established.
  static Future<void> signUpWithUsername({
    required String username,
    required String password,
  }) async {
    final name = normalizeUsername(username);

    // 1. Username must be unique — check before creating the account.
    if (await isUsernameTaken(name)) {
      throw const AuthException('username already taken');
    }

    final email = derivedEmail(name);
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': name},
      );

      var user = res.user;
      var session = res.session;

      // 2. Email confirmation ON => signUp returns a user but NO session.
      //    Do NOT show a "check your inbox" blocker. Sign in at once
      //    with the exact same credentials.
      if (session == null && user != null) {
        try {
          final signIn = await _client.auth.signInWithPassword(
            email: email,
            password: password,
          );
          user = signIn.user;
          session = signIn.session;
        } on AuthException {
          throw const AuthException(
            'Account was created, but automatic sign-in was blocked. '
            'On your Supabase server, turn OFF Auth > Email confirmation, '
            'then log in with the same username and password.',
          );
        }
      }

      if (session == null || user == null) {
        throw const AuthException(
          'Sign-up did not return a session. On your Supabase server, '
          'turn OFF Auth > Email confirmation, then try logging in.',
        );
      }

      // 3. Create the profile row (unique constraint is a second guard
      //    against a race between the check above and this insert).
      try {
        await _ensureProfile(user.id, name);
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          throw const AuthException('username already taken');
        }
        rethrow;
      }
    } on AuthException catch (e) {
      if (_looksLikeAlreadyRegistered(e)) {
        throw const AuthException('username already taken');
      }
      rethrow;
    }
  }

  /// Login uses the exact same username + password fields as signup.
  static Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final name = normalizeUsername(username);
    final res = await _client.auth.signInWithPassword(
      email: derivedEmail(name),
      password: password,
    );
    final user = res.user;
    if (user != null) {
      // Heal a missing profile row (e.g. created before profiles existed).
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        try {
          await _ensureProfile(user.id, name);
        } catch (_) {
          // Login itself succeeded; a profile can be created on next launch.
        }
      }
    }
  }

  static Future<void> signOut() => _client.auth.signOut();

  static Future<String?> currentUsername() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    return row?['username'] as String?;
  }
}
