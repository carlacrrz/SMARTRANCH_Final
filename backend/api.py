"""
Smart Ranch — REST API
FastAPI server providing historical data from InfluxDB,
PostgreSQL-backed ranch management, and device management endpoints.
"""
import os
import re
import json
import logging
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from influxdb_client import InfluxDBClient
from dotenv import load_dotenv

load_dotenv()

# --- Configuration ---
INFLUX_URL = os.getenv("INFLUX_URL", "http://localhost:8086")
INFLUX_TOKEN = os.getenv("INFLUX_TOKEN", "smart-ranch-dev-token")
INFLUX_ORG = os.getenv("INFLUX_ORG", "smart_ranch")
INFLUX_BUCKET = os.getenv("INFLUX_BUCKET", "telemetry")

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("api")


# --- Lifecycle ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown events."""
    from database import check_connection
    await check_connection()
    log.info("🐄 Smart Ranch API ready (InfluxDB + PostgreSQL)")
    yield
    log.info("🛑 Shutting down Smart Ranch API")


# --- FastAPI App ---
app = FastAPI(
    title="Smart Ranch API",
    description="REST API for cattle management — InfluxDB telemetry + PostgreSQL ranch data",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # MVP: allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- PostgreSQL Router ---
from api_pg import router as pg_router
app.include_router(pg_router)

# --- Auth Router ---
from auth import auth_router
app.include_router(auth_router)

# --- Reports Router ---
from reports import report_router
app.include_router(report_router)

# --- CSV Export Router ---
from export_csv import export_router
app.include_router(export_router)

# --- InfluxDB client ---
influx_client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
query_api = influx_client.query_api()


# --- THI Helpers ---
THI_THRESHOLDS = [
    (89, "emergency"),
    (79, "danger"),
    (72, "alert"),
    (0,  "normal"),
]


def get_thi_level(thi: float) -> str:
    for threshold, level in THI_THRESHOLDS:
        if thi >= threshold:
            return level
    return "normal"


# --- Input Sanitization ---
ALLOWED_RANGES = {"1h", "6h", "24h", "7d", "30d"}
_DEVICE_ID_RE = re.compile(r"^[a-zA-Z0-9_\-]+$")


def sanitize_device_id(device_id: str) -> str:
    """Validate device_id to prevent Flux injection."""
    if not _DEVICE_ID_RE.match(device_id):
        raise HTTPException(status_code=400, detail="Invalid device_id format")
    return device_id


def sanitize_range(range_str: str) -> str:
    """Validate range against allowed values."""
    if range_str not in ALLOWED_RANGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid range '{range_str}'. Allowed: {', '.join(sorted(ALLOWED_RANGES))}",
        )
    return range_str


# --- Endpoints ---

@app.get("/")
def root():
    return {"service": "Smart Ranch API", "status": "running", "version": "1.0.0"}


@app.get("/api/animals")
def list_animals():
    """
    List all active devices/animals with their latest telemetry reading.
    """
    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -1h)
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> last()
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> group(columns: ["device_id"])
      |> last(column: "_time")
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        animals = []
        for table in tables:
            for record in table.records:
                values = record.values
                thi = values.get("thi", 0)
                animals.append({
                    "device_id": values.get("device_id", "unknown"),
                    "body_temp": values.get("body_temp", 0),
                    "ambient_temp": values.get("ambient_temp", 0),
                    "humidity": values.get("humidity", 0),
                    "thi": thi,
                    "thi_level": get_thi_level(thi) if thi else "unknown",
                    "accel_x": values.get("accel_x", 0),
                    "accel_y": values.get("accel_y", 0),
                    "accel_z": values.get("accel_z", 0),
                    "movement_intensity": values.get("movement_intensity", 0),
                    "last_seen": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                })
        return {"animals": animals, "count": len(animals)}
    except Exception as e:
        log.error("Error querying animals: %s", e)
        return {"animals": [], "count": 0, "error": str(e)}


