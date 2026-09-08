import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

VALID_DEVICE_ID = "ESP32_01"
VALID_API_KEY = "dev_secret_key_abc123"
INVALID_API_KEY = "wrong_secret_key_999"


def test_health_endpoint():
    """Verify that the service health probe responds with 200 OK."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "timestamp" in data


def test_ingest_missing_api_key():
    """Verify requests without an X-API-Key header are rejected with 401."""
    payload = {
        "device_id": VALID_DEVICE_ID,
        "readings": {"ph": 6.0}
    }
    response = client.post("/ingest", json=payload)
    assert response.status_code == 401


def test_ingest_invalid_api_key():
    """Verify requests with a bogus API key are rejected with 401."""
    payload = {
        "device_id": VALID_DEVICE_ID,
        "readings": {"ph": 6.0}
    }
    headers = {"X-API-Key": INVALID_API_KEY}
    response = client.post("/ingest", json=payload, headers=headers)
    assert response.status_code == 401


def test_ingest_device_id_mismatch():
    """Verify that an authenticated device cannot submit readings for another device."""
    payload = {
        "device_id": "ESP32_IMPOSTER",
        "readings": {"ph": 6.0}
    }
    headers = {"X-API-Key": VALID_API_KEY}
    response = client.post("/ingest", json=payload, headers=headers)
    assert response.status_code == 400


def test_ingest_partial_probes_tolerated():
    """Verify payload succeeds even if some sensor probes are null/missing."""
    payload = {
        "device_id": VALID_DEVICE_ID,
        "readings": {
            "ph": 6.1,
            "ec": None,
            "water_temperature": 22.0
            # other probes intentionally omitted
        }
    }
    headers = {"X-API-Key": VALID_API_KEY}
    response = client.post("/ingest", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "accepted"
    assert data["device_id"] == VALID_DEVICE_ID


def test_ingest_threshold_alert_generation():
    """Verify out-of-range sensor values generate alerts in the database."""
    payload = {
        "device_id": VALID_DEVICE_ID,
        "readings": {
            "ph": 4.5,                # Critical: below ALERT_PH_MIN (5.5)
            "water_temperature": 28.0  # Warning: above ALERT_WATER_TEMP_MAX (26.0)
        }
    }
    headers = {"X-API-Key": VALID_API_KEY}
    response = client.post("/ingest", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "accepted"
    assert data["alerts_generated"] >= 2