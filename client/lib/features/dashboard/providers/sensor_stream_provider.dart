import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../system/providers/system_provider.dart';
import '../models/sensor_reading.dart';

/// Provides a **real-time stream** of the latest sensor reading for the
/// active system.
///
/// Uses Supabase Realtime under the hood — every INSERT into
/// `sensor_readings` for the active system triggers a stream emission.
///
/// Returns `null` while waiting for the first reading.
final sensorStreamProvider =
    StreamProvider.autoDispose<SensorReading?>((ref) {
  final systemId = ref.watch(activeSystemIdProvider);
  if (systemId == null) return const Stream.empty();

  final client = ref.watch(supabaseClientProvider);

  return client
      .from('sensor_readings')
      .stream(primaryKey: ['id'])
      .eq('system_id', systemId)
      .order('recorded_at', ascending: false)
      .limit(1)
      .map((rows) {
        if (rows.isEmpty) return null;
        return SensorReading.fromMap(rows.first);
      });
});

/// Provides the latest sensor reading as a one-shot future (initial load).
///
/// Useful for screens that just need the current value without subscribing
/// to real-time updates (e.g. the charts screen initial state).
final latestReadingProvider =
    FutureProvider.autoDispose<SensorReading?>((ref) async {
  final systemId = ref.watch(activeSystemIdProvider);
  if (systemId == null) return null;

  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('sensor_readings')
      .select()
      .eq('system_id', systemId)
      .order('recorded_at', ascending: false)
      .limit(1);

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;
  return SensorReading.fromMap(rows.first as Map<String, dynamic>);
});
