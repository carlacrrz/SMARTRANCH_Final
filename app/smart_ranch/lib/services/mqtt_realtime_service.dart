import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_config.dart';

/// Real-time MQTT service for GPS positions and alert notifications.
/// Connects to the MQTT broker and streams updates to listeners.
class MqttRealtimeService {
  static MqttServerClient? _client;
  static bool _connected = false;

  // Stream controllers for different data types
  static final _gpsController = StreamController<Map<String, dynamic>>.broadcast();
  static final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  static final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();

  /// Streams for consuming real-time data
  static Stream<Map<String, dynamic>> get gpsStream => _gpsController.stream;
  static Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  static Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;

  static bool get isConnected => _connected;

  /// Connect to the MQTT broker
  static Future<bool> connect() async {
    if (_connected) return true;

    try {
      _client = MqttServerClient(AppConfig.mqttHost, 'smart_ranch_flutter_${DateTime.now().millisecondsSinceEpoch}');
      _client!.port = AppConfig.mqttPortTcp;
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;
      _client!.onAutoReconnect = _onReconnect;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.logging(on: false);

      final connMsg = MqttConnectMessage()
          .withClientIdentifier(_client!.clientIdentifier)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      _client!.connectionMessage = connMsg;

      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _connected = true;
        _subscribe();
        _listenToMessages();
        return true;
      }
      return false;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  /// Subscribe to relevant topics
  static void _subscribe() {
    _client?.subscribe('ranch/+/gps', MqttQos.atLeastOnce);
    _client?.subscribe('ranch/+/alert', MqttQos.atLeastOnce);
    _client?.subscribe(AppConfig.telemetryTopicPattern, MqttQos.atMostOnce);
  }

  /// Listen to incoming messages
  static void _listenToMessages() {
    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null) return;

      for (final msg in messages) {
        final topic = msg.topic;
        final payload = msg.payload as MqttPublishMessage;
        final text = MqttPublishPayload.bytesToStringAsString(payload.payload.message);

        try {
          final data = json.decode(text) as Map<String, dynamic>;
          data['_topic'] = topic;
          data['_received_at'] = DateTime.now().toIso8601String();

          if (topic.endsWith('/gps')) {
            // Extract device ID from topic: ranch/{deviceId}/gps
            final parts = topic.split('/');
            if (parts.length >= 2) {
              data['device_id'] = parts[1];
            }
            _gpsController.add(data);
          } else if (topic.endsWith('/alert')) {
            _alertController.add(data);
          } else if (topic.endsWith('/telemetry')) {
            _telemetryController.add(data);
          }
        } catch (_) {
          // Skip malformed messages
        }
      }
    });
  }

  static void _onConnected() {
    _connected = true;
  }

  static void _onDisconnected() {
    _connected = false;
  }

  static void _onReconnect() {
    // Auto-reconnect will re-subscribe automatically
  }

  /// Disconnect from the broker
  static void disconnect() {
    _client?.disconnect();
    _connected = false;
  }

  /// Dispose all stream controllers
  static void dispose() {
    disconnect();
    _gpsController.close();
    _alertController.close();
    _telemetryController.close();
  }
}
