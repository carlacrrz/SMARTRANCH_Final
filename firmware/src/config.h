/*
 * Smart Ranch — Configuration
 * Change these values to match your network and MQTT broker.
 * 
 * Each ESP32 = one head of cattle. Set a unique DEVICE_ID per device.
 */

#ifndef CONFIG_H
#define CONFIG_H

// ============================================================
// WiFi Configuration
// ============================================================
#define WIFI_SSID       "YOUR_WIFI_SSID"
#define WIFI_PASS       "YOUR_WIFI_PASSWORD"

// ============================================================
// MQTT Broker Configuration
// ============================================================
#define MQTT_SERVER     "192.168.1.100"   // IP of your MQTT broker (Mosquitto Docker)
#define MQTT_PORT       1883
#define MQTT_USER       ""                // Leave empty for anonymous (MVP)
#define MQTT_PASS       ""

// ============================================================
// Device Identity
// ============================================================
#define DEVICE_ID       "vaca_001"        // Unique ID for this animal
#define ANIMAL_NAME     "Lupita"          // Friendly name (optional)

// ============================================================
// Telemetry Configuration
// ============================================================
#define PUBLISH_INTERVAL_MS   5000        // Publish every 5 seconds
#define GPS_PUBLISH_INTERVAL_MS 30000     // GPS every 30 seconds (saves battery)
#define MQTT_TOPIC_TELEMETRY  "ranch/" DEVICE_ID "/telemetry"
#define MQTT_TOPIC_GPS        "ranch/" DEVICE_ID "/gps"
#define MQTT_TOPIC_ALERT      "ranch/" DEVICE_ID "/alert"
#define MQTT_TOPIC_COMMAND    "ranch/" DEVICE_ID "/command"
#define MQTT_TOPIC_WATER      "ranch/water/level"

// ============================================================
// Sensor Simulation Ranges (for MVP without real sensors)
// ============================================================
#define SIM_BODY_TEMP_MIN     37.5f       // Normal bovine body temp
#define SIM_BODY_TEMP_MAX     41.5f       // Fever threshold ~40°C
#define SIM_AMBIENT_TEMP_MIN  25.0f       // Sonora morning
#define SIM_AMBIENT_TEMP_MAX  48.0f       // Sonora peak summer
#define SIM_HUMIDITY_MIN      15.0f       // Arid climate
#define SIM_HUMIDITY_MAX      75.0f       // After rain

// ============================================================
// GPS Simulation (Rancho Cananea area)
// ============================================================
#define SIM_GPS_CENTER_LAT    30.984      // Center latitude
#define SIM_GPS_CENTER_LNG   -110.305     // Center longitude
#define SIM_GPS_WANDER_LAT    0.008       // Max latitude wander (~890m)
#define SIM_GPS_WANDER_LNG    0.010       // Max longitude wander (~870m)

// ============================================================
// Battery Simulation
// ============================================================
#define SIM_BATTERY_MIN_V     3.3f        // Li-Po cutoff voltage
#define SIM_BATTERY_MAX_V     4.2f        // Li-Po full charge

// ============================================================
// Water Level Sensor (HC-SR04 ultrasonic or pressure sensor)
// ============================================================
#define WATER_PUBLISH_INTERVAL_MS  60000   // Publish every 60 seconds
#define WATER_SENSOR_PIN           34      // ADC pin for water level
#define SIM_WATER_TANK_DEPTH_CM    200.0f  // Tank depth in cm
#define SIM_WATER_MIN_LEVEL_CM     20.0f   // Min water level
#define SIM_WATER_MAX_LEVEL_CM     190.0f  // Max water level

#endif // CONFIG_H
