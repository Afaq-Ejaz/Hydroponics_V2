import hashlib
import hmac
from fastapi import Header, HTTPException, status
from src.database import get_supabase_client


async def authenticate_device(
    x_api_key: str | None = Header(default=None, alias="X-API-Key")
) -> dict:
    """Validate device X-API-Key against stored SHA-256 hash."""
    # 1. Return 401 if header is absent
    if not x_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-API-Key header",
        )

    # 2. Hash raw key
    computed_hash = hashlib.sha256(x_api_key.encode()).hexdigest()

    # 3. Query device table via Supabase client
    supabase = get_supabase_client()
    response = (
        supabase.table("devices")
        .select("*")
        .eq("api_key_hash", computed_hash)
        .execute()
    )

    # 4. Return 401 if device record not found
    if not response or not response.data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    device = response.data[0]

    # 5. Constant-time digest comparison
    db_hash = device.get("api_key_hash", "")
    if not hmac.compare_digest(computed_hash, db_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    # 6. Check active flag
    if not device.get("is_active", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Device is deactivated",
        )

    return device


# Aliases for cross-module compatibility
get_authenticated_device = authenticate_device
verify_device_api_key = authenticate_device