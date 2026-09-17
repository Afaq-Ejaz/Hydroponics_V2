import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../system/providers/system_provider.dart';
import '../models/hourly_telemetry.dart';

/// Available chart time-window options.
enum ChartTimeRange {
  h24(label: '24h', limit: 24),
  d7(label: '7D', limit: 168),
  d30(label: '30D', limit: 720);

  const ChartTimeRange({required this.label, required this.limit});
  final String label;
  final int limit;
}

/// Category filters matching the Figma design.
enum ChartCategory {
  all(label: 'All'),
  phAndEc(label: 'pH & EC'),
  temperature(label: 'Temperature'),
  environment(label: 'Environment'),
  water(label: 'Water');

  const ChartCategory({required this.label});
  final String label;
}

/// Currently selected time range (defaults to 24 hours).
final chartTimeRangeProvider = StateProvider<ChartTimeRange>((ref) {
  return ChartTimeRange.h24;
});

/// Currently selected category filter chip (defaults to All).
final chartCategoryProvider = StateProvider<ChartCategory>((ref) {
  return ChartCategory.all;
});

/// Fetches hourly rollups from the FastAPI backend for the active system.
final hourlyTelemetryProvider =
    FutureProvider.autoDispose<List<HourlyTelemetry>>((ref) async {
  final systemId = ref.watch(activeSystemIdProvider);
  if (systemId == null) return [];

  final range = ref.watch(chartTimeRangeProvider);

  final url = Uri.parse(
    '${AppConfig.backendBaseUrl}/systems/$systemId/telemetry/hourly?limit=${range.limit}',
  );

  try {
    final response = await http.get(url).timeout(AppConfig.httpTimeout);

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) => HourlyTelemetry.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch telemetry: HTTP ${response.statusCode}');
    }
  } catch (e) {
    // If backend is unreachable or offline, rethrow so UI shows clean retry state
    rethrow;
  }
});
