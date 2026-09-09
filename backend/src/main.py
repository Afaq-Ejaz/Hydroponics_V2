"""
FastAPI application – IoT Smart Hydroponics Ingestion Service.

Endpoints
---------
``GET  /health``                              → liveness probe
``POST /ingest``                              → authenticated sensor-data ingestion
``GET  /alerts``                              → filtered alert listing
``PATCH /alerts/{alert_id}/acknowledge``       → acknowledge an alert
``GET  /devices/{device_id}/status``           → device online/offline status
``GET  /systems/{system_id}/telemetry/hourly`` → hourly aggregated telemetry
"""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Query, status  # type: ignore[reportMissingImports]
from supabase import Client

from src.config import get_settings
from src.database import get_db, get_supabase_client
from src.schemas import (
    AlertAcknowledgeRequest,
    AlertListResponse,
    AlertResponse,
    DeviceStatusResponse,
    ErrorResponse,
    HealthResponse,
    HourlyAggregationResponse,
    IngestionResponse,
    SensorPayload,
)
from src.security import authenticate_device
from src.services.alert_service import evaluate_alerts
from src.services.watchdog_service import check_device_heartbeats

from src.schemas import (
    # ... your other schemas like IngestionResponse, etc. ...
    AlertListResponse, 
    HourlyAggregationResponse
)

logger = logging.getLogger("hydroponics")
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")



# ── Background watchdog worker ──────────────────────────────────────────


async def _watchdog_loop(interval_seconds: int = 60) -> None:
    """Periodically invoke the device-heartbeat checker."""
    while True:
        try:
            count = await check_device_heartbeats()
            if count:
                logger.info("Watchdog: %d new offline alert(s) created", count)
        except asyncio.CancelledError:
            logger.info("Watchdog: background task cancelled – shutting down")
            raise
        except Exception as exc:
            logger.error("Watchdog: heartbeat check failed: %s", exc)
        await asyncio.sleep(interval_seconds)


# ── Lifespan ────────────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Warm-up: eagerly create the Supabase client and validate connectivity."""
    settings = get_settings()
    client = get_supabase_client()
    logger.info("Supabase client initialised → %s", settings.SUPABASE_URL)

    # Quick connectivity check – will raise if the URL / key are wrong.
    try:
        client.table("devices").select("id").limit(1).execute()
        logger.info("Database connectivity verified ✓")
    except Exception as exc:
        logger.error("Database connectivity check failed: %s", exc)

    # Launch the watchdog background task
    watchdog_task = asyncio.create_task(_watchdog_loop())
    logger.info("Watchdog background task started (60 s interval)")

    yield  # application runs here

    # Graceful shutdown
    watchdog_task.cancel()
    try:
        await watchdog_task
    except asyncio.CancelledError:
        pass
    logger.info("Watchdog background task stopped")


# ── App ─────────────────────────────────────────────────────────────────


app = FastAPI(
    title="Hydroponics Ingestion Service",
    version="1.0.0",
    description="High-throughput sensor data ingestion for IoT Smart Hydroponics.",
    lifespan=lifespan,
)


# ── Routes ──────────────────────────────────────────────────────────────


@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["Operations"],
    summary="Liveness probe",
)
async def health_check() -> HealthResponse:
    """Returns ``{ status: "ok" }`` when the service is alive."""
    return HealthResponse()


@app.post(
    "/ingest",
    response_model=IngestionResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        401: {"model": ErrorResponse, "description": "Invalid API key"},
        403: {"model": ErrorResponse, "description": "Device deactivated"},
        400: {"model": ErrorResponse, "description": "Device ID mismatch"},
    },
    tags=["Ingestion"],
    summary="Ingest sensor telemetry from an ESP32 device",
)
async def ingest_reading(
    payload: SensorPayload,
    device: dict = Depends(authenticate_device),
    db: Client = Depends(get_db),
) -> IngestionResponse:
    """Validate, persist, and evaluate a sensor reading.

    Flow
    ----
    1. Verify ``payload.device_id`` matches the authenticated device.
    2. Insert a row into ``sensor_readings``.
    3. Update ``devices.last_seen``.
    4. Evaluate alert thresholds and insert any alerts.
    5. Return an ``IngestionResponse``.
    """
    # ── 1. Device-ID cross-check ─────────────────────────────────────
    if payload.device_id != device["id"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Payload device_id '{payload.device_id}' does not match "
                f"authenticated device '{device['id']}'."
            ),
        )

    system_id: str = device["system_id"]
    recorded_at = payload.timestamp.isoformat()
    readings_dict = payload.readings.model_dump(exclude_none=True)

    # ── 2. Insert sensor reading ─────────────────────────────────────
    reading_row = {
        "system_id": system_id,
        "device_id": payload.device_id,
        "recorded_at": recorded_at,
        **readings_dict,
    }

    try:
        db.table("sensor_readings").insert(reading_row).execute()
    except Exception as exc:
        logger.error("Failed to insert reading: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to persist sensor reading.",
        ) from exc

    # ── 3. Touch device last_seen ────────────────────────────────────
    try:
        db.table("devices").update({"last_seen": recorded_at}).eq(
            "id", payload.device_id
        ).execute()
    except Exception as exc:
        # Non-fatal – log and continue
        logger.warning("Failed to update last_seen for %s: %s", payload.device_id, exc)

    # ── 4. Evaluate alerts ───────────────────────────────────────────
    alerts: list[dict] = []
    try:
        alerts = evaluate_alerts(readings_dict, payload.device_id, system_id, db)
        if alerts:
            logger.info(
                "%d alert(s) raised for device %s", len(alerts), payload.device_id
            )
    except Exception as exc:
        # Non-fatal – the reading itself is already persisted
        logger.warning("Alert evaluation failed for %s: %s", payload.device_id, exc)

    # ── 5. Respond ───────────────────────────────────────────────────
    return IngestionResponse(
        device_id=payload.device_id,
        system_id=system_id,
        recorded_at=payload.timestamp,
        alerts_generated=len(alerts),
    )


