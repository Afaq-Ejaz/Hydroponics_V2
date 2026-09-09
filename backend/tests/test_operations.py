"""
Tests for Phase 4 – Operations & Watchdog.

Covers:
  - Device status endpoint (online / offline / not found)
  - Alert acknowledgment endpoint (success / not found)
  - Watchdog heartbeat checker with deduplication
"""

import uuid
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from src.database import get_supabase_client
from src.main import app
from src.services.watchdog_service import check_device_heartbeats

client = TestClient(app)

VALID_DEVICE_ID = "ESP32_01"


# ── Helpers ──────────────────────────────────────────────────────────────


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _set_device_last_seen(device_id: str, last_seen: str | None) -> None:
    """Update the ``last_seen`` column for a device directly via Supabase."""
    db = get_supabase_client()
    db.table("devices").update({"last_seen": last_seen}).eq("id", device_id).execute()


def _insert_alert(alert_id: str, system_id: str, device_id: str | None = None) -> dict:
    """Insert a mock alert row and return its dict."""
    db = get_supabase_client()
    row = {
        "id": alert_id,
        "system_id": system_id,
        "device_id": device_id,
        "severity": "warning",
        "message": "Test alert for acknowledgment",
        "is_acknowledged": False,
        "created_at": _now_utc().isoformat(),
    }
    db.table("alerts").insert(row).execute()
    return row


def _delete_alert(alert_id: str) -> None:
    """Clean up an alert row."""
    db = get_supabase_client()
    db.table("alerts").delete().eq("id", alert_id).execute()


def _get_device_system_id(device_id: str) -> str:
    """Return the system_id for a given device."""
    db = get_supabase_client()
    resp = db.table("devices").select("system_id").eq("id", device_id).execute()
    return resp.data[0]["system_id"]


def _cleanup_offline_alerts(device_id: str) -> None:
    """Remove offline alerts for a device to ensure test isolation."""
    db = get_supabase_client()
    db.table("alerts").delete().eq("device_id", device_id).like(
        "message", "%stopped reporting%"
    ).execute()


# ── Device Status Tests ─────────────────────────────────────────────────


def test_get_device_status_online():
    """Device with a recent last_seen should report status='online'."""
    now = _now_utc().isoformat()
    _set_device_last_seen(VALID_DEVICE_ID, now)

    response = client.get(f"/devices/{VALID_DEVICE_ID}/status")
    assert response.status_code == 200

    data = response.json()
    assert data["device_id"] == VALID_DEVICE_ID
    assert data["status"] == "online"
    assert data["minutes_since_last_seen"] is not None
    assert data["minutes_since_last_seen"] <= 5  # within threshold


def test_get_device_status_offline():
    """Device with a stale last_seen should report status='offline'."""
    stale = (_now_utc() - timedelta(minutes=10)).isoformat()
    _set_device_last_seen(VALID_DEVICE_ID, stale)

    response = client.get(f"/devices/{VALID_DEVICE_ID}/status")
    assert response.status_code == 200

    data = response.json()
    assert data["device_id"] == VALID_DEVICE_ID
    assert data["status"] == "offline"
    assert data["minutes_since_last_seen"] is not None
    assert data["minutes_since_last_seen"] >= 10


def test_get_device_status_not_found():
    """Querying a non-existent device should return 404."""
    response = client.get("/devices/NON_EXISTENT_ID/status")
    assert response.status_code == 404
    assert response.json()["detail"] == "Device not found"


# ── Alert Acknowledgment Tests ──────────────────────────────────────────


def test_acknowledge_alert_success():
    """Acknowledging an unacknowledged alert should set is_acknowledged=True."""
    alert_id = str(uuid.uuid4())
    system_id = _get_device_system_id(VALID_DEVICE_ID)

    try:
        _insert_alert(alert_id, system_id, VALID_DEVICE_ID)

        response = client.patch(f"/alerts/{alert_id}/acknowledge")
        assert response.status_code == 200

        data = response.json()
        assert data["is_acknowledged"] is True
        assert data["id"] == alert_id
        assert data["acknowledged_at"] is not None
    finally:
        _delete_alert(alert_id)


def test_acknowledge_alert_not_found():
    """Acknowledging a non-existent alert should return 404."""
    fake_id = str(uuid.uuid4())
    response = client.patch(f"/alerts/{fake_id}/acknowledge")
    assert response.status_code == 404
    assert response.json()["detail"] == "Alert not found"


# ── Watchdog Tests ──────────────────────────────────────────────────────


def test_watchdog_detects_offline_device_and_deduplicates():
    """Watchdog should create exactly one alert for a stale device and
    skip duplicates on a second run.
    """
    import asyncio

    system_id = _get_device_system_id(VALID_DEVICE_ID)

    # Clean up any pre-existing offline alerts for this device
    _cleanup_offline_alerts(VALID_DEVICE_ID)

    # Set device to stale (15 minutes ago)
    stale = (_now_utc() - timedelta(minutes=15)).isoformat()
    _set_device_last_seen(VALID_DEVICE_ID, stale)

    try:
        # First run – should create 1 alert
        count_1 = asyncio.run(check_device_heartbeats())
        assert count_1 >= 1, f"Expected at least 1 new alert, got {count_1}"

        # Second run – deduplication should prevent new alerts
        count_2 = asyncio.run(check_device_heartbeats())
        assert count_2 == 0, f"Expected 0 new alerts (dedup), got {count_2}"
    finally:
        # Restore device to online so other tests aren't affected
        _set_device_last_seen(VALID_DEVICE_ID, _now_utc().isoformat())
        _cleanup_offline_alerts(VALID_DEVICE_ID)
