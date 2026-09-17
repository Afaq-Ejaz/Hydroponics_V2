import 'package:flutter/material.dart';

/// Centralised colour palette extracted from the Figma designs.
///
/// The Figma screens use a clean light theme with green (#2E7D5B) as
/// the primary accent, soft greys for backgrounds, and colour-coded
/// sensor cards.
abstract final class AppColors {
  // ── Brand / Primary ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF2E7D5B);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF1B5E3B);
  static const Color primarySurface = Color(0xFFE8F5E9);

  // ── Backgrounds ───────────────────────────────────────────────────────
  static const Color scaffoldBackground = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color surfaceVariant = Color(0xFFF0F2F5);

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // ── Status ────────────────────────────────────────────────────────────
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Sensor-specific (from Figma card accents) ─────────────────────────
  static const Color sensorPh = Color(0xFF8B5CF6);       // Purple
  static const Color sensorEc = Color(0xFF14B8A6);       // Teal
  static const Color sensorWaterTemp = Color(0xFF06B6D4); // Cyan
  static const Color sensorAirTemp = Color(0xFFF97316);   // Orange
  static const Color sensorHumidity = Color(0xFF0EA5E9);  // Sky blue
  static const Color sensorWaterLevel = Color(0xFF6366F1); // Indigo
  static const Color sensorMoisture = Color(0xFF3B82F6);  // Blue
  static const Color sensorLight = Color(0xFFFACC15);     // Yellow
  static const Color sensorFlow = Color(0xFF0284C7);      // Sky / Water Flow Blue

  // ── Chart accents ─────────────────────────────────────────────────────
  static const Color chartGrid = Color(0xFFE5E7EB);
  static const Color chartTargetLine = Color(0xFF94A3B8);

  // ── Borders / Dividers ────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // ── Bottom Nav ────────────────────────────────────────────────────────
  static const Color navActive = primary;
  static const Color navInactive = Color(0xFF9CA3AF);

  // ── Alert Severity ────────────────────────────────────────────────────
  static const Color alertCritical = Color(0xFFEF4444);
  static const Color alertWarning = Color(0xFFF59E0B);
  static const Color alertInfo = Color(0xFF3B82F6);
}
