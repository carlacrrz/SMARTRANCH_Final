import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sensor_reading.dart';
import '../models/reproduction_alert.dart';
import '../models/health_alert.dart';
import '../models/trough_reading.dart';

/// Demo service that simulates multiple ESP32 devices for testing
/// without requiring MQTT broker infrastructure.
/// Now includes estrus (celo) and health simulation.
class DemoService extends ChangeNotifier {
  final List<_SimulatedAnimal> _animals = [
    _SimulatedAnimal('vaca_001', 'Lupita', false),
    _SimulatedAnimal('vaca_002', 'Estrella', false),
    _SimulatedAnimal('vaca_003', 'Canela', true), // starts stressed
    _SimulatedAnimal('vaca_004', 'Luna', false),
    _SimulatedAnimal('vaca_005', 'Valentina', false),
  ];

  final Map<String, SensorReading> _latestReadings = {};
  final Map<String, List<SensorReading>> _readingHistory = {};
  static const int _maxHistory = 120;

  // --- Estrus Simulation ---
  final Map<String, ReproductionAlert> _activeEstrusAlerts = {};
  final Map<String, int> _estrusTickCounter = {};

  // --- Health Simulation ---
  final Map<String, HealthAlert> _activeHealthAlerts = {};
  final Map<String, String> _healthStates = {}; // device_id -> status

  // --- Trough Simulation ---
  final Map<String, TroughReading> _troughReadings = {};
  static const _troughNames = {
    'bebedero_01': 'Potrero Norte',
    'bebedero_02': 'Corral Principal',
    'bebedero_03': 'Potrero Sur',
  };

  Timer? _timer;
  bool _isRunning = false;
  final _random = Random();
  int _tickCount = 0;

  Map<String, SensorReading> get latestReadings =>
      Map.unmodifiable(_latestReadings);
  Map<String, List<SensorReading>> get readingHistory =>
      Map.unmodifiable(_readingHistory);
  bool get isRunning => _isRunning;

  /// Active estrus alerts by device_id.
  Map<String, ReproductionAlert> get activeEstrusAlerts =>
      Map.unmodifiable(_activeEstrusAlerts);

  /// Active health alerts by device_id.
  Map<String, HealthAlert> get activeHealthAlerts =>
      Map.unmodifiable(_activeHealthAlerts);

  /// Current trough readings.
  Map<String, TroughReading> get troughReadings =>
      Map.unmodifiable(_troughReadings);

