/*
 * ========================================================================
 *  Smart Ranch — ESP32 Cattle Thermal Stress Monitor
 * ========================================================================
 *  Firmware for wearable collar/ear-tag sensor node.
 *  
 *  MVP Mode: Simulates sensor readings and publishes via MQTT over WiFi.
 *  When real sensors are connected, replace the simulate_*() functions
 *  with actual sensor reading code.
 *
 *  MQTT Topics:
 *    PUBLISH:   ranch/{DEVICE_ID}/telemetry  (JSON every 5 seconds)
 *    SUBSCRIBE: ranch/{DEVICE_ID}/command     (receive commands)
 *    RECEIVE:   ranch/{DEVICE_ID}/alert       (alerts from bridge)
 * ========================================================================
 */

#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "config.h"

// --- Globals ---
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

unsigned long lastPublish = 0;
unsigned long lastGpsPublish = 0;
unsigned long lastWaterPublish = 0;
unsigned long lastWifiCheck = 0;
unsigned long messageCount = 0;

// Simulation state (smooth transitions)
float simBodyTemp     = 38.5f;
float simAmbientTemp  = 32.0f;
float simHumidity     = 40.0f;
float simAccelX       = 0.0f;
float simAccelY       = 0.0f;
float simAccelZ       = 9.8f;    // gravity
bool  simStressMode   = false;   // toggles periodically
unsigned long lastStressToggle = 0;

// GPS simulation state
float simLatitude     = SIM_GPS_CENTER_LAT;
float simLongitude    = SIM_GPS_CENTER_LNG;
float simSpeed        = 0.0f;    // km/h
float simBattery      = 4.1f;    // volts
float simWaterLevel   = 150.0f;  // cm (water depth in tank)

// --- Forward Declarations ---
void setupWiFi();
void setupMQTT();
void reconnectMQTT();
void publishTelemetry();
void publishGps();
void publishWaterLevel();
void mqttCallback(char* topic, byte* payload, unsigned int length);
float simulateBodyTemp();
float simulateAmbientTemp();
float simulateHumidity();
void simulateAccelerometer(float &x, float &y, float &z, float &intensity);
void simulateGps(float &lat, float &lng, float &speed);
float simulateBattery();
float simulateWaterLevel();
float randomFloat(float min, float max);
float smoothStep(float current, float target, float maxDelta);

// ================================================================
//  SETUP
// ================================================================
void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println();
    Serial.println("╔══════════════════════════════════════════╗");
    Serial.println("║   🐄 Smart Ranch — Thermal Monitor      ║");
    Serial.println("║   Device: " DEVICE_ID "                       ║");
    Serial.println("╚══════════════════════════════════════════╝");
    Serial.println();

    // Initialize random seed
    randomSeed(analogRead(0) + millis());

    setupWiFi();
    setupMQTT();
}

// ================================================================
//  LOOP
// ================================================================
void loop() {
    // Maintain WiFi connection
    if (WiFi.status() != WL_CONNECTED) {
        if (millis() - lastWifiCheck > 10000) {
            lastWifiCheck = millis();
            Serial.println("⚡ WiFi disconnected. Reconnecting...");
            setupWiFi();
        }
    }

    // Maintain MQTT connection
    if (!mqttClient.connected()) {
        reconnectMQTT();
    }
    mqttClient.loop();

    // Toggle stress simulation every 60 seconds (for demo variety)
    if (millis() - lastStressToggle > 60000) {
        lastStressToggle = millis();
        simStressMode = !simStressMode;
        Serial.printf("🔄 Stress simulation: %s\n", simStressMode ? "ON (hot day)" : "OFF (cool day)");
    }

    // Publish telemetry at configured interval
    if (millis() - lastPublish >= PUBLISH_INTERVAL_MS) {
        lastPublish = millis();
        publishTelemetry();
    }

    // Publish GPS at longer interval (saves battery)
    if (millis() - lastGpsPublish >= GPS_PUBLISH_INTERVAL_MS) {
        lastGpsPublish = millis();
        publishGps();
    }

    // Publish water level at configured interval
    if (millis() - lastWaterPublish >= WATER_PUBLISH_INTERVAL_MS) {
        lastWaterPublish = millis();
        publishWaterLevel();
    }
}

