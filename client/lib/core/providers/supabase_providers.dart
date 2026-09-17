import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the Supabase client instance throughout the app.
///
/// This is a simple non-disposable provider — the client lives for the
/// entire app lifetime.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provides a **stream** of auth state changes.
///
/// Widgets or other providers that depend on this will automatically
/// rebuild whenever the user signs in, signs out, or the token refreshes.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Provides the current [Session], or `null` if not authenticated.
///
/// This is derived from [authStateChangesProvider] so it's always in sync
/// with the latest auth state.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.whenOrNull(data: (state) => state.session);
});

/// Provides the current [User], or `null` if not authenticated.
final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session?.user;
});

/// Whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});