@app.get("/api/animals/{device_id}/history")
def animal_history(
    device_id: str,
    range_str: str = Query(default="1h", alias="range", description="Time range: 1h, 6h, 24h, 7d, 30d"),
):
    """
    Get historical telemetry data for a specific animal/device.
    """
    device_id = sanitize_device_id(device_id)
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> filter(fn: (r) => r.device_id == "{device_id}")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> sort(columns: ["_time"], desc: false)
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        readings = []
        for table in tables:
            for record in table.records:
                values = record.values
                readings.append({
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                    "body_temp": values.get("body_temp", 0),
                    "ambient_temp": values.get("ambient_temp", 0),
                    "humidity": values.get("humidity", 0),
                    "thi": values.get("thi", 0),
                    "thi_level": values.get("thi_level", "unknown"),
                    "accel_x": values.get("accel_x", 0),
                    "accel_y": values.get("accel_y", 0),
                    "accel_z": values.get("accel_z", 0),
                    "movement_intensity": values.get("movement_intensity", 0),
                })
        return {
            "device_id": device_id,
            "range": range_str,
            "readings": readings,
            "count": len(readings),
        }
    except Exception as e:
        log.error("Error querying history for %s: %s", device_id, e)
        return {"device_id": device_id, "readings": [], "count": 0, "error": str(e)}


@app.get("/api/stats")
def herd_stats():
    """
    Get global herd statistics.
    """
    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -1h)
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> last()
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> group(columns: ["device_id"])
      |> last(column: "_time")
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)

        total = 0
        levels = {"normal": 0, "alert": 0, "danger": 0, "emergency": 0}
        this = []
        body_temps = []

        for table in tables:
            for record in table.records:
                total += 1
                values = record.values
                thi = values.get("thi", 0)
                if thi:
                    this.append(thi)
                    level = get_thi_level(thi)
                    levels[level] = levels.get(level, 0) + 1
                bt = values.get("body_temp", 0)
                if bt:
                    body_temps.append(bt)

        return {
            "total_animals": total,
            "by_level": levels,
            "avg_thi": round(sum(this) / len(this), 1) if this else 0,
            "max_thi": round(max(this), 1) if this else 0,
            "min_thi": round(min(this), 1) if this else 0,
            "avg_body_temp": round(sum(body_temps) / len(body_temps), 1) if body_temps else 0,
        }
    except Exception as e:
        log.error("Error computing stats: %s", e)
        return {"total_animals": 0, "by_level": {}, "error": str(e)}


@app.get("/api/alerts")
def recent_alerts(
    range_str: str = Query(default="1h", alias="range"),
):
    """
    Get recent alert-level readings.
    """
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> filter(fn: (r) => r.thi_level == "danger" or r.thi_level == "emergency")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> sort(columns: ["_time"], desc: true)
      |> limit(n: 50)
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        alerts = []
        for table in tables:
            for record in table.records:
                values = record.values
                thi = values.get("thi", 0)
                alerts.append({
                    "device_id": values.get("device_id", "unknown"),
                    "thi": thi,
                    "thi_level": get_thi_level(thi),
                    "body_temp": values.get("body_temp", 0),
                    "ambient_temp": values.get("ambient_temp", 0),
                    "humidity": values.get("humidity", 0),
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                })
        return {"alerts": alerts, "count": len(alerts)}
    except Exception as e:
        log.error("Error querying alerts: %s", e)
        return {"alerts": [], "count": 0, "error": str(e)}


@app.get("/api/animals/{device_id}/activity")
def animal_activity(
    device_id: str,
    range_str: str = Query(default="1h", alias="range", description="Time range: 1h, 6h, 24h, 7d, 30d"),
):
    """
    Get movement intensity history for estrus detection analysis.
    """
    device_id = sanitize_device_id(device_id)
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> filter(fn: (r) => r.device_id == "{device_id}")
      |> filter(fn: (r) => r._field == "movement_intensity" or r._field == "estrus_score")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> sort(columns: ["_time"], desc: false)
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        readings = []
        for table in tables:
            for record in table.records:
                values = record.values
                readings.append({
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                    "movement_intensity": values.get("movement_intensity", 0),
                    "estrus_score": values.get("estrus_score", 0),
                })
        return {
            "device_id": device_id,
            "range": range_str,
            "readings": readings,
            "count": len(readings),
        }
    except Exception as e:
        log.error("Error querying activity for %s: %s", device_id, e)
        return {"device_id": device_id, "readings": [], "count": 0, "error": str(e)}


@app.get("/api/reproduction/alerts")
def reproduction_alerts(
    range_str: str = Query(default="24h", alias="range"),
):
    """
    Get recent estrus detection alerts (high estrus_score readings).
    """
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> filter(fn: (r) => r._field == "estrus_score")
      |> filter(fn: (r) => r._value >= 0.8)
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> sort(columns: ["_time"], desc: true)
      |> limit(n: 50)
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        alerts = []
        for table in tables:
            for record in table.records:
                values = record.values
                alerts.append({
                    "device_id": values.get("device_id", "unknown"),
                    "estrus_score": values.get("estrus_score", 0),
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                })
        return {"alerts": alerts, "count": len(alerts)}
    except Exception as e:
        log.error("Error querying reproduction alerts: %s", e)
        return {"alerts": [], "count": 0, "error": str(e)}