# ── Alert Management ────────────────────────────────────────────────────


@app.patch(
    "/alerts/{alert_id}/acknowledge",
    response_model=AlertResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Alert not found"},
    },
    tags=["Alerts"],
    summary="Acknowledge an alert",
)
async def acknowledge_alert(
    alert_id: UUID,
    body: AlertAcknowledgeRequest | None = None,
    db: Client = Depends(get_db),
) -> AlertResponse:
    """Mark an alert as acknowledged.

    If the alert is already acknowledged, the existing record is returned
    unchanged to guarantee idempotency.
    """
    # 1. Look up the alert
    response = db.table("alerts").select("*").eq("id", str(alert_id)).execute()
    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Alert not found",
        )

    alert = response.data[0]

    # 2. Already acknowledged – return as-is
    if alert.get("is_acknowledged"):
        return AlertResponse(**alert)

    # 3. Acknowledge now
    update_data: dict = {
        "is_acknowledged": True,
        "acknowledged_at": datetime.now(timezone.utc).isoformat(),
    }
    if body and body.acknowledged_by is not None:
        update_data["acknowledged_by"] = str(body.acknowledged_by)

    updated = (
        db.table("alerts")
        .update(update_data)
        .eq("id", str(alert_id))
        .execute()
    )

    return AlertResponse(**updated.data[0])


# ── Device Status ───────────────────────────────────────────────────────


@app.get(
    "/devices/{device_id}/status",
    response_model=DeviceStatusResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Device not found"},
    },
    tags=["Devices"],
    summary="Query a device's online/offline status",
)
async def get_device_status(
    device_id: str,
    db: Client = Depends(get_db),
) -> DeviceStatusResponse:
    """Compute the current online/offline status of a device based on its
    ``last_seen`` timestamp and the configured offline threshold.
    """
    settings = get_settings()

    # 1. Fetch the device
    response = db.table("devices").select("*").eq("id", device_id).execute()
    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found",
        )

    device = response.data[0]
    last_seen_raw = device.get("last_seen")

    # 2. Determine status
    device_status = "offline"
    minutes_since: float | None = None

    if last_seen_raw is not None:
        last_seen_dt = _parse_datetime(last_seen_raw)
        now_utc = datetime.now(timezone.utc)
        elapsed = (now_utc - last_seen_dt).total_seconds() / 60
        minutes_since = round(elapsed, 2)
        if elapsed <= settings.DEVICE_OFFLINE_THRESHOLD_MINUTES:
            device_status = "online"

    return DeviceStatusResponse(
        device_id=device["id"],
        system_id=device["system_id"],
        name=device["name"],
        is_active=device["is_active"],
        status=device_status,
        last_seen=last_seen_raw,
        minutes_since_last_seen=minutes_since,
    )


def _parse_datetime(value: str | datetime) -> datetime:
    """Robustly parse a datetime value from Supabase (ISO string or datetime)."""
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    raw = value.replace("Z", "+00:00")
    return datetime.fromisoformat(raw)


# ── Alert Querying ──────────────────────────────────────────────────────


@app.get(
    "/alerts",
    response_model=AlertListResponse,
    tags=["Alerts"],
    summary="List and filter alerts",
)
async def list_alerts(
    system_id: UUID = Query(..., description="System UUID (required)"),
    device_id: str | None = Query(None, description="Filter by device ID"),
    is_acknowledged: bool | None = Query(None, description="Filter by acknowledgment state"),
    severity: str | None = Query(None, description="Filter by severity (info, warning, critical)"),
    limit: int = Query(50, ge=1, le=100, description="Max results (1–100)"),
    db: Client = Depends(get_db),
) -> AlertListResponse:
    """Return a filtered, paginated list of alerts for a system."""
    query = (
        db.table("alerts")
        .select("*")
        .eq("system_id", str(system_id))
    )

    if device_id is not None:
        query = query.eq("device_id", device_id)
    if is_acknowledged is not None:
        query = query.eq("is_acknowledged", is_acknowledged)
    if severity is not None:
        query = query.eq("severity", severity)

    response = (
        query
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )

    alerts = response.data or []
    return AlertListResponse(
        alerts=[AlertResponse(**a) for a in alerts],
        total_count=len(alerts),
    )


# ── Telemetry Aggregation ───────────────────────────────────────────────


@app.get(
    "/systems/{system_id}/telemetry/hourly",
    response_model=list[HourlyAggregationResponse],
    tags=["Telemetry"],
    summary="Hourly-averaged sensor telemetry",
)
async def get_hourly_telemetry(
    system_id: UUID,
    limit: int = Query(24, ge=1, le=168, description="Number of hourly buckets (default 24)"),
    db: Client = Depends(get_db),
) -> list[HourlyAggregationResponse]:
    """Query the ``hourly_sensor_averages`` view for downsampled telemetry."""
    response = (
        db.table("hourly_sensor_averages")
        .select("*")
        .eq("system_id", str(system_id))
        .order("hour", desc=True)
        .limit(limit)
        .execute()
    )

    rows = response.data or []
    return [HourlyAggregationResponse(**row) for row in rows]
