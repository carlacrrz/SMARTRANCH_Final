"""
Smart Ranch — MQTT Bridge
Subscribes to ESP32 telemetry, calculates THI, stores in InfluxDB,
and publishes alerts back to MQTT.
"""
import os
import sys
import json
import time
import signal
import logging
from datetime import datetime, timezone

import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
from dotenv import load_dotenv

load_dotenv()

# PostgreSQL writer (for alerts, GPS, geofence)
try:
    import pg_writer
    PG_ENABLED = True
except ImportError:
    PG_ENABLED = False

# --- Configuration ---
MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
INFLUX_URL = os.getenv("INFLUX_URL", "http://localhost:8086")
INFLUX_TOKEN = os.getenv("INFLUX_TOKEN", "smart-ranch-dev-token")
INFLUX_ORG = os.getenv("INFLUX_ORG", "smart_ranch")
INFLUX_BUCKET = os.getenv("INFLUX_BUCKET", "telemetry")

TELEMETRY_TOPIC = "ranch/+/telemetry"
TROUGH_TELEMETRY_TOPIC = "ranch/trough/+/telemetry"
ALERT_TOPIC_TEMPLATE = "ranch/{device_id}/alert"
WATER_ALERT_TEMPLATE = "ranch/trough/{trough_id}/alert"
WATER_LOW_THRESHOLD = 20.0  # percent

# --- Logging ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("bridge")

# --- THI Calculation ---
# THI = (1.8 × T + 32) − (0.55 − 0.0055 × RH) × (1.8 × T − 26)
# Categories:
#   < 72    → Normal (green)
#   72-79   → Alert  (yellow)
#   79-89   → Danger (orange)
#   >= 89   → Emergency (red)

THI_THRESHOLDS = [
    (89, "emergency", "🔴 EMERGENCIA: Intervención inmediata requerida"),
    (79, "danger",    "🔶 PELIGRO: Proveer sombra y agua inmediatamente"),
    (72, "alert",     "⚠️ ALERTA: Monitorear de cerca"),
    (0,  "normal",    "✅ Normal"),
]

# --- Estrus (Celo) Detection ---
# Cows in estrus show ~70-80% increase in movement intensity.
# We track a rolling baseline per animal and detect sustained spikes.
ESTRUS_ACTIVITY_MULTIPLIER = 1.7    # 70% above baseline = possible estrus
ESTRUS_CONSECUTIVE_THRESHOLD = 6    # 6 consecutive readings (~30s at 5s/read)
ESTRUS_BASELINE_WINDOW = 120        # Rolling window of readings for baseline

# Per-device activity tracking
_activity_history: dict[str, list[float]] = {}     # recent movement_intensity values
_estrus_spike_count: dict[str, int] = {}            # consecutive above-threshold count
_active_estrus_alerts: dict[str, bool] = {}         # currently in estrus?

REPRODUCTION_ALERT_TEMPLATE = "ranch/{device_id}/alert/reproduction"
GEOFENCE_ALERT_TEMPLATE = "ranch/{device_id}/alert/geofence"

# --- Health Detection ---
# Cross fever (body_temp > 40°C) with lethargy (movement < 0.3)
FEVER_TEMP_THRESHOLD = 40.0          # °C
LETHARGY_MOVEMENT_THRESHOLD = 0.3
FEVER_CONSECUTIVE_THRESHOLD = 3      # 3 readings (~15s)
LETHARGY_CONSECUTIVE_THRESHOLD = 6   # 6 readings (~30s)

_fever_count: dict[str, int] = {}
_lethargy_count: dict[str, int] = {}
_active_health_alerts: dict[str, str] = {}  # device_id -> status

HEALTH_ALERT_TEMPLATE = "ranch/{device_id}/alert/health"


def calculate_thi(ambient_temp: float, humidity: float) -> float:
    """Calculate Temperature-Humidity Index."""
    thi = (1.8 * ambient_temp + 32) - (0.55 - 0.0055 * humidity) * (1.8 * ambient_temp - 26)
    return round(thi, 2)


