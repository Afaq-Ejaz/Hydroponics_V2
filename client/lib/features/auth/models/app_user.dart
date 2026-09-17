/// Lightweight user model decoupled from Supabase's [User] type.
///
/// This lets the rest of the app work with a clean data class.
/// If the auth provider changes in the future, only the factory
/// constructor needs updating.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
  });

  final String id;
  final String email;
  final String? fullName;

  /// Create from a Supabase [User] object's metadata.
  factory AppUser.fromSupabaseUser({
    required String id,
    required String email,
    Map<String, dynamic>? userMetadata,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: userMetadata?['full_name'] as String?,
    );
  }

  @override
  String toString() => 'AppUser(id: $id, email: $email, fullName: $fullName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