@app.get("/api/health/alerts")
def health_alerts(
    range_str: str = Query(default="24h", alias="range"),
):
    """
    Get recent health alerts (fever, lethargy, sick_suspected).
    """
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "telemetry")
      |> filter(fn: (r) => r.health_status != "healthy")
      |> last()
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> group(columns: ["device_id"])
      |> last(column: "_time")
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        alerts = []
        for table in tables:
            for record in table.records:
                values = record.values
                alerts.append({
                    "device_id": values.get("device_id", "unknown"),
                    "health_status": values.get("health_status", "unknown"),
                    "body_temp": values.get("body_temp", 0),
                    "movement_intensity": values.get("movement_intensity", 0),
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                })
        return {"alerts": alerts, "count": len(alerts)}
    except Exception as e:
        log.error("Error querying health alerts: %s", e)
        return {"alerts": [], "count": 0, "error": str(e)}


# --- Trough / Water Endpoints ---

def sanitize_trough_id(trough_id: str) -> str:
    """Sanitize trough_id to prevent injection."""
    import re
    if not re.match(r"^[a-zA-Z0-9_\-]+$", trough_id):
        return "invalid"
    return trough_id


@app.get("/api/troughs")
def list_troughs(
    range_str: str = Query(default="1h", alias="range"),
):
    """
    List all troughs with their latest water level.
    """
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "trough_level")
      |> last()
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> group(columns: ["trough_id"])
      |> last(column: "_time")
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        troughs = []
        for table in tables:
            for record in table.records:
                values = record.values
                troughs.append({
                    "trough_id": values.get("trough_id", "unknown"),
                    "level_percent": values.get("level_percent", 0),
                    "distance_cm": values.get("distance_cm", 0),
                    "tank_depth_cm": values.get("tank_depth_cm", 100),
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                })
        return {"troughs": troughs, "count": len(troughs)}
    except Exception as e:
        log.error("Error querying troughs: %s", e)
        return {"troughs": [], "count": 0, "error": str(e)}


@app.get("/api/troughs/{trough_id}/history")
def trough_history(
    trough_id: str,
    range_str: str = Query(default="24h", alias="range"),
):
    """
    Get water level history for a specific trough.
    """
    trough_id = sanitize_trough_id(trough_id)
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "trough_level")
      |> filter(fn: (r) => r.trough_id == "{trough_id}")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> sort(columns: ["_time"], desc: false)
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        readings = []
        for table in tables:
            for record in table.records:
                values = record.values
                readings.append({
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                    "level_percent": values.get("level_percent", 0),
                    "distance_cm": values.get("distance_cm", 0),
                })
        return {
            "trough_id": trough_id,
            "range": range_str,
            "readings": readings,
            "count": len(readings),
        }
    except Exception as e:
        log.error("Error querying trough history: %s", e)
        return {"trough_id": trough_id, "readings": [], "count": 0, "error": str(e)}


@app.get("/api/water/alerts")
def water_alerts(
    range_str: str = Query(default="24h", alias="range"),
):
    """
    Get recent low water level alerts.
    """
    range_str = sanitize_range(range_str)

    flux_query = f'''
    from(bucket: "{INFLUX_BUCKET}")
      |> range(start: -{range_str})
      |> filter(fn: (r) => r._measurement == "trough_level")
      |> filter(fn: (r) => r._field == "level_percent")
      |> filter(fn: (r) => r._value <= 20.0)
      |> sort(columns: ["_time"], desc: true)
      |> limit(n: 50)
    '''
    try:
        tables = query_api.query(flux_query, org=INFLUX_ORG)
        alerts = []
        for table in tables:
            for record in table.records:
                values = record.values
                alerts.append({
                    "trough_id": values.get("trough_id", "unknown"),
                    "level_percent": values.get("_value", 0),
                    "timestamp": values.get("_time", "").isoformat() if hasattr(values.get("_time", ""), "isoformat") else str(values.get("_time", "")),
                })
        return {"alerts": alerts, "count": len(alerts)}
    except Exception as e:
        log.error("Error querying water alerts: %s", e)
        return {"alerts": [], "count": 0, "error": str(e)}

