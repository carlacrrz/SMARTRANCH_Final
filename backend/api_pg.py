"""
Smart Ranch — PostgreSQL API Router
CRUD endpoints for all ranch management modules.
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import (
    AnimalCreate, AnimalUpdate, AnimalResponse,
    MedicalRecordCreate, MedicalRecordResponse,
    ReproductiveEventCreate, ReproductiveEventResponse,
    WeightRecordCreate, WeightRecordResponse,
    GpsZoneCreate, GpsZoneResponse,
    AlertCreate, AlertAcknowledge, AlertResponse,
    FeedRecordCreate, FeedRecordResponse,
    FinancialEventCreate, FinancialEventResponse,
    GpsPositionResponse,
)

log = logging.getLogger("api_pg")

router = APIRouter(prefix="/api/v2", tags=["PostgreSQL"])


# ============================================================
#  ANIMALS — CRUD
# ============================================================

@router.get("/animals", response_model=list[AnimalResponse])
async def list_animals(
    status: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    sex: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    limit: int = Query(100, le=500),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db),
):
    """List all animals with optional filters."""
    query = "SELECT * FROM animals WHERE 1=1"
    params = {}

    if status:
        query += " AND status = :status"
        params["status"] = status
    if category:
        query += " AND category = :category"
        params["category"] = category
    if sex:
        query += " AND sex = :sex"
        params["sex"] = sex
    if search:
        query += " AND (name ILIKE :search OR ear_tag ILIKE :search OR device_id ILIKE :search)"
        params["search"] = f"%{search}%"

    query += " ORDER BY name ASC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset

    result = await db.execute(text(query), params)
    rows = result.mappings().all()
    return [AnimalResponse(**dict(r)) for r in rows]


@router.get("/animals/{animal_id}", response_model=AnimalResponse)
async def get_animal(animal_id: int, db: AsyncSession = Depends(get_db)):
    """Get a single animal by ID."""
    result = await db.execute(text("SELECT * FROM animals WHERE id = :id"), {"id": animal_id})
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Animal not found")
    return AnimalResponse(**dict(row))


@router.post("/animals", response_model=AnimalResponse, status_code=201)
async def create_animal(animal: AnimalCreate, db: AsyncSession = Depends(get_db)):
    """Create a new animal."""
    query = text("""
        INSERT INTO animals (device_id, name, ear_tag, breed, sex, birth_date,
                            weight_kg, category, mother_id, father_id, status,
                            photo_url, notes)
        VALUES (:device_id, :name, :ear_tag, :breed, :sex, :birth_date,
                :weight_kg, :category, :mother_id, :father_id, :status,
                :photo_url, :notes)
        RETURNING *
    """)
    result = await db.execute(query, animal.model_dump())
    await db.commit()
    row = result.mappings().first()
    return AnimalResponse(**dict(row))


@router.put("/animals/{animal_id}", response_model=AnimalResponse)
async def update_animal(animal_id: int, animal: AnimalUpdate, db: AsyncSession = Depends(get_db)):
    """Update an existing animal."""
    # Build dynamic SET clause from non-None fields
    updates = {k: v for k, v in animal.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    updates["updated_at"] = datetime.now(timezone.utc)
    set_clause = ", ".join(f"{k} = :{k}" for k in updates)
    updates["id"] = animal_id

    query = text(f"UPDATE animals SET {set_clause} WHERE id = :id RETURNING *")
    result = await db.execute(query, updates)
    await db.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Animal not found")
    return AnimalResponse(**dict(row))


@router.delete("/animals/{animal_id}", status_code=204)
async def delete_animal(animal_id: int, db: AsyncSession = Depends(get_db)):
    """Soft-delete: set status to 'dead' or 'sold'. Hard delete only if explicitly needed."""
    result = await db.execute(
        text("UPDATE animals SET status = 'sold', updated_at = NOW() WHERE id = :id RETURNING id"),
        {"id": animal_id},
    )
    await db.commit()
    if not result.first():
        raise HTTPException(status_code=404, detail="Animal not found")


@router.get("/animals/{animal_id}/full")
async def get_animal_full_profile(animal_id: int, db: AsyncSession = Depends(get_db)):
    """Get complete animal profile with all related data."""
    # Animal
    animal = await db.execute(text("SELECT * FROM animals WHERE id = :id"), {"id": animal_id})
    animal_row = animal.mappings().first()
    if not animal_row:
        raise HTTPException(status_code=404, detail="Animal not found")

    # Medical
    medical = await db.execute(
        text("SELECT * FROM medical_records WHERE animal_id = :id ORDER BY recorded_at DESC LIMIT 20"),
        {"id": animal_id},
    )
    # Reproductive
    repro = await db.execute(
        text("SELECT * FROM reproductive_events WHERE animal_id = :id ORDER BY recorded_at DESC LIMIT 20"),
        {"id": animal_id},
    )
    # Weight
    weights = await db.execute(
        text("SELECT * FROM weight_records WHERE animal_id = :id ORDER BY recorded_at DESC LIMIT 20"),
        {"id": animal_id},
    )
    # Alerts
    alerts = await db.execute(
        text("SELECT * FROM alerts_log WHERE animal_id = :id ORDER BY created_at DESC LIMIT 20"),
        {"id": animal_id},
    )

    return {
        "animal": dict(animal_row),
        "medical_records": [dict(r) for r in medical.mappings().all()],
        "reproductive_events": [dict(r) for r in repro.mappings().all()],
        "weight_records": [dict(r) for r in weights.mappings().all()],
        "recent_alerts": [dict(r) for r in alerts.mappings().all()],
    }


# ============================================================
#  MEDICAL RECORDS
# ============================================================

@router.get("/medical", response_model=list[MedicalRecordResponse])
async def list_medical_records(
    animal_id: Optional[int] = Query(None),
    record_type: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT * FROM medical_records WHERE 1=1"
    params: dict = {}
    if animal_id:
        query += " AND animal_id = :animal_id"
        params["animal_id"] = animal_id
    if record_type:
        query += " AND record_type = :record_type"
        params["record_type"] = record_type
    query += " ORDER BY recorded_at DESC LIMIT :limit"
    params["limit"] = limit

    result = await db.execute(text(query), params)
    return [MedicalRecordResponse(**dict(r)) for r in result.mappings().all()]


@router.post("/medical", response_model=MedicalRecordResponse, status_code=201)
async def create_medical_record(record: MedicalRecordCreate, db: AsyncSession = Depends(get_db)):
    query = text("""
        INSERT INTO medical_records (animal_id, record_type, product_name, dose,
                                     administered_by, cost, notes, next_due_date, withdrawal_days)
        VALUES (:animal_id, :record_type, :product_name, :dose,
                :administered_by, :cost, :notes, :next_due_date, :withdrawal_days)
        RETURNING *
    """)
    result = await db.execute(query, record.model_dump())
    await db.commit()
    return MedicalRecordResponse(**dict(result.mappings().first()))


@router.get("/medical/upcoming")
async def upcoming_medical(days: int = Query(7, le=90), db: AsyncSession = Depends(get_db)):
    """Get medical events due in the next N days."""
    query = text("""
        SELECT mr.*, a.name as animal_name, a.ear_tag
        FROM medical_records mr
        JOIN animals a ON mr.animal_id = a.id
        WHERE mr.next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + :days * INTERVAL '1 day'
        ORDER BY mr.next_due_date ASC
    """)
    result = await db.execute(query, {"days": days})
    return [dict(r) for r in result.mappings().all()]


# ============================================================
#  REPRODUCTIVE EVENTS
# ============================================================

@router.get("/reproductive", response_model=list[ReproductiveEventResponse])
async def list_reproductive_events(
    animal_id: Optional[int] = Query(None),
    event_type: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT * FROM reproductive_events WHERE 1=1"
    params: dict = {}
    if animal_id:
        query += " AND animal_id = :animal_id"
        params["animal_id"] = animal_id
    if event_type:
        query += " AND event_type = :event_type"
        params["event_type"] = event_type
    query += " ORDER BY recorded_at DESC LIMIT :limit"
    params["limit"] = limit

    result = await db.execute(text(query), params)
    return [ReproductiveEventResponse(**dict(r)) for r in result.mappings().all()]


@router.post("/reproductive", response_model=ReproductiveEventResponse, status_code=201)
async def create_reproductive_event(event: ReproductiveEventCreate, db: AsyncSession = Depends(get_db)):
    query = text("""
        INSERT INTO reproductive_events (animal_id, event_type, bull_or_semen,
                                         pregnancy_confirmed, expected_birth_date, calf_id, notes)
        VALUES (:animal_id, :event_type, :bull_or_semen,
                :pregnancy_confirmed, :expected_birth_date, :calf_id, :notes)
        RETURNING *
    """)
    result = await db.execute(query, event.model_dump())
    await db.commit()
    return ReproductiveEventResponse(**dict(result.mappings().first()))


@router.get("/reproductive/expected-births")
async def expected_births(days: int = Query(30, le=90), db: AsyncSession = Depends(get_db)):
    """Get animals with expected births in the next N days."""
    query = text("""
        SELECT re.*, a.name as animal_name, a.ear_tag
        FROM reproductive_events re
        JOIN animals a ON re.animal_id = a.id
        WHERE re.expected_birth_date BETWEEN CURRENT_DATE AND CURRENT_DATE + :days * INTERVAL '1 day'
          AND re.event_type IN ('mating', 'artificial_insemination', 'pregnancy_check')
          AND re.pregnancy_confirmed = TRUE
        ORDER BY re.expected_birth_date ASC
    """)
    result = await db.execute(query, {"days": days})
    return [dict(r) for r in result.mappings().all()]


# ============================================================
#  WEIGHT RECORDS
# ============================================================

@router.get("/weights", response_model=list[WeightRecordResponse])
async def list_weight_records(
    animal_id: Optional[int] = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT * FROM weight_records WHERE 1=1"
    params: dict = {}
    if animal_id:
        query += " AND animal_id = :animal_id"
        params["animal_id"] = animal_id
    query += " ORDER BY recorded_at DESC LIMIT :limit"
    params["limit"] = limit

    result = await db.execute(text(query), params)
    return [WeightRecordResponse(**dict(r)) for r in result.mappings().all()]


@router.post("/weights", response_model=WeightRecordResponse, status_code=201)
async def create_weight_record(record: WeightRecordCreate, db: AsyncSession = Depends(get_db)):
    query = text("""
        INSERT INTO weight_records (animal_id, weight_kg, body_condition_score, notes)
        VALUES (:animal_id, :weight_kg, :body_condition_score, :notes)
        RETURNING *
    """)
    result = await db.execute(query, record.model_dump())
    await db.commit()
    row = result.mappings().first()

    # Also update the animal's current weight
    await db.execute(
        text("UPDATE animals SET weight_kg = :w, updated_at = NOW() WHERE id = :id"),
        {"w": record.weight_kg, "id": record.animal_id},
    )
    await db.commit()

    return WeightRecordResponse(**dict(row))


@router.get("/weights/{animal_id}/growth")
async def animal_growth_curve(animal_id: int, db: AsyncSession = Depends(get_db)):
    """Get weight history for growth curve visualization."""
    query = text("""
        SELECT weight_kg, body_condition_score, recorded_at
        FROM weight_records
        WHERE animal_id = :id
        ORDER BY recorded_at ASC
    """)
    result = await db.execute(query, {"id": animal_id})
    rows = [dict(r) for r in result.mappings().all()]

    # Calculate daily weight gain between consecutive records
    gdp_records = []
    for i in range(1, len(rows)):
        days_diff = (rows[i]["recorded_at"] - rows[i - 1]["recorded_at"]).days
        if days_diff > 0:
            gdp = (rows[i]["weight_kg"] - rows[i - 1]["weight_kg"]) / days_diff
            gdp_records.append({
                "date": rows[i]["recorded_at"].isoformat(),
                "weight_kg": rows[i]["weight_kg"],
                "gdp_kg": round(gdp, 3),
            })

    return {"animal_id": animal_id, "records": rows, "gdp": gdp_records}


# ============================================================
#  GPS ZONES
# ============================================================

@router.get("/zones", response_model=list[GpsZoneResponse])
async def list_gps_zones(db: AsyncSession = Depends(get_db)):
    query = text("""
        SELECT id, name, zone_type,
               ST_AsGeoJSON(boundary)::json->'coordinates' as coordinates,
               color, alert_on_exit, alert_on_enter, notes, created_at
        FROM gps_zones
        ORDER BY name
    """)
    result = await db.execute(query)
    rows = []
    for r in result.mappings().all():
        row = dict(r)
        # GeoJSON polygon coordinates come as [[[lng,lat],...]]
        coords = row.get("coordinates")
        if coords and len(coords) > 0:
            row["coordinates"] = coords[0]  # Flatten outer ring
        rows.append(GpsZoneResponse(**row))
    return rows


@router.post("/zones", response_model=GpsZoneResponse, status_code=201)
async def create_gps_zone(zone: GpsZoneCreate, db: AsyncSession = Depends(get_db)):
    # Build WKT polygon from coordinates
    coords = zone.coordinates
    # Ensure polygon is closed
    if coords[0] != coords[-1]:
        coords.append(coords[0])
    wkt_points = ", ".join(f"{c[0]} {c[1]}" for c in coords)
    wkt = f"POLYGON(({wkt_points}))"

    query = text("""
        INSERT INTO gps_zones (name, zone_type, boundary, color, alert_on_exit, alert_on_enter, notes)
        VALUES (:name, :zone_type, ST_GeomFromText(:wkt, 4326), :color, :alert_on_exit, :alert_on_enter, :notes)
        RETURNING id, name, zone_type, color, alert_on_exit, alert_on_enter, notes, created_at
    """)
    params = zone.model_dump()
    del params["coordinates"]
    params["wkt"] = wkt

    result = await db.execute(query, params)
    await db.commit()
    row = dict(result.mappings().first())
    row["coordinates"] = zone.coordinates
    return GpsZoneResponse(**row)


@router.delete("/zones/{zone_id}", status_code=204)
async def delete_gps_zone(zone_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("DELETE FROM gps_zones WHERE id = :id RETURNING id"), {"id": zone_id})
    await db.commit()
    if not result.first():
        raise HTTPException(status_code=404, detail="Zone not found")


# ============================================================
#  GPS POSITIONS (read-only — written by bridge)
# ============================================================

@router.get("/gps/{device_id}/positions")
async def get_gps_positions(
    device_id: str,
    hours: int = Query(24, le=168),
    limit: int = Query(500, le=2000),
    db: AsyncSession = Depends(get_db),
):
    """Get GPS position history for a device."""
    query = text("""
        SELECT id, device_id,
               ST_Y(position) as latitude,
               ST_X(position) as longitude,
               altitude, speed, heading, hdop, recorded_at
        FROM gps_positions
        WHERE device_id = :device_id
          AND recorded_at >= NOW() - :hours * INTERVAL '1 hour'
        ORDER BY recorded_at DESC
        LIMIT :limit
    """)
    result = await db.execute(query, {"device_id": device_id, "hours": hours, "limit": limit})
    return [dict(r) for r in result.mappings().all()]


@router.get("/gps/current")
async def get_all_current_positions(db: AsyncSession = Depends(get_db)):
    """Get latest GPS position for each device (map overview)."""
    query = text("""
        SELECT DISTINCT ON (gp.device_id)
            gp.device_id,
            a.name as animal_name,
            ST_Y(gp.position) as latitude,
            ST_X(gp.position) as longitude,
            gp.speed, gp.recorded_at,
            (SELECT gz.name FROM gps_zones gz
             WHERE ST_Contains(gz.boundary, gp.position)
             LIMIT 1) as current_zone
        FROM gps_positions gp
        LEFT JOIN animals a ON a.device_id = gp.device_id
        ORDER BY gp.device_id, gp.recorded_at DESC
    """)
    result = await db.execute(query)
    return [dict(r) for r in result.mappings().all()]


@router.get("/gps/geofence-check")
async def check_geofence_violations(db: AsyncSession = Depends(get_db)):
    """Check which animals are outside their expected zones."""
    query = text("""
        WITH latest_positions AS (
            SELECT DISTINCT ON (device_id)
                device_id, position, recorded_at
            FROM gps_positions
            ORDER BY device_id, recorded_at DESC
        )
        SELECT lp.device_id, a.name as animal_name,
               ST_Y(lp.position) as latitude,
               ST_X(lp.position) as longitude,
               lp.recorded_at,
               COALESCE(
                   (SELECT gz.name FROM gps_zones gz
                    WHERE ST_Contains(gz.boundary, lp.position) LIMIT 1),
                   'FUERA DE ZONA'
               ) as current_zone
        FROM latest_positions lp
        LEFT JOIN animals a ON a.device_id = lp.device_id
        WHERE NOT EXISTS (
            SELECT 1 FROM gps_zones gz
            WHERE ST_Contains(gz.boundary, lp.position)
        )
    """)
    result = await db.execute(query)
    return [dict(r) for r in result.mappings().all()]


# ============================================================
#  ALERTS LOG
# ============================================================

@router.get("/alerts", response_model=list[AlertResponse])
async def list_alerts(
    animal_id: Optional[int] = Query(None),
    alert_type: Optional[str] = Query(None),
    unacknowledged: bool = Query(False),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT * FROM alerts_log WHERE 1=1"
    params: dict = {}
    if animal_id:
        query += " AND animal_id = :animal_id"
        params["animal_id"] = animal_id
    if alert_type:
        query += " AND alert_type = :alert_type"
        params["alert_type"] = alert_type
    if unacknowledged:
        query += " AND acknowledged = FALSE"
    query += " ORDER BY created_at DESC LIMIT :limit"
    params["limit"] = limit

    result = await db.execute(text(query), params)
    return [AlertResponse(**dict(r)) for r in result.mappings().all()]


@router.post("/alerts", response_model=AlertResponse, status_code=201)
async def create_alert(alert: AlertCreate, db: AsyncSession = Depends(get_db)):
    query = text("""
        INSERT INTO alerts_log (animal_id, device_id, alert_type, severity, message, metadata)
        VALUES (:animal_id, :device_id, :alert_type, :severity, :message, :metadata::jsonb)
        RETURNING *
    """)
    params = alert.model_dump()
    import json
    params["metadata"] = json.dumps(params["metadata"]) if params["metadata"] else None
    result = await db.execute(query, params)
    await db.commit()
    return AlertResponse(**dict(result.mappings().first()))


@router.put("/alerts/{alert_id}/acknowledge", response_model=AlertResponse)
async def acknowledge_alert(alert_id: int, ack: AlertAcknowledge, db: AsyncSession = Depends(get_db)):
    query = text("""
        UPDATE alerts_log
        SET acknowledged = TRUE, acknowledged_by = :by, acknowledged_at = NOW()
        WHERE id = :id
        RETURNING *
    """)
    result = await db.execute(query, {"id": alert_id, "by": ack.acknowledged_by})
    await db.commit()
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Alert not found")
    return AlertResponse(**dict(row))


# ============================================================
#  FEED RECORDS
# ============================================================

@router.get("/feed", response_model=list[FeedRecordResponse])
async def list_feed_records(
    animal_id: Optional[int] = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT * FROM feed_records WHERE 1=1"
    params: dict = {}
    if animal_id:
        query += " AND animal_id = :animal_id"
        params["animal_id"] = animal_id
    query += " ORDER BY recorded_at DESC LIMIT :limit"
    params["limit"] = limit

    result = await db.execute(text(query), params)
    return [FeedRecordResponse(**dict(r)) for r in result.mappings().all()]


@router.post("/feed", response_model=FeedRecordResponse, status_code=201)
async def create_feed_record(record: FeedRecordCreate, db: AsyncSession = Depends(get_db)):
    query = text("""
        INSERT INTO feed_records (animal_id, group_name, feed_type, quantity_kg, cost, notes)
        VALUES (:animal_id, :group_name, :feed_type, :quantity_kg, :cost, :notes)
        RETURNING *
    """)
    result = await db.execute(query, record.model_dump())
    await db.commit()
    return FeedRecordResponse(**dict(result.mappings().first()))


# ============================================================
#  FINANCIAL EVENTS
# ============================================================

@router.get("/financial", response_model=list[FinancialEventResponse])
async def list_financial_events(
    animal_id: Optional[int] = Query(None),
    event_type: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT * FROM financial_events WHERE 1=1"
    params: dict = {}
    if animal_id:
        query += " AND animal_id = :animal_id"
        params["animal_id"] = animal_id
    if event_type:
        query += " AND event_type = :event_type"
        params["event_type"] = event_type
    query += " ORDER BY recorded_at DESC LIMIT :limit"
    params["limit"] = limit

    result = await db.execute(text(query), params)
    return [FinancialEventResponse(**dict(r)) for r in result.mappings().all()]


@router.post("/financial", response_model=FinancialEventResponse, status_code=201)
async def create_financial_event(event: FinancialEventCreate, db: AsyncSession = Depends(get_db)):
    query = text("""
        INSERT INTO financial_events (animal_id, event_type, amount, buyer_seller, weight_at_event, notes)
        VALUES (:animal_id, :event_type, :amount, :buyer_seller, :weight_at_event, :notes)
        RETURNING *
    """)
    result = await db.execute(query, event.model_dump())
    await db.commit()
    return FinancialEventResponse(**dict(result.mappings().first()))


# ============================================================
#  DASHBOARD STATS (aggregated)
# ============================================================

@router.get("/dashboard")
async def dashboard_stats(db: AsyncSession = Depends(get_db)):
    """Aggregated stats for the ranch dashboard."""
    stats = {}

    # Animal counts by status
    result = await db.execute(text("""
        SELECT status, COUNT(*) as count FROM animals GROUP BY status
    """))
    stats["animals_by_status"] = {r["status"]: r["count"] for r in result.mappings().all()}

    # Animal counts by category
    result = await db.execute(text("""
        SELECT category, COUNT(*) as count FROM animals WHERE status = 'active' GROUP BY category
    """))
    stats["animals_by_category"] = {r["category"]: r["count"] for r in result.mappings().all()}

    # Total active animals
    result = await db.execute(text("SELECT COUNT(*) as total FROM animals WHERE status = 'active'"))
    stats["total_active"] = result.scalar()

    # Upcoming medical events (next 7 days)
    result = await db.execute(text("""
        SELECT COUNT(*) as count FROM medical_records
        WHERE next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
    """))
    stats["upcoming_medical_7d"] = result.scalar()

    # Expected births (next 30 days)
    result = await db.execute(text("""
        SELECT COUNT(*) as count FROM reproductive_events
        WHERE expected_birth_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
          AND pregnancy_confirmed = TRUE
    """))
    stats["expected_births_30d"] = result.scalar()

    # Unacknowledged alerts
    result = await db.execute(text("""
        SELECT COUNT(*) as count FROM alerts_log WHERE acknowledged = FALSE
    """))
    stats["unacknowledged_alerts"] = result.scalar()

    return stats
