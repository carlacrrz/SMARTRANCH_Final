"""
Smart Ranch — Pydantic Models
Request/response schemas for the REST API.
"""
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field


# ============================================================
#  Animals
# ============================================================
class AnimalCreate(BaseModel):
    device_id: Optional[str] = None
    name: str
    ear_tag: Optional[str] = None
    breed: Optional[str] = None
    sex: str = Field(pattern=r"^(male|female)$")
    birth_date: Optional[date] = None
    weight_kg: Optional[float] = None
    category: str = "cow"
    mother_id: Optional[int] = None
    father_id: Optional[int] = None
    status: str = "active"
    photo_url: Optional[str] = None
    notes: Optional[str] = None


class AnimalUpdate(BaseModel):
    device_id: Optional[str] = None
    name: Optional[str] = None
    ear_tag: Optional[str] = None
    breed: Optional[str] = None
    sex: Optional[str] = None
    birth_date: Optional[date] = None
    weight_kg: Optional[float] = None
    category: Optional[str] = None
    mother_id: Optional[int] = None
    father_id: Optional[int] = None
    status: Optional[str] = None
    photo_url: Optional[str] = None
    notes: Optional[str] = None


class AnimalResponse(BaseModel):
    id: int
    device_id: Optional[str] = None
    name: str
    ear_tag: Optional[str] = None
    breed: Optional[str] = None
    sex: str
    birth_date: Optional[date] = None
    weight_kg: Optional[float] = None
    category: str
    mother_id: Optional[int] = None
    father_id: Optional[int] = None
    status: str
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  Medical Records
# ============================================================
class MedicalRecordCreate(BaseModel):
    animal_id: int
    record_type: str
    product_name: Optional[str] = None
    dose: Optional[str] = None
    administered_by: Optional[str] = None
    cost: Optional[float] = None
    notes: Optional[str] = None
    next_due_date: Optional[date] = None
    withdrawal_days: int = 0


class MedicalRecordResponse(BaseModel):
    id: int
    animal_id: int
    record_type: str
    product_name: Optional[str] = None
    dose: Optional[str] = None
    administered_by: Optional[str] = None
    cost: Optional[float] = None
    notes: Optional[str] = None
    next_due_date: Optional[date] = None
    withdrawal_days: int
    recorded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  Reproductive Events
# ============================================================
class ReproductiveEventCreate(BaseModel):
    animal_id: int
    event_type: str
    bull_or_semen: Optional[str] = None
    pregnancy_confirmed: Optional[bool] = None
    expected_birth_date: Optional[date] = None
    calf_id: Optional[int] = None
    notes: Optional[str] = None


class ReproductiveEventResponse(BaseModel):
    id: int
    animal_id: int
    event_type: str
    bull_or_semen: Optional[str] = None
    pregnancy_confirmed: Optional[bool] = None
    expected_birth_date: Optional[date] = None
    calf_id: Optional[int] = None
    notes: Optional[str] = None
    recorded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  Weight Records
# ============================================================
class WeightRecordCreate(BaseModel):
    animal_id: int
    weight_kg: float
    body_condition_score: Optional[int] = Field(None, ge=1, le=9)
    notes: Optional[str] = None


class WeightRecordResponse(BaseModel):
    id: int
    animal_id: int
    weight_kg: float
    body_condition_score: Optional[int] = None
    notes: Optional[str] = None
    recorded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  GPS Zones
# ============================================================
class GpsZoneCreate(BaseModel):
    name: str
    zone_type: str = "pasture"
    coordinates: list[list[float]]  # [[lng, lat], [lng, lat], ...]
    color: str = "#4CAF50"
    alert_on_exit: bool = True
    alert_on_enter: bool = False
    notes: Optional[str] = None


class GpsZoneResponse(BaseModel):
    id: int
    name: str
    zone_type: str
    coordinates: Optional[list[list[float]]] = None
    color: str
    alert_on_exit: bool
    alert_on_enter: bool
    notes: Optional[str] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  Alerts Log
# ============================================================
class AlertCreate(BaseModel):
    animal_id: Optional[int] = None
    device_id: Optional[str] = None
    alert_type: str
    severity: str = "warning"
    message: Optional[str] = None
    metadata: Optional[dict] = None


class AlertAcknowledge(BaseModel):
    acknowledged_by: str


class AlertResponse(BaseModel):
    id: int
    animal_id: Optional[int] = None
    device_id: Optional[str] = None
    alert_type: str
    severity: str
    message: Optional[str] = None
    metadata: Optional[dict] = None
    acknowledged: bool
    acknowledged_by: Optional[str] = None
    acknowledged_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  Feed Records
# ============================================================
class FeedRecordCreate(BaseModel):
    animal_id: Optional[int] = None
    group_name: Optional[str] = None
    feed_type: str
    quantity_kg: Optional[float] = None
    cost: Optional[float] = None
    notes: Optional[str] = None


class FeedRecordResponse(BaseModel):
    id: int
    animal_id: Optional[int] = None
    group_name: Optional[str] = None
    feed_type: str
    quantity_kg: Optional[float] = None
    cost: Optional[float] = None
    notes: Optional[str] = None
    recorded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  Financial Events
# ============================================================
class FinancialEventCreate(BaseModel):
    animal_id: Optional[int] = None
    event_type: str
    amount: float
    buyer_seller: Optional[str] = None
    weight_at_event: Optional[float] = None
    notes: Optional[str] = None


class FinancialEventResponse(BaseModel):
    id: int
    animal_id: Optional[int] = None
    event_type: str
    amount: float
    buyer_seller: Optional[str] = None
    weight_at_event: Optional[float] = None
    notes: Optional[str] = None
    recorded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
#  GPS Position (for queries only, written by bridge)
# ============================================================
class GpsPositionResponse(BaseModel):
    id: int
    device_id: str
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    speed: Optional[float] = None
    heading: Optional[float] = None
    hdop: Optional[float] = None
    recorded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
