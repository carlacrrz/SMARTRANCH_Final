/// Configuration constants for the Smart Ranch app.
class AppConfig {
  // MQTT Broker
  static String mqttHost = const String.fromEnvironment('MQTT_HOST', defaultValue: '127.0.0.1');
  static int mqttPortTcp = 1883; // For mobile (TCP)
  static int mqttPortWs = 9001; // For web (WebSocket)

  // REST API
  static String apiBaseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');

  // MQTT Topics
  static const String telemetryTopicPattern = 'ranch/+/telemetry';
  static const String alertTopicPattern = 'ranch/+/alert';
  static String telemetryTopic(String deviceId) => 'ranch/$deviceId/telemetry';
  static String alertTopic(String deviceId) => 'ranch/$deviceId/alert';
  static String commandTopic(String deviceId) => 'ranch/$deviceId/command';

  // THI Thresholds (configurable)
  static double thiNormal = 72.0;
  static double thiAlert = 72.0;
  static double thiDanger = 79.0;
  static double thiEmergency = 89.0;

  // Update interval
  static const Duration chartUpdateInterval = Duration(seconds: 10);
}
