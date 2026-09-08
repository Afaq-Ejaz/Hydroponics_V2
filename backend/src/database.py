"""
Supabase client initialisation and FastAPI dependency helpers.

The client is created **once** using the ``service_role`` key so the
ingestion worker has full write access to ``sensor_readings`` regardless
of RLS policies.
"""

from functools import lru_cache

from supabase import Client, create_client

from src.config import get_settings


@lru_cache
def get_supabase_client() -> Client:
    """Return a cached Supabase ``Client`` (service-role privileges)."""
    settings = get_settings()
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


def get_db() -> Client:
    """FastAPI ``Depends()`` helper – yields the shared Supabase client."""
    return get_supabase_client()


# Alias for backward compatibility across modules
get_supabase = get_supabase_client