// ================================================================
//  WiFi
// ================================================================
void setupWiFi() {
    Serial.printf("📶 Connecting to WiFi: %s", WIFI_SSID);

    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASS);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println(" ✅");
        Serial.printf("   IP: %s\n", WiFi.localIP().toString().c_str());
        Serial.printf("   RSSI: %d dBm\n", WiFi.RSSI());
    } else {
        Serial.println(" ❌ Failed!");
        Serial.println("   Will retry in background...");
    }
}

// ================================================================
//  MQTT
// ================================================================
void setupMQTT() {
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
    mqttClient.setCallback(mqttCallback);
    mqttClient.setBufferSize(512);  // Larger buffer for JSON payloads
}

void reconnectMQTT() {
    static unsigned long lastAttempt = 0;
    if (millis() - lastAttempt < 5000) return;  // Retry every 5 seconds
    lastAttempt = millis();

    Serial.printf("🔌 Connecting to MQTT: %s:%d...", MQTT_SERVER, MQTT_PORT);

    String clientId = "esp32_" + String(DEVICE_ID);

    bool connected;
    if (strlen(MQTT_USER) > 0) {
        connected = mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS);
    } else {
        connected = mqttClient.connect(clientId.c_str());
    }

    if (connected) {
        Serial.println(" ✅");

        // Subscribe to command topic
        mqttClient.subscribe(MQTT_TOPIC_COMMAND);
        Serial.printf("   📡 Subscribed to: %s\n", MQTT_TOPIC_COMMAND);

        // Subscribe to alerts (so we can display on Serial)
        mqttClient.subscribe(MQTT_TOPIC_ALERT);
        Serial.printf("   📡 Subscribed to: %s\n", MQTT_TOPIC_ALERT);

    } else {
        Serial.printf(" ❌ (rc=%d)\n", mqttClient.state());
    }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
    // Convert payload to string
    char message[length + 1];
    memcpy(message, payload, length);
    message[length] = '\0';

    Serial.printf("📩 [%s] %s\n", topic, message);

    // Handle commands
    String topicStr = String(topic);
    if (topicStr.endsWith("/command")) {
        JsonDocument doc;
        DeserializationError err = deserializeJson(doc, message);
        if (!err) {
            const char* cmd = doc["command"];
            if (cmd) {
                Serial.printf("   🎮 Command received: %s\n", cmd);
                // Future: handle commands like "led_on", "restart", etc.
            }
        }
    } else if (topicStr.endsWith("/alert")) {
        Serial.println("   🚨 ALERT RECEIVED FROM BRIDGE!");
    }
}

// ================================================================
//  TELEMETRY
// ================================================================
void publishTelemetry() {
    float bodyTemp    = simulateBodyTemp();
    float ambientTemp = simulateAmbientTemp();
    float humidity    = simulateHumidity();
    float accelX, accelY, accelZ, movementIntensity;
    simulateAccelerometer(accelX, accelY, accelZ, movementIntensity);

    float battery = simulateBattery();

    // Build JSON payload
    JsonDocument doc;
    doc["device_id"]          = DEVICE_ID;
    doc["animal_name"]        = ANIMAL_NAME;
    doc["body_temp"]          = round(bodyTemp * 10.0f) / 10.0f;
    doc["ambient_temp"]       = round(ambientTemp * 10.0f) / 10.0f;
    doc["humidity"]           = round(humidity * 10.0f) / 10.0f;
    doc["accel_x"]            = round(accelX * 100.0f) / 100.0f;
    doc["accel_y"]            = round(accelY * 100.0f) / 100.0f;
    doc["accel_z"]            = round(accelZ * 100.0f) / 100.0f;
    doc["movement_intensity"] = round(movementIntensity * 100.0f) / 100.0f;
    doc["battery_v"]          = round(battery * 100.0f) / 100.0f;
    doc["uptime_ms"]          = millis();
    doc["rssi"]               = WiFi.RSSI();
    doc["msg_count"]          = ++messageCount;

    char jsonBuffer[512];
    size_t len = serializeJson(doc, jsonBuffer);

    if (mqttClient.publish(MQTT_TOPIC_TELEMETRY, jsonBuffer, len)) {
        Serial.printf("📤 [#%lu] Body=%.1f°C Ambient=%.1f°C Hum=%.0f%% Move=%.2f Batt=%.2fV\n",
            messageCount, bodyTemp, ambientTemp, humidity, movementIntensity, battery);
    } else {
        Serial.println("❌ Failed to publish!");
    }
}

