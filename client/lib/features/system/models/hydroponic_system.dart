/// Data model for a hydroponic system the user belongs to.
///
/// Mapped from a Supabase join of `system_members` → `hydroponic_systems`.
class HydroponicSystem {
  const HydroponicSystem({
    required this.id,
    required this.name,
    required this.role,
    this.description,
  });

  final String id;
  final String name;
  final String role; // 'owner', 'operator', 'viewer'
  final String? description;

  /// Parse from the Supabase join response shape:
  /// ```json
  /// {
  ///   "system_id": "uuid",
  ///   "role": "owner",
  ///   "hydroponic_systems": { "id": "uuid", "name": "My Farm", "description": "..." }
  /// }
  /// ```
  factory HydroponicSystem.fromMembershipRow(Map<String, dynamic> row) {
    final system = row['hydroponic_systems'] as Map<String, dynamic>;
    return HydroponicSystem(
      id: system['id'] as String,
      name: system['name'] as String,
      role: row['role'] as String,
      description: system['description'] as String?,
    );
  }

  @override
  String toString() =>
      'HydroponicSystem(id: $id, name: $name, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydroponicSystem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
