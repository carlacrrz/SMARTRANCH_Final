"""
Smart Ranch — JWT Authentication Module
Handles user registration, login, token generation/verification.
"""
import os
import hashlib
import hmac
import json
import time
import base64
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, HTTPException, Header
from pydantic import BaseModel, EmailStr
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db

log = logging.getLogger("auth")

# --- Configuration ---
JWT_SECRET = os.getenv("JWT_SECRET", "smart-ranch-secret-change-in-production-2026")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = int(os.getenv("JWT_EXPIRY_HOURS", "24"))


# --- Pydantic Models ---
class UserRegister(BaseModel):
    username: str
    email: str
    password: str
    full_name: Optional[str] = None
    role: str = "operator"  # admin, operator, viewer


class UserLogin(BaseModel):
    username: str
    password: str


class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str] = None
    role: str
    created_at: Optional[datetime] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


# --- Password Hashing (SHA-256 + salt, no bcrypt dependency) ---
def _hash_password(password: str, salt: Optional[bytes] = None) -> str:
    if salt is None:
        salt = os.urandom(16)
    hashed = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return base64.b64encode(salt + hashed).decode()


def _verify_password(password: str, stored_hash: str) -> bool:
    decoded = base64.b64decode(stored_hash)
    salt = decoded[:16]
    stored = decoded[16:]
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000)
    return hmac.compare_digest(stored, check)


# --- JWT (manual, no PyJWT dependency needed) ---
def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _b64url_decode(s: str) -> bytes:
    padding = 4 - len(s) % 4
    if padding != 4:
        s += "=" * padding
    return base64.urlsafe_b64decode(s)


def create_token(user_id: int, username: str, role: str) -> str:
    """Create a JWT token."""
    header = {"alg": JWT_ALGORITHM, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "sub": user_id,
        "username": username,
        "role": role,
        "iat": now,
        "exp": now + JWT_EXPIRY_HOURS * 3600,
    }

    header_b64 = _b64url_encode(json.dumps(header).encode())
    payload_b64 = _b64url_encode(json.dumps(payload).encode())
    message = f"{header_b64}.{payload_b64}"

    signature = hmac.new(JWT_SECRET.encode(), message.encode(), hashlib.sha256).digest()
    sig_b64 = _b64url_encode(signature)

    return f"{message}.{sig_b64}"


def verify_token(token: str) -> dict:
    """Verify and decode a JWT token."""
    try:
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError("Invalid token format")

        header_b64, payload_b64, sig_b64 = parts
        message = f"{header_b64}.{payload_b64}"

        expected_sig = hmac.new(JWT_SECRET.encode(), message.encode(), hashlib.sha256).digest()
        actual_sig = _b64url_decode(sig_b64)

        if not hmac.compare_digest(expected_sig, actual_sig):
            raise ValueError("Invalid signature")

        payload = json.loads(_b64url_decode(payload_b64))

        if payload.get("exp", 0) < int(time.time()):
            raise ValueError("Token expired")

        return payload
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")


# --- FastAPI Dependencies ---
async def get_current_user(
    authorization: Optional[str] = Header(None),
) -> dict:
    """Extract and verify the current user from the Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization scheme")

    token = authorization[7:]
    return verify_token(token)


async def require_admin(user: dict = Depends(get_current_user)) -> dict:
    """Require admin role."""
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


# --- Auth Endpoints (to be included in main API) ---
from fastapi import APIRouter

auth_router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@auth_router.post("/register", response_model=TokenResponse, status_code=201)
async def register(user: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register a new user."""
    # Check if username or email already exists
    existing = await db.execute(
        text("SELECT id FROM users WHERE username = :u OR email = :e"),
        {"u": user.username, "e": user.email},
    )
    if existing.first():
        raise HTTPException(status_code=409, detail="Username or email already exists")

    password_hash = _hash_password(user.password)

    result = await db.execute(
        text("""
            INSERT INTO users (username, email, password_hash, full_name, role)
            VALUES (:username, :email, :password_hash, :full_name, :role)
            RETURNING id, username, email, full_name, role, created_at
        """),
        {
            "username": user.username,
            "email": user.email,
            "password_hash": password_hash,
            "full_name": user.full_name,
            "role": user.role,
        },
    )
    await db.commit()
    row = dict(result.mappings().first())

    token = create_token(row["id"], row["username"], row["role"])
    return TokenResponse(
        access_token=token,
        expires_in=JWT_EXPIRY_HOURS * 3600,
        user=UserResponse(**row),
    )


@auth_router.post("/login", response_model=TokenResponse)
async def login(creds: UserLogin, db: AsyncSession = Depends(get_db)):
    """Login and receive a JWT token."""
    result = await db.execute(
        text("SELECT * FROM users WHERE username = :u"),
        {"u": creds.username},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user = dict(row)
    if not _verify_password(creds.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_token(user["id"], user["username"], user["role"])

    # Update last_login
    await db.execute(
        text("UPDATE users SET last_login = NOW() WHERE id = :id"),
        {"id": user["id"]},
    )
    await db.commit()

    return TokenResponse(
        access_token=token,
        expires_in=JWT_EXPIRY_HOURS * 3600,
        user=UserResponse(
            id=user["id"],
            username=user["username"],
            email=user["email"],
            full_name=user.get("full_name"),
            role=user["role"],
            created_at=user.get("created_at"),
        ),
    )


@auth_router.get("/me", response_model=UserResponse)
async def get_me(
    user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get current authenticated user details."""
    result = await db.execute(
        text("SELECT id, username, email, full_name, role, created_at FROM users WHERE id = :id"),
        {"id": user["sub"]},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(**dict(row))