# --- Herd Management (CRUD) ---
# In-memory fallback when PostgreSQL is not running (demo mode)
_herd_animals: list[dict] = [
    {"id": 1, "siniiga_tag": "MX-0026-0001", "device_id": "vaca_001", "name": "Lupita",
     "breed": "Hereford", "sex": "hembra", "birth_date": "2022-03-15", "weight_kg": 420,
     "pasture": "Potrero Norte", "status": "active", "notes": None},
    {"id": 2, "siniiga_tag": "MX-0026-0002", "device_id": "vaca_002", "name": "Estrella",
     "breed": "Angus", "sex": "hembra", "birth_date": "2021-06-22", "weight_kg": 380,
     "pasture": "Potrero Norte", "status": "active", "notes": None},
    {"id": 3, "siniiga_tag": "MX-0026-0003", "device_id": "vaca_003", "name": "Canela",
     "breed": "Charolais", "sex": "hembra", "birth_date": "2023-01-10", "weight_kg": 350,
     "pasture": "Corral Principal", "status": "active", "notes": None},
    {"id": 4, "siniiga_tag": "MX-0026-0004", "device_id": "vaca_004", "name": "Luna",
     "breed": "Brahman", "sex": "hembra", "birth_date": "2020-09-05", "weight_kg": 450,
     "pasture": "Potrero Sur", "status": "active", "notes": None},
    {"id": 5, "siniiga_tag": "MX-0026-0005", "device_id": "vaca_005", "name": "Valentina",
     "breed": "Simmental", "sex": "hembra", "birth_date": "2022-11-18", "weight_kg": 400,
     "pasture": "Potrero Sur", "status": "active", "notes": None},
]
_next_id = 6


@app.get("/api/herd/animals")
def list_herd_animals(
    status: str = Query(default="active"),
    breed: str = Query(default=None),
    sex: str = Query(default=None),
    pasture: str = Query(default=None),
):
    """List all animals in the herd, with optional filters."""
    animals = _herd_animals
    if status:
        animals = [a for a in animals if a.get("status") == status]
    if breed:
        animals = [a for a in animals if a.get("breed", "").lower() == breed.lower()]
    if sex:
        animals = [a for a in animals if a.get("sex") == sex]
    if pasture:
        animals = [a for a in animals if a.get("pasture", "").lower() == pasture.lower()]
    return {"animals": animals, "count": len(animals)}


@app.post("/api/herd/animals")
def create_herd_animal(animal: dict):
    """Register a new animal in the herd."""
    global _next_id
    animal["id"] = _next_id
    _next_id += 1
    animal.setdefault("status", "active")
    _herd_animals.append(animal)
    return animal


@app.get("/api/herd/animals/{animal_id}")
def get_herd_animal(animal_id: int):
    """Get a specific animal by ID."""
    for animal in _herd_animals:
        if animal["id"] == animal_id:
            return animal
    return {"error": "Animal not found"}


@app.put("/api/herd/animals/{animal_id}")
def update_herd_animal(animal_id: int, updates: dict):
    """Update an animal's data."""
    for animal in _herd_animals:
        if animal["id"] == animal_id:
            animal.update({k: v for k, v in updates.items() if k != "id"})
            return animal
    return {"error": "Animal not found"}


@app.delete("/api/herd/animals/{animal_id}")
def delete_herd_animal(animal_id: int):
    """Remove an animal from inventory (logical delete = status change)."""
    for animal in _herd_animals:
        if animal["id"] == animal_id:
            animal["status"] = "removed"
            return {"message": f"Animal {animal_id} marked as removed"}
    return {"error": "Animal not found"}


@app.get("/api/herd/stats")
def herd_stats():
    """Get herd inventory statistics."""
    active = [a for a in _herd_animals if a.get("status") == "active"]
    breeds = {}
    pastures = {}
    sexes = {"hembra": 0, "macho": 0}
    for a in active:
        breed = a.get("breed", "Desconocida")
        breeds[breed] = breeds.get(breed, 0) + 1
        pasture = a.get("pasture", "Sin asignar")
        pastures[pasture] = pastures.get(pasture, 0) + 1
        sex = a.get("sex", "hembra")
        sexes[sex] = sexes.get(sex, 0) + 1
    return {
        "total_active": len(active),
        "total_all": len(_herd_animals),
        "by_breed": breeds,
        "by_pasture": pastures,
        "by_sex": sexes,
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("API_PORT", 8000))
    host = os.getenv("API_HOST", "0.0.0.0")
    log.info("🌐 Starting Smart Ranch API on %s:%s", host, port)
    uvicorn.run(app, host=host, port=port)