// ================================================================
//  GPS PUBLISHING
// ================================================================
void publishGps() {
    float lat, lng, speed;
    simulateGps(lat, lng, speed);

    JsonDocument doc;
    doc["device_id"]    = DEVICE_ID;
    doc["animal_name"]  = ANIMAL_NAME;
    doc["latitude"]     = round(lat * 1000000.0) / 1000000.0;   // 6 decimal places
    doc["longitude"]    = round(lng * 1000000.0) / 1000000.0;
    doc["speed"]        = round(speed * 10.0f) / 10.0f;         // km/h
    doc["battery_v"]    = round(simulateBattery() * 100.0f) / 100.0f;
    doc["hdop"]         = randomFloat(0.8f, 3.5f);              // GPS accuracy
    doc["satellites"]   = (int)randomFloat(6.0f, 14.0f);

    char jsonBuffer[256];
    size_t len = serializeJson(doc, jsonBuffer);

    if (mqttClient.publish(MQTT_TOPIC_GPS, jsonBuffer, len)) {
        Serial.printf("📍 GPS: lat=%.6f lng=%.6f speed=%.1f km/h\n", lat, lng, speed);
    } else {
        Serial.println("❌ Failed to publish GPS!");
    }
}

// ================================================================
//  SENSOR SIMULATION
//  Replace these functions with real sensor reads when hardware
//  is available (e.g., DS18B20, BME280, MPU6050)
// ================================================================

float simulateBodyTemp() {
    // Normal: 38.0-39.5°C, Stressed: 39.5-41.5°C
    float target = simStressMode
        ? randomFloat(39.5f, SIM_BODY_TEMP_MAX)
        : randomFloat(SIM_BODY_TEMP_MIN, 39.5f);
    simBodyTemp = smoothStep(simBodyTemp, target, 0.15f);
    return simBodyTemp;
}

float simulateAmbientTemp() {
    // Normal: 25-35°C, Stressed: 38-48°C (Sonora heat wave)
    float target = simStressMode
        ? randomFloat(38.0f, SIM_AMBIENT_TEMP_MAX)
        : randomFloat(SIM_AMBIENT_TEMP_MIN, 35.0f);
    simAmbientTemp = smoothStep(simAmbientTemp, target, 0.5f);
    return simAmbientTemp;
}

float simulateHumidity() {
    // Sonora: typically 15-50%, can spike after rain
    float target = simStressMode
        ? randomFloat(40.0f, SIM_HUMIDITY_MAX)   // Hot + humid = worst case
        : randomFloat(SIM_HUMIDITY_MIN, 45.0f);
    simHumidity = smoothStep(simHumidity, target, 1.0f);
    return simHumidity;
}

void simulateAccelerometer(float &x, float &y, float &z, float &intensity) {
    if (simStressMode) {
        // Stressed: rapid head movement (jadeo/panting), less overall movement
        x = randomFloat(-3.0f, 3.0f);   // Panting head shake
        y = randomFloat(-1.0f, 1.0f);
        z = 9.8f + randomFloat(-2.0f, 2.0f);
    } else {
        // Normal: gentle walking/grazing
        x = randomFloat(-1.0f, 1.0f);
        y = randomFloat(-0.5f, 0.5f);
        z = 9.8f + randomFloat(-0.3f, 0.3f);
    }

    simAccelX = smoothStep(simAccelX, x, 0.5f);
    simAccelY = smoothStep(simAccelY, y, 0.5f);
    simAccelZ = smoothStep(simAccelZ, z, 0.3f);

    x = simAccelX;
    y = simAccelY;
    z = simAccelZ;

    // Movement intensity: deviation from rest (0,0,9.8)
    intensity = sqrt(x * x + y * y + (z - 9.8f) * (z - 9.8f));
}

