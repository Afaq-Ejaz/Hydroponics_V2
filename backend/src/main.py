"""
FastAPI application – IoT Smart Hydroponics Ingestion Service.

Endpoints
---------
``GET  /health``   → liveness probe
``POST /ingest``   → authenticated sensor-data ingestion
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status  # type: ignore[reportMissingImports]
from supabase import Client

from src.config import get_settings
from src.database import get_db, get_supabase_client
from src.schemas import (
    ErrorResponse,
    HealthResponse,
    IngestionResponse,
    SensorPayload,
)
from src.security import authenticate_device
from src.services.alert_service import evaluate_alerts

logger = logging.getLogger("hydroponics")
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")


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

    yield  # application runs here


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