  /// Start generating simulated data.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _generateReadings(); // initial
    _generateTroughReadings(); // initial trough
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _generateReadings();
      // Troughs update less frequently
      if (_tickCount % 12 == 0) _generateTroughReadings();
    });
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void _generateReadings() {
    _tickCount++;

    for (final animal in _animals) {
      // Toggle stress randomly
      if (_random.nextDouble() < 0.03) {
        animal.stressed = !animal.stressed;
      }

      // --- Estrus Simulation ---
      // Every ~24 ticks (~2 min), one random cow enters estrus for 12 ticks (~1 min)
      if (_tickCount % 24 == 0 && _random.nextDouble() < 0.4) {
        final candidate =
            _animals[_random.nextInt(_animals.length)];
        if (!candidate.inEstrus) {
          candidate.inEstrus = true;
          _estrusTickCounter[candidate.id] = 0;
        }
      }

      // Track estrus duration
      if (animal.inEstrus) {
        _estrusTickCounter[animal.id] =
            (_estrusTickCounter[animal.id] ?? 0) + 1;
        if ((_estrusTickCounter[animal.id] ?? 0) > 12) {
          animal.inEstrus = false;
          _estrusTickCounter.remove(animal.id);
          _activeEstrusAlerts.remove(animal.id);
        }
      }

      // --- Health Simulation ---
      // Every ~36 ticks (~3 min), one random cow gets sick for 10 ticks
      if (_tickCount % 36 == 0 && _random.nextDouble() < 0.3) {
        final candidate =
            _animals[_random.nextInt(_animals.length)];
        if (_healthStates[candidate.id] == null ||
            _healthStates[candidate.id] == 'healthy') {
          final types = ['fever', 'lethargy', 'sick_suspected'];
          candidate.healthState = types[_random.nextInt(types.length)];
          candidate.healthTicks = 0;
          _healthStates[candidate.id] = candidate.healthState;
        }
      }

      // Track health duration
      if (animal.healthState != 'healthy') {
        animal.healthTicks++;
        if (animal.healthTicks > 10) {
          animal.healthState = 'healthy';
          animal.healthTicks = 0;
          _healthStates[animal.id] = 'healthy';
          _activeHealthAlerts.remove(animal.id);
        }
      }

      // Generate sensor values
      final isEstrus = animal.inEstrus;
      final isSick =
          animal.healthState == 'fever' ||
          animal.healthState == 'sick_suspected';
      final isLethargic =
          animal.healthState == 'lethargy' ||
          animal.healthState == 'sick_suspected';

      final bodyTemp = isSick
          ? 40.5 + _random.nextDouble() * 1.5
          : animal.stressed
              ? 39.5 + _random.nextDouble() * 2.0
              : 37.5 + _random.nextDouble() * 2.0;
      final ambientTemp = animal.stressed
          ? 38.0 + _random.nextDouble() * 10.0
          : 25.0 + _random.nextDouble() * 10.0;
      final humidity = animal.stressed
          ? 40.0 + _random.nextDouble() * 35.0
          : 15.0 + _random.nextDouble() * 30.0;

      final thi = SensorReading.calculateThi(ambientTemp, humidity);

      // Movement: high for estrus, low for lethargy, normal otherwise
      final movementIntensity = isEstrus
          ? 3.0 + _random.nextDouble() * 3.0 // High activity = celo
          : isLethargic
              ? 0.05 + _random.nextDouble() * 0.15 // Very low = sick
              : animal.stressed
                  ? 1.5 + _random.nextDouble() * 3.0
                  : 0.1 + _random.nextDouble() * 1.0;

      // Estrus score
      final estrusScore = isEstrus
          ? 0.8 + _random.nextDouble() * 0.2
          : _random.nextDouble() * 0.2;

      // Health status
      final healthStatus = animal.healthState;

      final batteryMap = {
        'vaca_001': (94.0, 4.15),
        'vaca_002': (88.0, 4.05),
        'vaca_003': (76.0, 3.92),
        'vaca_004': (91.0, 4.12),
        'vaca_005': (62.0, 3.78),
      };
      final batData = batteryMap[animal.id] ?? (85.0, 4.0);

      final reading = SensorReading(
        deviceId: animal.id,
        animalName: animal.name,
        bodyTemp: double.parse(bodyTemp.toStringAsFixed(1)),
        ambientTemp: double.parse(ambientTemp.toStringAsFixed(1)),
        humidity: double.parse(humidity.toStringAsFixed(1)),
        thi: thi,
        thiLevel: SensorReading.thiLevelFromValue(thi),
        accelX: (_random.nextDouble() - 0.5) *
            (isEstrus ? 6 : animal.stressed ? 4 : 2),
        accelY: (_random.nextDouble() - 0.5) *
            (isEstrus ? 4 : animal.stressed ? 2 : 1),
        accelZ:
            9.8 +
            (_random.nextDouble() - 0.5) *
                (isEstrus ? 4 : animal.stressed ? 3 : 0.5),
        movementIntensity:
            double.parse(movementIntensity.toStringAsFixed(2)),
        estrusScore: double.parse(estrusScore.toStringAsFixed(2)),
        healthStatus: healthStatus,
        batteryPercent: batData.$1,
        batteryVoltage: batData.$2,
      );

      _latestReadings[animal.id] = reading;
      _readingHistory.putIfAbsent(animal.id, () => []);
      _readingHistory[animal.id]!.add(reading);
      if (_readingHistory[animal.id]!.length > _maxHistory) {
        _readingHistory[animal.id]!.removeAt(0);
      }

      // Update active alert maps
      if (isEstrus && estrusScore > 0.7) {
        _activeEstrusAlerts[animal.id] = ReproductionAlert(
          deviceId: animal.id,
          animalName: animal.name,
          activityScore: estrusScore,
          movementIntensity: movementIntensity,
        );
      }
      if (healthStatus != 'healthy') {
        _activeHealthAlerts[animal.id] = HealthAlert(
          deviceId: animal.id,
          animalName: animal.name,
          type: healthStatus,
          bodyTemp: bodyTemp,
          movementIntensity: movementIntensity,
        );
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _generateTroughReadings() {
    for (final entry in _troughNames.entries) {
      final id = entry.key;
      final name = entry.value;

      // Simulate water levels that slowly decrease then get refilled
      final existing = _troughReadings[id];
      double level;
      if (existing == null) {
        level = 60 + _random.nextDouble() * 40; // Start 60-100%
      } else {
        // Decrease by 1-3%, occasionally refill
        level = existing.levelPercent - (1 + _random.nextDouble() * 2);
        if (level <= 5 || _random.nextDouble() < 0.08) {
          level = 70 + _random.nextDouble() * 30; // Refill to 70-100%
        }
      }
      level = level.clamp(0.0, 100.0);

      final distanceCm = 100 - level; // Simplified: level% maps to distance

      _troughReadings[id] = TroughReading(
        troughId: id,
        troughName: name,
        levelPercent: double.parse(level.toStringAsFixed(1)),
        distanceCm: double.parse(distanceCm.toStringAsFixed(1)),
        tankDepthCm: 100,
      );
    }
  }
}

class _SimulatedAnimal {
  final String id;
  final String name;
  bool stressed;
  bool inEstrus;
  String healthState;
  int healthTicks;

  _SimulatedAnimal(this.id, this.name, this.stressed)
      : inEstrus = false,
        healthState = 'healthy',
        healthTicks = 0;
}