// ================================================================
//  GPS SIMULATION
// ================================================================
void simulateGps(float &lat, float &lng, float &speed) {
    // Random walk around the center point (simulates grazing)
    float targetLat = SIM_GPS_CENTER_LAT + randomFloat(-SIM_GPS_WANDER_LAT, SIM_GPS_WANDER_LAT);
    float targetLng = SIM_GPS_CENTER_LNG + randomFloat(-SIM_GPS_WANDER_LNG, SIM_GPS_WANDER_LNG);

    // Smooth movement — cattle graze slowly
    float moveRate = simStressMode ? 0.0001f : 0.00005f;  // Move faster when stressed
    simLatitude  = smoothStep(simLatitude, targetLat, moveRate);
    simLongitude = smoothStep(simLongitude, targetLng, moveRate);

    // Speed based on position change (~111km per degree at equator)
    float dlat = abs(simLatitude - targetLat) * 111000.0f;   // meters
    float dlng = abs(simLongitude - targetLng) * 85000.0f;   // meters at ~30°N
    float distM = sqrt(dlat * dlat + dlng * dlng);
    simSpeed = smoothStep(simSpeed, (distM / 30.0f) * 3.6f, 0.5f);  // m/30s → km/h

    lat = simLatitude;
    lng = simLongitude;
    speed = simSpeed;
}

// ================================================================
//  BATTERY SIMULATION
// ================================================================
float simulateBattery() {
    // Slowly drain battery — resets every ~4 hours of operation
    float hoursRunning = millis() / 3600000.0f;
    float cycleHours = fmod(hoursRunning, 4.0f);  // 4-hour cycle
    float drain = (cycleHours / 4.0f) * (SIM_BATTERY_MAX_V - SIM_BATTERY_MIN_V);
    simBattery = smoothStep(simBattery, SIM_BATTERY_MAX_V - drain, 0.01f);
    return simBattery;
}

// ================================================================
//  WATER LEVEL SIMULATION
//  Replace with HC-SR04 ultrasonic or pressure sensor reading
// ================================================================
float simulateWaterLevel() {
    // Simulate daily consumption cycle: drops during day, refills
    float hoursRunning = millis() / 3600000.0f;
    float dayPhase = fmod(hoursRunning, 8.0f) / 8.0f;  // 8-hour cycle

    float target;
    if (dayPhase < 0.6f) {
        // Consumption phase: level drops
        target = SIM_WATER_MAX_LEVEL_CM - (dayPhase / 0.6f) * 
                 (SIM_WATER_MAX_LEVEL_CM - SIM_WATER_MIN_LEVEL_CM) * 0.7f;
    } else {
        // Refill phase: level rises
        float refillPhase = (dayPhase - 0.6f) / 0.4f;
        target = SIM_WATER_MIN_LEVEL_CM * 1.3f + 
                 refillPhase * (SIM_WATER_MAX_LEVEL_CM - SIM_WATER_MIN_LEVEL_CM * 1.3f);
    }
    target += randomFloat(-5.0f, 5.0f);  // Noise
    simWaterLevel = smoothStep(simWaterLevel, target, 2.0f);
    return simWaterLevel;
}

void publishWaterLevel() {
    float level = simulateWaterLevel();
    float fillPercent = (level / SIM_WATER_TANK_DEPTH_CM) * 100.0f;
    fillPercent = constrain(fillPercent, 0.0f, 100.0f);

    JsonDocument doc;
    doc["device_id"]       = "water_tank_01";
    doc["level_cm"]        = round(level * 10.0f) / 10.0f;
    doc["fill_percentage"] = round(fillPercent * 10.0f) / 10.0f;
    doc["tank_depth_cm"]   = SIM_WATER_TANK_DEPTH_CM;
    doc["temperature"]     = round(simulateAmbientTemp() * 10.0f) / 10.0f;
    doc["battery_v"]       = round(simulateBattery() * 100.0f) / 100.0f;

    char jsonBuffer[256];
    size_t len = serializeJson(doc, jsonBuffer);

    if (mqttClient.publish(MQTT_TOPIC_WATER, jsonBuffer, len)) {
        Serial.printf("💧 Water: %.1fcm (%.1f%%) temp=%.1f°C\n", level, fillPercent, doc["temperature"].as<float>());
    } else {
        Serial.println("❌ Failed to publish water level!");
    }
}

// ================================================================
//  UTILITY
// ================================================================

float randomFloat(float min, float max) {
    return min + ((float)random(0, 10000) / 10000.0f) * (max - min);
}

float smoothStep(float current, float target, float maxDelta) {
    float diff = target - current;
    if (abs(diff) <= maxDelta) return target;
    return current + (diff > 0 ? maxDelta : -maxDelta);
}