def get_thi_level(thi: float) -> tuple[str, str]:
    """Return (level, message) based on THI value."""
    for threshold, level, message in THI_THRESHOLDS:
        if thi >= threshold:
            return level, message
    return "normal", "✅ Normal"


# --- InfluxDB ---
influx_client: InfluxDBClient | None = None
write_api = None


def init_influxdb():
    global influx_client, write_api
    try:
        influx_client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
        write_api = influx_client.write_api(write_options=SYNCHRONOUS)
        # Test connection
        influx_client.ping()
        log.info("✅ Connected to InfluxDB at %s", INFLUX_URL)
    except Exception as e:
        log.error("❌ Failed to connect to InfluxDB: %s", e)
        sys.exit(1)


def write_telemetry(
    device_id: str, data: dict, thi: float, level: str,
    estrus_score: float = 0.0, health_status: str = "healthy",
):
    """Write a telemetry point to InfluxDB."""
    point = (
        Point("telemetry")
        .tag("device_id", device_id)
        .tag("thi_level", level)
        .tag("health_status", health_status)
        .field("body_temp", float(data.get("body_temp", 0)))
        .field("ambient_temp", float(data.get("ambient_temp", 0)))
        .field("humidity", float(data.get("humidity", 0)))
        .field("thi", float(thi))
        .field("accel_x", float(data.get("accel_x", 0)))
        .field("accel_y", float(data.get("accel_y", 0)))
        .field("accel_z", float(data.get("accel_z", 0)))
        .field("movement_intensity", float(data.get("movement_intensity", 0)))
        .field("estrus_score", estrus_score)
    )
    try:
        write_api.write(bucket=INFLUX_BUCKET, record=point)
    except Exception as e:
        log.error("Failed to write to InfluxDB: %s", e)


def write_trough_telemetry(trough_id: str, data: dict):
    """Write a trough level point to InfluxDB."""
    point = (
        Point("trough_level")
        .tag("trough_id", trough_id)
        .field("level_percent", float(data.get("level_percent", 0)))
        .field("distance_cm", float(data.get("distance_cm", 0)))
        .field("tank_depth_cm", float(data.get("tank_depth_cm", 100)))
    )
    try:
        write_api.write(bucket=INFLUX_BUCKET, record=point)
    except Exception as e:
        log.error("Failed to write trough data to InfluxDB: %s", e)


