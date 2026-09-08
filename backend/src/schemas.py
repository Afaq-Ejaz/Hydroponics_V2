"""
Pydantic v2 request / response schemas for the ingestion API.

Design decisions
----------------
* Every sensor value inside ``SensorReadings`` is ``float | None`` so the
  ESP32 can omit fields when a probe is temporarily disconnected.
* ``timestamp`` defaults to UTC-now when the device doesn't supply one.
* Response models carry deterministic structures so Flutter clients can
  decode them without guessing.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field  # pyright: ignore[reportMissingImports]


# ── Helpers ──────────────────────────────────────────────────────────────


def _utc_now() -> datetime:
    """Return the current UTC time (timezone-aware)."""
    return datetime.now(timezone.utc)


# ── Request Schemas ──────────────────────────────────────────────────────


class SensorReadings(BaseModel):
    """Individual sensor values – all optional to tolerate probe failures."""

    ph: float | None = None
    ec: float | None = None
    water_temperature: float | None = None
    water_level: float | None = None
    air_temperature: float | None = None
    humidity: float | None = None
    light_intensity: float | None = None


class SensorPayload(BaseModel):
    """Top-level ingestion payload sent by an ESP32 device."""

    device_id: str = Field(..., min_length=1, examples=["ESP32_01"])
    timestamp: datetime = Field(default_factory=_utc_now)
    readings: SensorReadings


# ── Response Schemas ─────────────────────────────────────────────────────


class HealthResponse(BaseModel):
    """``GET /health`` response."""

    status: str = "ok"
    timestamp: datetime = Field(default_factory=_utc_now)


class DeviceStatusResponse(BaseModel):
    """Compact device-status view returned after validation."""

    device_id: str
    system_id: UUID
    is_active: bool
    last_seen: Optional[datetime] = None


class IngestionResponse(BaseModel):
    """``POST /ingest`` success response."""

    status: str = "accepted"
    device_id: str
    system_id: UUID
    recorded_at: datetime
    alerts_generated: int = 0


class ErrorResponse(BaseModel):
    """Standardised error envelope."""

    detail: str
