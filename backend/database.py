"""
Smart Ranch — PostgreSQL Database Connection
Async connection pool using SQLAlchemy + asyncpg.
"""
import os
import logging

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from dotenv import load_dotenv

load_dotenv()

log = logging.getLogger("database")

PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DATABASE = os.getenv("PG_DATABASE", "smart_ranch")
PG_USER = os.getenv("PG_USER", "ranch_admin")
PG_PASSWORD = os.getenv("PG_PASSWORD", "smartranch2026")

DATABASE_URL = f"postgresql+asyncpg://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DATABASE}"

engine = create_async_engine(DATABASE_URL, echo=False, pool_size=10, max_overflow=20)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db():
    """FastAPI dependency for database sessions."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


async def check_connection():
    """Test database connectivity."""
    try:
        async with engine.connect() as conn:
            await conn.execute(
                __import__("sqlalchemy").text("SELECT 1")
            )
        log.info("✅ Connected to PostgreSQL at %s:%s/%s", PG_HOST, PG_PORT, PG_DATABASE)
        return True
    except Exception as e:
        log.error("❌ PostgreSQL connection failed: %s", e)
        return False