# --- Estrus Detection ---
def check_estrus_activity(device_id: str, movement_intensity: float) -> float:
    """Check if an animal shows estrus-like activity patterns.
    Returns estrus_score (0.0-1.0) based on activity vs baseline."""
    # Update history
    if device_id not in _activity_history:
        _activity_history[device_id] = []
    _activity_history[device_id].append(movement_intensity)
    if len(_activity_history[device_id]) > ESTRUS_BASELINE_WINDOW:
        _activity_history[device_id].pop(0)

    history = _activity_history[device_id]
    if len(history) < 10:
        return 0.0  # Not enough data for baseline

    # Calculate baseline (average of recent window, excluding top 10%)
    sorted_history = sorted(history)
    trim_count = max(1, len(sorted_history) // 10)
    baseline_values = sorted_history[:-trim_count] if trim_count > 0 else sorted_history
    baseline = sum(baseline_values) / len(baseline_values) if baseline_values else 1.0
    baseline = max(baseline, 0.1)  # prevent division by zero

    # Calculate estrus score
    ratio = movement_intensity / baseline
    estrus_score = min(1.0, max(0.0, (ratio - 1.0) / (ESTRUS_ACTIVITY_MULTIPLIER - 1.0)))

    # Track consecutive spikes
    if ratio >= ESTRUS_ACTIVITY_MULTIPLIER:
        _estrus_spike_count[device_id] = _estrus_spike_count.get(device_id, 0) + 1
    else:
        _estrus_spike_count[device_id] = 0

    # Detect estrus onset
    spike_count = _estrus_spike_count.get(device_id, 0)
    was_in_estrus = _active_estrus_alerts.get(device_id, False)

    if spike_count >= ESTRUS_CONSECUTIVE_THRESHOLD and not was_in_estrus:
        _active_estrus_alerts[device_id] = True
        estrus_score = 1.0
    elif spike_count == 0 and was_in_estrus:
        _active_estrus_alerts[device_id] = False

    return estrus_score


def publish_estrus_alert(client, device_id: str, data: dict, estrus_score: float):
    """Publish estrus detection alert via MQTT."""
    alert_payload = json.dumps({
        "device_id": device_id,
        "animal_name": data.get("animal_name", ""),
        "type": "estrus_detected",
        "estrus_score": estrus_score,
        "movement_intensity": data.get("movement_intensity", 0),
        "message": "💕 Posible celo detectado — actividad elevada sostenida",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    topic = REPRODUCTION_ALERT_TEMPLATE.format(device_id=device_id)
    client.publish(topic, alert_payload, qos=1)
    log.info("💕 Estrus alert for %s (score=%.2f)", device_id, estrus_score)


# --- Health Detection ---
def check_health_status(device_id: str, body_temp: float, movement_intensity: float) -> str:
    """Check for fever + lethargy patterns indicating illness.
    Returns health_status: 'healthy', 'fever', 'lethargy', 'sick_suspected'."""
    # Track fever
    if body_temp >= FEVER_TEMP_THRESHOLD:
        _fever_count[device_id] = _fever_count.get(device_id, 0) + 1
    else:
        _fever_count[device_id] = 0

    # Track lethargy
    if movement_intensity <= LETHARGY_MOVEMENT_THRESHOLD:
        _lethargy_count[device_id] = _lethargy_count.get(device_id, 0) + 1
    else:
        _lethargy_count[device_id] = 0

    has_fever = _fever_count.get(device_id, 0) >= FEVER_CONSECUTIVE_THRESHOLD
    has_lethargy = _lethargy_count.get(device_id, 0) >= LETHARGY_CONSECUTIVE_THRESHOLD

    if has_fever and has_lethargy:
        status = "sick_suspected"
    elif has_fever:
        status = "fever"
    elif has_lethargy:
        status = "lethargy"
    else:
        status = "healthy"

    prev_status = _active_health_alerts.get(device_id, "healthy")
    _active_health_alerts[device_id] = status

    return status


def publish_health_alert(client, device_id: str, data: dict, health_status: str):
    """Publish health alert via MQTT."""
    messages = {
        "fever": "🌡️ Fiebre detectada — temperatura corporal elevada sostenida",
        "lethargy": "😴 Letargo detectado — actividad muy baja sostenida",
        "sick_suspected": "🏥 ¡Posible enfermedad! Fiebre + letargo — revisar al animal",
    }
    alert_payload = json.dumps({
        "device_id": device_id,
        "animal_name": data.get("animal_name", ""),
        "type": health_status,
        "body_temp": data.get("body_temp", 0),
        "movement_intensity": data.get("movement_intensity", 0),
        "message": messages.get(health_status, ""),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    topic = HEALTH_ALERT_TEMPLATE.format(device_id=device_id)
    client.publish(topic, alert_payload, qos=1)
    log.warning("🏥 Health alert for %s: %s", device_id, health_status)


# --- MQTT Callbacks ---
def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code == 0:
        log.info("✅ Connected to MQTT broker at %s:%s", MQTT_HOST, MQTT_PORT)
        client.subscribe(TELEMETRY_TOPIC)
        client.subscribe(TROUGH_TELEMETRY_TOPIC)
        client.subscribe("ranch/+/gps")
        log.info("📡 Subscribed to %s, %s, and ranch/+/gps", TELEMETRY_TOPIC, TROUGH_TELEMETRY_TOPIC)
    else:
        log.error("❌ MQTT connection failed: %s", reason_code)


def on_trough_message(client, topic: str, data: dict):
    """Process incoming trough/water level telemetry."""
    parts = topic.split("/")
    if len(parts) < 4:
        return
    trough_id = parts[2]  # ranch/trough/{trough_id}/telemetry

    level = data.get("level_percent", 0)
    log.info("💧 [%s] Level=%.1f%% Distance=%.1fcm", trough_id, level, data.get("distance_cm", 0))

    write_trough_telemetry(trough_id, data)

    # Publish alert if water level is low
    if level <= WATER_LOW_THRESHOLD:
        alert_payload = json.dumps({
            "trough_id": trough_id,
            "level_percent": level,
            "message": f"💧 ¡Nivel bajo de agua! Bebedero {trough_id} al {level:.0f}%",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        alert_topic = WATER_ALERT_TEMPLATE.format(trough_id=trough_id)
        client.publish(alert_topic, alert_payload, qos=1)
        log.warning("💧 Water alert for trough %s: %.1f%%", trough_id, level)


def on_message(client, userdata, msg):
    """Process incoming telemetry from ESP32 devices."""
    try:
        # Route trough messages to dedicated handler
        if "/trough/" in msg.topic:
            data = json.loads(msg.payload.decode("utf-8"))
            on_trough_message(client, msg.topic, data)
            return

        # Route GPS messages from dedicated GPS topic
        if msg.topic.endswith("/gps"):
            data = json.loads(msg.payload.decode("utf-8"))
            parts = msg.topic.split("/")
            device_id = parts[1] if len(parts) >= 3 else data.get("device_id", "unknown")
            lat = data.get("latitude")
            lng = data.get("longitude")
            if PG_ENABLED and lat and lng:
                pg_writer.write_gps_position(
                    device_id, lat, lng,
                    speed=data.get("speed"),
                    hdop=data.get("hdop"),
                    battery_level=((data.get("battery_v", 3.7) - 3.3) / 0.9) * 100,
                )
                violations = pg_writer.check_geofence(device_id, lat, lng)
                if violations:
                    for zone in violations:
                        alert_payload = json.dumps({
                            "device_id": device_id,
                            "type": "geofence_exit",
                            "zone": zone,
                            "latitude": lat, "longitude": lng,
                            "message": f"📍 Salió de zona: {zone['zone_name']}",
                            "timestamp": datetime.now(timezone.utc).isoformat(),
                        })
                        topic = GEOFENCE_ALERT_TEMPLATE.format(device_id=device_id)
                        client.publish(topic, alert_payload, qos=1)
                        pg_writer.write_alert(device_id, "geofence_exit", "warning",
                            f"Salió de zona: {zone['zone_name']}")
                log.info("📍 GPS [%s] lat=%.6f lng=%.6f speed=%.1f", device_id, lat, lng,
                         data.get("speed", 0))
            return

        # Extract device_id from topic: ranch/{device_id}/telemetry
        parts = msg.topic.split("/")
        if len(parts) < 3:
            return
        device_id = parts[1]

        # Parse JSON payload
        data = json.loads(msg.payload.decode("utf-8"))

        # Calculate THI
        ambient_temp = data.get("ambient_temp", 0)
        humidity = data.get("humidity", 0)
        thi = calculate_thi(ambient_temp, humidity)
        level, message = get_thi_level(thi)

        body_temp = data.get("body_temp", 0)
        movement_intensity = data.get("movement_intensity", 0)

        # --- GPS Data ---
        latitude = data.get("latitude")
        longitude = data.get("longitude")
        if PG_ENABLED and latitude and longitude:
            pg_writer.write_gps_position(
                device_id, latitude, longitude,
                altitude=data.get("altitude"),
                speed=data.get("gps_speed"),
                heading=data.get("heading"),
                hdop=data.get("hdop"),
            )
            # --- Geofence Check ---
            violations = pg_writer.check_geofence(device_id, latitude, longitude)
            if violations:
                for zone in violations:
                    msg = f"📍 Salió de zona: {zone['zone_name']}"
                    alert_payload = json.dumps({
                        "device_id": device_id,
                        "type": "geofence_exit",
                        "zone": zone,
                        "latitude": latitude,
                        "longitude": longitude,
                        "message": msg,
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    })
                    topic = GEOFENCE_ALERT_TEMPLATE.format(device_id=device_id)
                    client.publish(topic, alert_payload, qos=1)
                    log.warning("📍 Geofence alert for %s: %s", device_id, msg)
                    pg_writer.write_alert(
                        device_id, "geofence_exit", "warning", msg,
                        {"zone": zone, "lat": latitude, "lng": longitude},
                    )

        # --- Estrus Detection ---
        estrus_score = check_estrus_activity(device_id, movement_intensity)
        if _active_estrus_alerts.get(device_id, False) and estrus_score >= 0.9:
            publish_estrus_alert(client, device_id, data, estrus_score)
            if PG_ENABLED:
                pg_writer.write_alert(
                    device_id, "estrus_detected", "info",
                    f"Posible celo detectado (score={estrus_score:.2f})",
                    {"estrus_score": estrus_score, "movement_intensity": movement_intensity},
                )

        # --- Health Detection ---
        health_status = check_health_status(device_id, body_temp, movement_intensity)
        if health_status != "healthy":
            prev = _active_health_alerts.get(device_id, "healthy")
            # Publish alert on status change or escalation
            if health_status != prev or health_status == "sick_suspected":
                publish_health_alert(client, device_id, data, health_status)
                if PG_ENABLED:
                    severity = "emergency" if health_status == "sick_suspected" else "warning"
                    pg_writer.write_alert(
                        device_id, f"health_{health_status}", severity,
                        f"Alerta de salud: {health_status}",
                        {"body_temp": body_temp, "movement": movement_intensity},
                    )

        # Log to console
        log.info(
            "🐄 [%s] Body=%.1f°C Ambient=%.1f°C Hum=%.0f%% THI=%.1f [%s] Estrus=%.2f Health=%s",
            device_id, body_temp, ambient_temp, humidity, thi, level.upper(),
            estrus_score, health_status,
        )

        # Store in InfluxDB (with new fields)
        write_telemetry(device_id, data, thi, level, estrus_score, health_status)

        # Publish THI alert if THI >= danger threshold
        if thi >= 79:
            alert_payload = json.dumps({
                "device_id": device_id,
                "thi": thi,
                "level": level,
                "message": message,
                "body_temp": body_temp,
                "ambient_temp": ambient_temp,
                "humidity": humidity,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            })
            alert_topic = ALERT_TOPIC_TEMPLATE.format(device_id=device_id)
            client.publish(alert_topic, alert_payload, qos=1)
            log.warning("🚨 Alert published to %s: %s", alert_topic, message)
            if PG_ENABLED:
                alert_type = "thi_emergency" if thi >= 89 else "thi_danger"
                pg_writer.write_alert(
                    device_id, alert_type, level, message,
                    {"thi": thi, "ambient_temp": ambient_temp, "humidity": humidity},
                )

    except json.JSONDecodeError:
        log.error("Invalid JSON payload: %s", msg.payload)
    except Exception as e:
        log.error("Error processing message: %s", e)


def on_disconnect(client, userdata, flags, reason_code, properties):
    log.warning("⚡ Disconnected from MQTT (rc=%s). Reconnecting...", reason_code)


# --- Main ---
def main():
    log.info("🐄 Smart Ranch Bridge — Starting up...")

    # Init InfluxDB
    init_influxdb()

    # Init MQTT client
    client = mqtt.Client(
        callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
        client_id="smart_ranch_bridge",
    )
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect

    # Graceful shutdown
    def shutdown(sig, frame):
        log.info("🛑 Shutting down...")
        client.disconnect()
        if influx_client:
            influx_client.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Connect and loop
    try:
        client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
        log.info("🔄 Waiting for telemetry data...")
        client.loop_forever()
    except KeyboardInterrupt:
        shutdown(None, None)
    except Exception as e:
        log.error("❌ Fatal error: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
