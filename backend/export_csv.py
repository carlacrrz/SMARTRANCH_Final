"""
Smart Ranch — CSV Export Endpoints
Export ranch data as CSV for Excel compatibility.
"""
import csv
import io
import logging
from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db

log = logging.getLogger("export")

export_router = APIRouter(prefix="/api/export", tags=["Export"])


def _make_csv_response(rows: list[dict], filename: str) -> StreamingResponse:
    """Create a CSV StreamingResponse from a list of dicts."""
    if not rows:
        return StreamingResponse(
            iter(["Sin datos"]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )

    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
    output.seek(0)

    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@export_router.get("/animals")
async def export_animals(db: AsyncSession = Depends(get_db)):
    """Export all animals as CSV."""
    result = await db.execute(text("""
        SELECT id, name, ear_tag, breed, sex, birth_date, weight_kg,
               category, status, device_id, notes, created_at
        FROM animals ORDER BY name
    """))
    rows = [dict(r) for r in result.mappings().all()]
    return _make_csv_response(rows, "animales.csv")


@export_router.get("/medical")
async def export_medical(
    animal_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Export medical records as CSV."""
    query = """
        SELECT mr.id, a.name as animal, mr.record_type, mr.product_name,
               mr.dose, mr.administered_by, mr.cost, mr.notes,
               mr.next_due_date, mr.recorded_at
        FROM medical_records mr
        JOIN animals a ON mr.animal_id = a.id
    """
    params = {}
    if animal_id:
        query += " WHERE mr.animal_id = :aid"
        params["aid"] = animal_id
    query += " ORDER BY mr.recorded_at DESC"

    result = await db.execute(text(query), params)
    rows = [dict(r) for r in result.mappings().all()]
    return _make_csv_response(rows, "registros_medicos.csv")


@export_router.get("/weights")
async def export_weights(
    animal_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Export weight records as CSV."""
    query = """
        SELECT wr.id, a.name as animal, wr.weight_kg,
               wr.body_condition_score, wr.notes, wr.recorded_at
        FROM weight_records wr
        JOIN animals a ON wr.animal_id = a.id
    """
    params = {}
    if animal_id:
        query += " WHERE wr.animal_id = :aid"
        params["aid"] = animal_id
    query += " ORDER BY wr.recorded_at DESC"

    result = await db.execute(text(query), params)
    rows = [dict(r) for r in result.mappings().all()]
    return _make_csv_response(rows, "pesajes.csv")


@export_router.get("/financial")
async def export_financial(db: AsyncSession = Depends(get_db)):
    """Export financial events as CSV."""
    result = await db.execute(text("""
        SELECT fe.id, a.name as animal, fe.event_type, fe.amount,
               fe.buyer_seller, fe.weight_at_event, fe.notes, fe.recorded_at
        FROM financial_events fe
        LEFT JOIN animals a ON fe.animal_id = a.id
        ORDER BY fe.recorded_at DESC
    """))
    rows = [dict(r) for r in result.mappings().all()]
    return _make_csv_response(rows, "movimientos_financieros.csv")


@export_router.get("/alerts")
async def export_alerts(db: AsyncSession = Depends(get_db)):
    """Export alerts as CSV."""
    result = await db.execute(text("""
        SELECT al.id, a.name as animal, al.device_id, al.alert_type,
               al.severity, al.message, al.acknowledged,
               al.acknowledged_by, al.created_at
        FROM alerts_log al
        LEFT JOIN animals a ON al.animal_id = a.id
        ORDER BY al.created_at DESC
    """))
    rows = [dict(r) for r in result.mappings().all()]
    return _make_csv_response(rows, "alertas.csv")
