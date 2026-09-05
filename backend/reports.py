"""
Smart Ranch — PDF Report Generator
Generates ranch status reports as downloadable HTML/PDF.
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import HTMLResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db

log = logging.getLogger("reports")

report_router = APIRouter(prefix="/api/reports", tags=["Reports"])


@report_router.get("/ranch-status", response_class=HTMLResponse)
async def ranch_status_report(
    format: str = Query("html", description="html or json"),
    db: AsyncSession = Depends(get_db),
):
    """Generate a comprehensive ranch status report."""
    now = datetime.now(timezone.utc)

    # Gather data
    animals = await db.execute(text("SELECT * FROM animals WHERE status = 'active' ORDER BY name"))
    animal_rows = [dict(r) for r in animals.mappings().all()]

    by_category = {}
    for a in animal_rows:
        cat = a.get("category", "otro")
        by_category[cat] = by_category.get(cat, 0) + 1

    # Medical upcoming
    medical = await db.execute(text("""
        SELECT mr.*, a.name as animal_name FROM medical_records mr
        JOIN animals a ON mr.animal_id = a.id
        WHERE mr.next_due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '14 days'
        ORDER BY mr.next_due_date
    """))
    medical_rows = [dict(r) for r in medical.mappings().all()]

    # Expected births
    births = await db.execute(text("""
        SELECT re.*, a.name as animal_name FROM reproductive_events re
        JOIN animals a ON re.animal_id = a.id
        WHERE re.expected_birth_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days'
          AND re.pregnancy_confirmed = TRUE
        ORDER BY re.expected_birth_date
    """))
    birth_rows = [dict(r) for r in births.mappings().all()]

    # Recent alerts
    alerts = await db.execute(text("""
        SELECT * FROM alerts_log WHERE acknowledged = FALSE
        ORDER BY created_at DESC LIMIT 20
    """))
    alert_rows = [dict(r) for r in alerts.mappings().all()]

    # Average weight by category
    weights = await db.execute(text("""
        SELECT a.category, ROUND(AVG(a.weight_kg)::numeric, 1) as avg_weight,
               COUNT(*) as count
        FROM animals a WHERE a.status = 'active' AND a.weight_kg IS NOT NULL
        GROUP BY a.category
    """))
    weight_rows = [dict(r) for r in weights.mappings().all()]

    # Financial summary (last 30 days)
    financial = await db.execute(text("""
        SELECT event_type, SUM(amount) as total, COUNT(*) as count
        FROM financial_events
        WHERE recorded_at >= NOW() - INTERVAL '30 days'
        GROUP BY event_type
    """))
    fin_rows = [dict(r) for r in financial.mappings().all()]

    if format == "json":
        from fastapi.responses import JSONResponse
        return JSONResponse({
            "generated_at": now.isoformat(),
            "total_animals": len(animal_rows),
            "by_category": by_category,
            "upcoming_medical": len(medical_rows),
            "expected_births": len(birth_rows),
            "unacknowledged_alerts": len(alert_rows),
            "weight_averages": weight_rows,
            "financial_30d": fin_rows,
            "animals": animal_rows,
        })

    # HTML report
    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte Smart Ranch — {now.strftime('%d/%m/%Y')}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: 'Segoe UI', system-ui, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 40px; }}
        .header {{ text-align: center; margin-bottom: 30px; }}
        .header h1 {{ color: #4ade80; font-size: 28px; }}
        .header p {{ color: #888; font-size: 14px; margin-top: 4px; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin: 20px 0; }}
        .kpi {{ background: #16213e; padding: 20px; border-radius: 12px; text-align: center; border: 1px solid #2a2a4a; }}
        .kpi .number {{ font-size: 32px; font-weight: 800; color: #4ade80; }}
        .kpi .label {{ font-size: 12px; color: #888; margin-top: 4px; }}
        .section {{ margin: 30px 0; }}
        .section h2 {{ color: #4ade80; font-size: 18px; margin-bottom: 12px; border-bottom: 1px solid #2a2a4a; padding-bottom: 6px; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th, td {{ padding: 8px 12px; text-align: left; border-bottom: 1px solid #2a2a4a; font-size: 13px; }}
        th {{ color: #4ade80; font-weight: 600; }}
        .badge {{ display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 11px; }}
        .badge-warning {{ background: rgba(251,191,36,0.2); color: #fbbf24; }}
        .badge-danger {{ background: rgba(239,68,68,0.2); color: #ef4444; }}
        .badge-success {{ background: rgba(74,222,128,0.2); color: #4ade80; }}
        .footer {{ text-align: center; margin-top: 40px; color: #555; font-size: 11px; }}
        @media print {{ body {{ background: white; color: #333; }} .kpi {{ border-color: #ddd; }} .section h2 {{ color: #2d5016; }} th {{ color: #2d5016; }} }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🐄 Smart Ranch — Reporte de Estatus</h1>
        <p>Rancho Cananea, Sonora — Generado: {now.strftime('%d/%m/%Y %H:%M')} UTC</p>
    </div>

    <div class="grid">
        <div class="kpi">
            <div class="number">{len(animal_rows)}</div>
            <div class="label">Cabezas Activas</div>
        </div>
        <div class="kpi">
            <div class="number">{len(medical_rows)}</div>
            <div class="label">Eventos Médicos Próximos</div>
        </div>
        <div class="kpi">
            <div class="number">{len(birth_rows)}</div>
            <div class="label">Partos Esperados (60d)</div>
        </div>
        <div class="kpi">
            <div class="number">{len(alert_rows)}</div>
            <div class="label">Alertas Sin Atender</div>
        </div>
    </div>

    <div class="section">
        <h2>📊 Inventario por Categoría</h2>
        <table>
            <tr><th>Categoría</th><th>Cantidad</th><th>% del Hato</th></tr>
            {"".join(f'<tr><td>{cat}</td><td>{count}</td><td>{count * 100 // max(len(animal_rows), 1)}%</td></tr>' for cat, count in by_category.items())}
        </table>
    </div>

    <div class="section">
        <h2>⚖️ Peso Promedio por Categoría</h2>
        <table>
            <tr><th>Categoría</th><th>Peso Prom. (kg)</th><th>Conteo</th></tr>
            {"".join(f'<tr><td>{w["category"]}</td><td>{w["avg_weight"]}</td><td>{w["count"]}</td></tr>' for w in weight_rows)}
        </table>
    </div>

    {"" if not medical_rows else f'''<div class="section">
        <h2>💉 Eventos Médicos Próximos (14 días)</h2>
        <table>
            <tr><th>Animal</th><th>Tipo</th><th>Producto</th><th>Fecha</th></tr>
            {"".join(f'<tr><td>{m.get("animal_name","")}</td><td>{m.get("record_type","")}</td><td>{m.get("product_name","—")}</td><td>{m.get("next_due_date","—")}</td></tr>' for m in medical_rows)}
        </table>
    </div>'''}

    {"" if not birth_rows else f'''<div class="section">
        <h2>🐣 Partos Esperados (60 días)</h2>
        <table>
            <tr><th>Animal</th><th>Toro/Semen</th><th>Fecha Esperada</th></tr>
            {"".join(f'<tr><td>{b.get("animal_name","")}</td><td>{b.get("bull_or_semen","—")}</td><td>{b.get("expected_birth_date","—")}</td></tr>' for b in birth_rows)}
        </table>
    </div>'''}

    {"" if not alert_rows else f'''<div class="section">
        <h2>⚠️ Alertas Sin Atender</h2>
        <table>
            <tr><th>Tipo</th><th>Severidad</th><th>Mensaje</th><th>Fecha</th></tr>
            {"".join(f'<tr><td>{a.get("alert_type","")}</td><td><span class="badge badge-{"danger" if a.get("severity") in ("emergency","danger") else "warning"}">{a.get("severity","")}</span></td><td>{a.get("message","")}</td><td>{a.get("created_at","")}</td></tr>' for a in alert_rows)}
        </table>
    </div>'''}

    {"" if not fin_rows else f'''<div class="section">
        <h2>💰 Resumen Financiero (30 días)</h2>
        <table>
            <tr><th>Tipo</th><th>Total</th><th>Movimientos</th></tr>
            {"".join(f'<tr><td>{f.get("event_type","")}</td><td>${f.get("total",0):,.2f}</td><td>{f.get("count",0)}</td></tr>' for f in fin_rows)}
        </table>
    </div>'''}

    <div class="section">
        <h2>🐄 Lista Completa del Hato</h2>
        <table>
            <tr><th>Nombre</th><th>Arete</th><th>Categoría</th><th>Sexo</th><th>Peso (kg)</th><th>Raza</th></tr>
            {"".join(f'<tr><td>{a.get("name","")}</td><td>{a.get("ear_tag","—")}</td><td>{a.get("category","")}</td><td>{a.get("sex","")}</td><td>{a.get("weight_kg","—")}</td><td>{a.get("breed","—")}</td></tr>' for a in animal_rows)}
        </table>
    </div>

    <div class="footer">
        <p>Smart Ranch v2.0 — Generado automáticamente. Para imprimir como PDF, use Ctrl+P → Guardar como PDF.</p>
    </div>
</body>
</html>"""

    return HTMLResponse(content=html)
