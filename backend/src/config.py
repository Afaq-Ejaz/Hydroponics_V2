"""
Application configuration via pydantic-settings.

All values are loaded from ``backend/.env`` and can be overridden through
real environment variables (12-factor style).
"""

from functools import lru_cache
from importlib import import_module
from pathlib import Path

# Import lazily so the module remains usable with either Pydantic v1 or v2.
# Pydantic v2 moved ``BaseSettings`` into the optional ``pydantic-settings``
# package, which may not be installed in every environment.
try:
    _pydantic_settings = import_module("pydantic_settings")
    BaseSettings = _pydantic_settings.BaseSettings
    SettingsConfigDict = _pydantic_settings.SettingsConfigDict
except ImportError:
    from pydantic import BaseSettings  # type: ignore[attr-defined,no-redef]

    SettingsConfigDict = dict  # type: ignore[assignment,misc]

# Resolve the .env that sits next to the ``backend/`` directory root,
# i.e. one level above ``src/``.
_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


class Settings(BaseSettings):
    """Typed, validated application settings."""

    model_config = SettingsConfigDict(
        env_file=str(_ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── Supabase connection ──────────────────────────────────────────
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str

    # ── Alert thresholds ─────────────────────────────────────────────
    ALERT_PH_MIN: float = 5.5
    ALERT_PH_MAX: float = 6.5
    ALERT_WATER_TEMP_MAX: float = 26.0
    ALERT_WATER_TEMP_MIN: float = 16.0

    # ── Device health ────────────────────────────────────────────────
    DEVICE_OFFLINE_THRESHOLD_MINUTES: int = 5


@lru_cache
def get_settings() -> Settings:
    """Return a cached singleton :class:`Settings` instance."""
    return Settings()  # type: ignore[call-arg]
