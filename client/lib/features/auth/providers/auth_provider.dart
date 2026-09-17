import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';

/// Auth state — holds the current session or null.
///
/// Uses [AsyncNotifier] for clean loading / error / data states.
/// The router watches this provider to redirect between login and app shell.
class AuthNotifier extends AsyncNotifier<Session?> {
  late final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSub;

  @override
  FutureOr<Session?> build() {
    _client = ref.read(supabaseClientProvider);

    // Listen for auth changes and update state
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      state = AsyncData(data.session);
    });

    // Dispose subscription when provider is disposed
    ref.onDispose(() => _authSub?.cancel());

    // Return current session (may be null if not logged in)
    return _client.auth.currentSession;
  }

  /// Sign in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session;
    });
  }

  /// Create a new account with email, password, and full name.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return response.session;
    });
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signOut();
      return null;
    });
  }
}

/// Global provider for auth state.
///
/// Watched by the router to redirect between login ↔ app shell.
final authProvider =
    AsyncNotifierProvider<AuthNotifier, Session?>(AuthNotifier.new);
