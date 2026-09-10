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
from typing import Literal, Optional
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


class AlertAcknowledgeRequest(BaseModel):
    """``PATCH /alerts/{alert_id}/acknowledge`` request body."""

    acknowledged_by: UUID | None = None


# ── Response Schemas ─────────────────────────────────────────────────────


class HealthResponse(BaseModel):
    """``GET /health`` response."""

    status: str = "ok"
    timestamp: datetime = Field(default_factory=_utc_now)


class DeviceStatusResponse(BaseModel):
    """``GET /devices/{device_id}/status`` response with online/offline status."""

    device_id: str
    system_id: UUID
    name: str
    is_active: bool
    status: Literal["online", "offline"]
    last_seen: Optional[datetime] = None
    minutes_since_last_seen: float | None = None


class AlertResponse(BaseModel):
    """Full alert record returned from management endpoints."""

    id: UUID
    system_id: UUID
    device_id: str | None = None
    severity: str
    message: str
    is_acknowledged: bool
    acknowledged_by: UUID | None = None
    acknowledged_at: datetime | None = None
    created_at: datetime


class AlertListResponse(BaseModel):
    """Paginated alert list returned by ``GET /alerts``."""

    alerts: list[AlertResponse]
    total_count: int


class HourlyAggregationResponse(BaseModel):
    """Single row from the ``telemetry_hourly_rollups`` view."""

    system_id: UUID
    device_id: str
    bucket: datetime
    avg_ph: float | None = None
    avg_ec: float | None = None
    avg_water_temp: float | None = None
    avg_water_level: float | None = None
    avg_air_temp: float | None = None
    avg_humidity: float | None = None
    avg_light_intensity: float | None = None
    sample_count: int


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
