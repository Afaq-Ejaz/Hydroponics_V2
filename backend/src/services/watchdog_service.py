"""
Device offline watchdog service.

Periodically scans all active devices and raises *critical* alerts for any
that have not reported within the configured
``DEVICE_OFFLINE_THRESHOLD_MINUTES`` window.  A deduplication check prevents
alert flooding: if an unacknowledged offline alert already exists for a
device, a duplicate is not created.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from src.config import get_settings
from src.database import get_supabase_client

logger = logging.getLogger("hydroponics.watchdog")


async def check_device_heartbeats() -> int:
    """Scan active devices and emit offline alerts for stale heartbeats.

    Returns
    -------
    int
        Number of **new** offline alerts created during this run.
    """
    settings = get_settings()
    db = get_supabase_client()
    now_utc = datetime.now(timezone.utc)
    new_alert_count = 0

    # 1. Fetch all active devices
    response = db.table("devices").select("*").eq("is_active", True).execute()
    devices = response.data or []

    for device in devices:
        last_seen_raw = device.get("last_seen")

        # 2. Determine staleness
        is_stale = True
        if last_seen_raw is not None:
            last_seen_dt = _parse_datetime(last_seen_raw)
            elapsed_minutes = (now_utc - last_seen_dt).total_seconds() / 60
            if elapsed_minutes <= settings.DEVICE_OFFLINE_THRESHOLD_MINUTES:
                is_stale = False

        if not is_stale:
            continue

        # 3. Deduplication: check for existing unacknowledged offline alert
        existing = (
            db.table("alerts")
            .select("id")
            .eq("device_id", device["id"])
            .eq("is_acknowledged", False)
            .like("message", "%stopped reporting%")
            .execute()
        )
        if existing.data:
            logger.debug(
                "Skipping duplicate offline alert for device %s", device["id"]
            )
            continue

        # 4. Insert new offline alert
        alert_row = {
            "system_id": device["system_id"],
            "device_id": device["id"],
            "severity": "critical",
            "message": (
                f"Device '{device['name']}' ({device['id']}) has stopped "
                f"reporting. Last seen: {device['last_seen'] or 'never'}."
            ),
            "is_acknowledged": False,
            "created_at": now_utc.isoformat(),
        }
        db.table("alerts").insert(alert_row).execute()
        new_alert_count += 1
        logger.info(
            "Offline alert created for device %s (last_seen: %s)",
            device["id"],
            device["last_seen"],
        )

    return new_alert_count


def _parse_datetime(value: str | datetime) -> datetime:
    """Robustly parse a datetime value from Supabase (ISO string or datetime)."""
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    # Handle ISO-format strings (with or without trailing 'Z')
    raw = value.replace("Z", "+00:00")
    return datetime.fromisoformat(raw)
