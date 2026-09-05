/*
 * Smart Ranch — Trough Water Level Monitor
 * ESP32 with HC-SR04 ultrasonic sensor for measuring water levels.
 * 
 * Publishes to MQTT topic: ranch/trough/{TROUGH_ID}/telemetry
 * 
 * Wiring:
 *   HC-SR04 TRIG -> GPIO 5
 *   HC-SR04 ECHO -> GPIO 18
 *   HC-SR04 VCC  -> 5V
 *   HC-SR04 GND  -> GND
 */

#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "config.h"

// ============================================================
// Trough-specific Configuration
// ============================================================
#ifndef TROUGH_ID
  #define TROUGH_ID         "bebedero_01"
#endif

#ifndef TROUGH_NAME
  #define TROUGH_NAME       "Bebedero Principal"
#endif

// Tank depth in centimeters (distance from sensor to bottom)
#ifndef TANK_DEPTH_CM
  #define TANK_DEPTH_CM     100.0f
#endif

// Sensor offset: distance from sensor to water at 100% full
#ifndef SENSOR_OFFSET_CM
  #define SENSOR_OFFSET_CM  5.0f
#endif

// Reading interval (longer than cattle monitor — water changes slowly)
#ifndef TROUGH_PUBLISH_INTERVAL_MS
  #define TROUGH_PUBLISH_INTERVAL_MS  60000  // 60 seconds
#endif

// HC-SR04 Pins
#define TRIG_PIN  5
#define ECHO_PIN  18

// MQTT Topic
#define MQTT_TOPIC_TROUGH  "ranch/trough/" TROUGH_ID "/telemetry"

// ============================================================
// Globals
// ============================================================
WiFiClient espClient;
PubSubClient mqttClient(espClient);

unsigned long lastPublish = 0;

// ============================================================
// WiFi
// ============================================================
void setupWiFi() {
    Serial.printf("📶 Connecting to %s", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 30) {
        delay(500);
        Serial.print(".");
        retries++;
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\n✅ WiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("\n❌ WiFi connection failed. Restarting...");
        ESP.restart();
    }
}

// ============================================================
// MQTT
// ============================================================
void reconnectMQTT() {
    while (!mqttClient.connected()) {
        Serial.printf("🔄 Connecting to MQTT %s:%d...\n", MQTT_SERVER, MQTT_PORT);
        String clientId = "trough_" + String(TROUGH_ID);
        if (mqttClient.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)) {
            Serial.println("✅ MQTT connected!");
        } else {
            Serial.printf("❌ MQTT failed, rc=%d. Retrying in 5s...\n", mqttClient.state());
            delay(5000);
        }
    }
}

// ============================================================
// HC-SR04 Ultrasonic Sensor
// ============================================================
float readDistanceCm() {
    // Send trigger pulse
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);

    // Read echo pulse duration
    long duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout
    
    if (duration == 0) {
        return -1.0f; // No echo received
    }

    // Speed of sound = 343 m/s = 0.0343 cm/µs
    // Distance = Duration * 0.0343 / 2 (round trip)
    float distance = duration * 0.0343f / 2.0f;
    return distance;
}

float calculateLevelPercent(float distanceCm) {
    if (distanceCm < 0) return 0.0f; // Sensor error
    
    // Water level = tank depth - (measured distance - sensor offset)
    float waterHeight = TANK_DEPTH_CM - (distanceCm - SENSOR_OFFSET_CM);
    
    // Clamp to 0-100%
    float percent = (waterHeight / TANK_DEPTH_CM) * 100.0f;
    if (percent < 0.0f) percent = 0.0f;
    if (percent > 100.0f) percent = 100.0f;
    
    return percent;
}

// ============================================================
// Publish Telemetry
// ============================================================
void publishTroughData() {
    // Take average of 3 readings for accuracy
    float totalDist = 0;
    int validReadings = 0;
    
    for (int i = 0; i < 3; i++) {
        float d = readDistanceCm();
        if (d > 0) {
            totalDist += d;
            validReadings++;
        }
        delay(100);
    }

    float distanceCm = (validReadings > 0) ? (totalDist / validReadings) : -1.0f;
    float levelPercent = calculateLevelPercent(distanceCm);

    // Build JSON
    JsonDocument doc;
    doc["trough_id"]    = TROUGH_ID;
    doc["trough_name"]  = TROUGH_NAME;
    doc["distance_cm"]  = round(distanceCm * 10.0f) / 10.0f;  // 1 decimal
    doc["level_percent"] = round(levelPercent * 10.0f) / 10.0f;
    doc["tank_depth_cm"] = TANK_DEPTH_CM;

    char buffer[256];
    serializeJson(doc, buffer, sizeof(buffer));

    // Publish
    if (mqttClient.publish(MQTT_TOPIC_TROUGH, buffer)) {
        Serial.printf("💧 Published: %s\n", buffer);
    } else {
        Serial.println("❌ Publish failed!");
    }
}

// ============================================================
// Setup & Loop
// ============================================================
void setup() {
    Serial.begin(115200);
    Serial.println("\n💧 Smart Ranch — Trough Water Monitor");
    Serial.printf("   Trough: %s (%s)\n", TROUGH_ID, TROUGH_NAME);
    Serial.printf("   Tank depth: %.0f cm\n", TANK_DEPTH_CM);

    // HC-SR04 pins
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);

    // Network
    setupWiFi();
    mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
}

void loop() {
    // Ensure connections
    if (WiFi.status() != WL_CONNECTED) {
        setupWiFi();
    }
    if (!mqttClient.connected()) {
        reconnectMQTT();
    }
    mqttClient.loop();

    // Publish at configured interval
    unsigned long now = millis();
    if (now - lastPublish >= TROUGH_PUBLISH_INTERVAL_MS) {
        lastPublish = now;
        publishTroughData();
    }
}
