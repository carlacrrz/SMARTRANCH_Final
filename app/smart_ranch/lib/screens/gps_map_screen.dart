import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/ranch_api_service.dart';
import '../services/mqtt_realtime_service.dart';

/// GPS Map screen — shows animal positions and geofence zones.
/// Uses a custom canvas-based map since we don't need Google Maps dependency.
class GpsMapScreen extends StatefulWidget {
  const GpsMapScreen({super.key});

  @override
  State<GpsMapScreen> createState() => _GpsMapScreenState();
}

class _GpsMapScreenState extends State<GpsMapScreen> {
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _violations = [];
  StreamSubscription<Map<String, dynamic>>? _gpsSubscription;
  bool _mqttConnected = false;

  static const _demoPositions = [
    {'device_id': 'vaca_001', 'animal_name': 'Lupita', 'latitude': 30.984, 'longitude': -110.305, 'current_zone': 'Potrero Norte', 'speed': 0.2, 'battery_v': 3.9},
    {'device_id': 'vaca_002', 'animal_name': 'Estrella', 'latitude': 30.986, 'longitude': -110.303, 'current_zone': 'Potrero Norte', 'speed': 0.0, 'battery_v': 4.1},
    {'device_id': 'vaca_003', 'animal_name': 'Canela', 'latitude': 30.977, 'longitude': -110.302, 'current_zone': 'Corral Principal', 'speed': 0.5, 'battery_v': 3.6},
    {'device_id': 'vaca_004', 'animal_name': 'Luna', 'latitude': 30.983, 'longitude': -110.304, 'current_zone': 'Bebedero Arroyo', 'speed': 0.1, 'battery_v': 4.0},
    {'device_id': 'vaca_005', 'animal_name': 'Valentina', 'latitude': 30.992, 'longitude': -110.315, 'current_zone': null, 'speed': 1.2, 'battery_v': 3.4},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectMqtt();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }

