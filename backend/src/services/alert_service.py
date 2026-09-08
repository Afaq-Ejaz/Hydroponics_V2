"""
Alert evaluation service.

After every sensor reading is persisted the alert service checks configured
thresholds and inserts ``critical`` / ``warning`` alerts into the ``alerts``
table so that Supabase Realtime can push them to subscribed Flutter clients
immediately.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from supabase import Client

from src.config import get_settings


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def evaluate_alerts(
    readings: dict,
    device_id: str,
    system_id: str,
    db: Client,
) -> list[dict]:
    """Check *readings* against configured thresholds and persist any alerts.

    Parameters
    ----------
    readings : dict
        Flat dict of sensor values (``None``-valued keys are skipped).
    device_id : str
        Originating device identifier.
    system_id : str
        UUID of the hydroponic system this reading belongs to.
    db : Client
        Supabase client with service-role privileges.

    Returns
    -------
    list[dict]
        Alert rows that were inserted (empty list when everything is nominal).
    """
    settings = get_settings()
    alerts: list[dict] = []

    # ── pH ───────────────────────────────────────────────────────────
    ph = readings.get("ph")
    if ph is not None:
        if ph < settings.ALERT_PH_MIN:
            alerts.append(
                _build_alert(
                    system_id,
                    device_id,
                    "critical",
                    f"pH too low: {ph:.2f} (min {settings.ALERT_PH_MIN})",
                )
            )
        elif ph > settings.ALERT_PH_MAX:
            alerts.append(
                _build_alert(
                    system_id,
                    device_id,
                    "critical",
                    f"pH too high: {ph:.2f} (max {settings.ALERT_PH_MAX})",
                )
            )

    # ── Water temperature ────────────────────────────────────────────
    water_temp = readings.get("water_temperature")
    if water_temp is not None:
        if water_temp > settings.ALERT_WATER_TEMP_MAX:
            alerts.append(
                _build_alert(
                    system_id,
                    device_id,
                    "warning",
                    f"Water temperature too high: {water_temp:.1f}°C "
                    f"(max {settings.ALERT_WATER_TEMP_MAX}°C)",
                )
            )
        elif water_temp < settings.ALERT_WATER_TEMP_MIN:
            alerts.append(
                _build_alert(
                    system_id,
                    device_id,
                    "warning",
                    f"Water temperature too low: {water_temp:.1f}°C "
                    f"(min {settings.ALERT_WATER_TEMP_MIN}°C)",
                )
            )

    # ── Persist ──────────────────────────────────────────────────────
    if alerts:
        db.table("alerts").insert(alerts).execute()

    return alerts


def _build_alert(
    system_id: str,
    device_id: str,
    severity: str,
    message: str,
) -> dict:
    """Construct an alert row dict ready for Supabase insertion."""
    return {
        "id": str(uuid.uuid4()),
        "system_id": system_id,
        "device_id": device_id,
        "severity": severity,
        "message": message,
        "is_acknowledged": False,
        "created_at": _utc_now().isoformat(),
    }
