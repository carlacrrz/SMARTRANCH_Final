"""
Smart Ranch — PostgreSQL Writer (used by bridge.py)
Synchronous PostgreSQL writes for the MQTT bridge process.
Uses psycopg2 (sync) since bridge runs in a synchronous MQTT loop.
"""
import os
import json
import logging

import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

load_dotenv()

log = logging.getLogger("pg_writer")

PG_HOST = os.getenv("PG_HOST", "localhost")
PG_PORT = os.getenv("PG_PORT", "5432")
PG_DATABASE = os.getenv("PG_DATABASE", "smart_ranch")
PG_USER = os.getenv("PG_USER", "ranch_admin")
PG_PASSWORD = os.getenv("PG_PASSWORD", "smartranch2026")

_conn = None


def get_connection():
    """Get or create PostgreSQL connection."""
    global _conn
    if _conn is None or _conn.closed:
        try:
            _conn = psycopg2.connect(
                host=PG_HOST, port=PG_PORT, dbname=PG_DATABASE,
                user=PG_USER, password=PG_PASSWORD,
            )
            _conn.autocommit = True
            log.info("✅ Connected to PostgreSQL (sync writer)")
        except Exception as e:
            log.error("❌ PostgreSQL sync connection failed: %s", e)
            _conn = None
    return _conn


def write_alert(device_id: str, alert_type: str, severity: str, message: str, metadata: dict = None):
    """Write an alert to PostgreSQL alerts_log."""
    conn = get_connection()
    if not conn:
        return
    try:
        with conn.cursor() as cur:
            # Try to find animal_id from device_id
            cur.execute("SELECT id FROM animals WHERE device_id = %s", (device_id,))
            row = cur.fetchone()
            animal_id = row[0] if row else None

            cur.execute(
                """INSERT INTO alerts_log (animal_id, device_id, alert_type, severity, message, metadata)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (animal_id, device_id, alert_type, severity, message,
                 json.dumps(metadata) if metadata else None),
            )
    except Exception as e:
        log.error("Failed to write alert to PostgreSQL: %s", e)


def write_gps_position(device_id: str, latitude: float, longitude: float,
                       altitude: float = None, speed: float = None,
                       heading: float = None, hdop: float = None):
    """Write a GPS position to PostgreSQL gps_positions (PostGIS)."""
    conn = get_connection()
    if not conn:
        return
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO gps_positions (device_id, position, altitude, speed, heading, hdop)
                   VALUES (%s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s, %s, %s)""",
                (device_id, longitude, latitude, altitude, speed, heading, hdop),
            )
    except Exception as e:
        log.error("Failed to write GPS position to PostgreSQL: %s", e)


def check_geofence(device_id: str, latitude: float, longitude: float) -> list[dict]:
    """Check if a position is outside any geofence zones with alert_on_exit=True.
    Returns list of violated zones."""
    conn = get_connection()
    if not conn:
        return []
    try:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT gz.id, gz.name, gz.zone_type
                   FROM gps_zones gz
                   WHERE gz.alert_on_exit = TRUE
                     AND NOT ST_Contains(gz.boundary, ST_SetSRID(ST_MakePoint(%s, %s), 4326))""",
                (longitude, latitude),
            )
            rows = cur.fetchall()
            return [{"zone_id": r[0], "zone_name": r[1], "zone_type": r[2]} for r in rows]
    except Exception as e:
        log.error("Geofence check failed: %s", e)
        return []


def close():
    """Close the connection."""
    global _conn
    if _conn and not _conn.closed:
        _conn.close()
        log.info("PostgreSQL connection closed")