  void _connectMqtt() async {
    final ok = await MqttRealtimeService.connect();
    if (ok) {
      setState(() => _mqttConnected = true);
      _gpsSubscription = MqttRealtimeService.gpsStream.listen((data) {
        final deviceId = data['device_id'];
        setState(() {
          final idx = _positions.indexWhere((p) => p['device_id'] == deviceId);
          final updated = {
            'device_id': deviceId,
            'animal_name': data['animal_name'] ?? deviceId,
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'speed': data['speed'] ?? 0,
            'battery_v': data['battery_v'] ?? 0,
            'current_zone': data['current_zone'],
          };
          if (idx >= 0) {
            _positions[idx] = updated;
          } else {
            _positions.add(updated);
          }
        });
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final positions = await RanchApiService.getCurrentPositions();
      final violations = await RanchApiService.getGeofenceViolations();
      setState(() {
        _positions = positions;
        _violations = violations;
      });
    } catch (e) {
      setState(() {
        _positions = List<Map<String, dynamic>>.from(_demoPositions);
        _violations = [_demoPositions.last];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatsBar(),
        Expanded(child: _buildMapArea()),
        _buildPositionList(),
      ],
    );
  }

  Widget _buildStatsBar() {
    final totalTracked = _positions.length;
    final inZone = _positions.where((p) => p['current_zone'] != null).length;
    final outOfZone = _violations.length;
    final moving = _positions.where((p) => (p['speed'] as num?) != null && (p['speed'] as num) > 0.3).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(icon: Icons.gps_fixed_rounded, label: 'Rastreadas', value: '$totalTracked', color: AppTheme.primary),
          _StatItem(icon: Icons.check_circle_rounded, label: 'En zona', value: '$inZone', color: AppTheme.thiNormal),
          _StatItem(icon: Icons.warning_amber_rounded, label: 'Fuera', value: '$outOfZone',
              color: outOfZone > 0 ? AppTheme.thiDanger : AppTheme.textSecondary),
          _StatItem(icon: Icons.directions_run_rounded, label: 'En movimiento', value: '$moving', color: AppTheme.secondary),
          _StatItem(icon: _mqttConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded, label: 'MQTT',
              value: _mqttConnected ? 'LIVE' : 'OFF',
              color: _mqttConnected ? AppTheme.thiNormal : AppTheme.thiDanger),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _RanchMapPainter(positions: _positions, violations: _violations),
            ),
            Positioned(
              right: 12, top: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendItem(color: AppTheme.thiNormal, label: 'En zona'),
                    SizedBox(height: 3),
                    _LegendItem(color: AppTheme.thiDanger, label: 'Fuera de zona'),
                    SizedBox(height: 3),
                    _LegendItem(color: Color(0xFF42A5F5), label: 'Agua'),
                    SizedBox(height: 3),
                    _LegendItem(color: Color(0xFF66BB6A), label: 'Potrero'),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12, top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.map_rounded, size: 14, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('Rancho Cananea',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12, bottom: 12,
              child: FloatingActionButton.small(
                onPressed: _loadData,
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionList() {
    if (_positions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 110,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _positions.length,
        itemBuilder: (context, index) {
          final pos = _positions[index];
          final isOutOfZone = pos['current_zone'] == null;

          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOutOfZone ? AppTheme.thiDanger.withAlpha(80) : AppTheme.divider,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isOutOfZone ? Icons.warning_amber_rounded : Icons.location_on_rounded,
                        size: 14, color: isOutOfZone ? AppTheme.thiDanger : AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pos['animal_name'] ?? pos['device_id'] ?? '?',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  pos['current_zone'] ?? 'FUERA DE ZONA',
                  style: TextStyle(
                    color: isOutOfZone ? AppTheme.thiDanger : AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: isOutOfZone ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 10, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text('${((pos['speed'] as num?) ?? 0).toStringAsFixed(1)} km/h',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    const Spacer(),
                    Icon(Icons.battery_full_rounded, size: 10,
                        color: ((pos['battery_v'] as num?) ?? 4) < 3.5
                            ? AppTheme.thiDanger : AppTheme.textSecondary),
                    const SizedBox(width: 2),
                    Text('${((pos['battery_v'] as num?) ?? 0).toStringAsFixed(1)}V',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
class _RanchMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> positions;
  final List<Map<String, dynamic>> violations;

  _RanchMapPainter({required this.positions, required this.violations});

  static const _minLat = 30.974;
  static const _maxLat = 30.994;
  static const _minLng = -110.318;
  static const _maxLng = -110.298;

  Offset _toCanvas(double lat, double lng, Size size) {
    final x = (lng - _minLng) / (_maxLng - _minLng) * size.width;
    final y = (1 - (lat - _minLat) / (_maxLat - _minLat)) * size.height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF1A2636));

    final gridPaint = Paint()..color = const Color(0xFF243355)..strokeWidth = 0.5;
    for (int i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      final y = size.height * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawZone(canvas, size, 'Corral Principal', 30.976, 30.978, -110.303, -110.301,
        const Color(0xFFFF5722).withAlpha(25), const Color(0xFFFF5722));
    _drawZone(canvas, size, 'Potrero Norte', 30.980, 30.990, -110.310, -110.300,
        const Color(0xFF4CAF50).withAlpha(20), const Color(0xFF4CAF50));
    _drawZone(canvas, size, 'Bebedero Arroyo', 30.982, 30.984, -110.305, -110.303,
        const Color(0xFF2196F3).withAlpha(25), const Color(0xFF2196F3));

    final violationIds = violations.map((v) => v['device_id']).toSet();
    for (final pos in positions) {
      final lat = (pos['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (pos['longitude'] as num?)?.toDouble() ?? 0;
      if (lat == 0 || lng == 0) continue;

      final offset = _toCanvas(lat, lng, size);
      final isViolation = violationIds.contains(pos['device_id']);

      canvas.drawCircle(offset, 14,
          Paint()..color = (isViolation ? AppTheme.thiDanger : AppTheme.primary).withAlpha(40));
      canvas.drawCircle(offset, 7,
          Paint()..color = isViolation ? AppTheme.thiDanger : AppTheme.primary);
      canvas.drawCircle(offset, 3, Paint()..color = Colors.white);

      final textPainter = TextPainter(
        text: TextSpan(
          text: pos['animal_name'] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, offset + Offset(-textPainter.width / 2, 12));
    }
  }

  void _drawZone(Canvas canvas, Size size, String name,
      double minLat, double maxLat, double minLng, double maxLng,
      Color fill, Color border) {
    final topLeft = _toCanvas(maxLat, minLng, size);
    final bottomRight = _toCanvas(minLat, maxLng, size);
    final rect = Rect.fromPoints(topLeft, bottomRight);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = fill);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final textPainter = TextPainter(
      text: TextSpan(text: name,
          style: TextStyle(color: border, fontSize: 10, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, topLeft + const Offset(6, 4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}
