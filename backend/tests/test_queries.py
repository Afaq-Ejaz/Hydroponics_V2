"""
Tests for Phase 5 – Alert Querying & Telemetry Aggregation.

Covers:
  - Filtered alert listing (GET /alerts)
  - Missing system_id validation (422)
  - Hourly telemetry aggregation endpoint (empty result set)
"""

import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from src.database import get_supabase_client
from src.main import app

client = TestClient(app)

VALID_DEVICE_ID = "ESP32_01"


# ── Helpers ──────────────────────────────────────────────────────────────


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _get_device_system_id(device_id: str) -> str:
    """Return the system_id for a given device."""
    db = get_supabase_client()
    resp = db.table("devices").select("system_id").eq("id", device_id).execute()
    return resp.data[0]["system_id"]


def _insert_alert(
    alert_id: str,
    system_id: str,
    device_id: str | None = None,
    severity: str = "warning",
    is_acknowledged: bool = False,
    message: str = "Test alert",
) -> dict:
    """Insert a mock alert row and return its dict."""
    db = get_supabase_client()
    row = {
        "id": alert_id,
        "system_id": system_id,
        "device_id": device_id,
        "severity": severity,
        "message": message,
        "is_acknowledged": is_acknowledged,
        "created_at": _now_utc().isoformat(),
    }
    db.table("alerts").insert(row).execute()
    return row


def _delete_alerts(*alert_ids: str) -> None:
    """Clean up alert rows."""
    db = get_supabase_client()
    for aid in alert_ids:
        db.table("alerts").delete().eq("id", aid).execute()


# ── Alert Query Tests ───────────────────────────────────────────────────


def test_get_alerts_filtered():
    """Insert alerts with different states and verify filtering returns the
    correct subset.
    """
    system_id = _get_device_system_id(VALID_DEVICE_ID)
    id_warn_unack = str(uuid.uuid4())
    id_crit_unack = str(uuid.uuid4())
    id_warn_acked = str(uuid.uuid4())

    try:
        _insert_alert(id_warn_unack, system_id, VALID_DEVICE_ID, severity="warning", is_acknowledged=False, message="pH warning")
        _insert_alert(id_crit_unack, system_id, VALID_DEVICE_ID, severity="critical", is_acknowledged=False, message="Temp critical")
        _insert_alert(id_warn_acked, system_id, VALID_DEVICE_ID, severity="warning", is_acknowledged=True, message="Old warning")

        # Filter: unacknowledged only
        resp = client.get("/alerts", params={
            "system_id": system_id,
            "is_acknowledged": False,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_count"] >= 2
        for alert in data["alerts"]:
            assert alert["is_acknowledged"] is False

        # Filter: warning severity only
        resp2 = client.get("/alerts", params={
            "system_id": system_id,
            "severity": "warning",
        })
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert data2["total_count"] >= 2
        for alert in data2["alerts"]:
            assert alert["severity"] == "warning"

        # Filter: unacknowledged + critical severity
        resp3 = client.get("/alerts", params={
            "system_id": system_id,
            "is_acknowledged": False,
            "severity": "critical",
        })
        assert resp3.status_code == 200
        data3 = resp3.json()
        assert data3["total_count"] >= 1
        for alert in data3["alerts"]:
            assert alert["severity"] == "critical"
            assert alert["is_acknowledged"] is False

    finally:
        _delete_alerts(id_warn_unack, id_crit_unack, id_warn_acked)


def test_get_alerts_missing_system_id():
    """Querying GET /alerts without system_id should return 422."""
    resp = client.get("/alerts")
    assert resp.status_code == 422


# ── Telemetry Aggregation Tests ─────────────────────────────────────────


def test_get_hourly_telemetry_empty():
    """Querying hourly telemetry for a non-existent system should return
    an empty list with HTTP 200.
    """
    fake_system_id = str(uuid.uuid4())
    resp = client.get(f"/systems/{fake_system_id}/telemetry/hourly")
    assert resp.status_code == 200
    assert resp.json() == []
