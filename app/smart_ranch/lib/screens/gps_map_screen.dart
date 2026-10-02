import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_theme.dart';
import '../services/ranch_api_service.dart';
import '../services/mqtt_realtime_service.dart';

/// GPS Map screen — real OpenStreetMap view with live animal positions and geofences.
class GpsMapScreen extends StatefulWidget {
  const GpsMapScreen({super.key});

  @override
  State<GpsMapScreen> createState() => _GpsMapScreenState();
}

class _GpsMapScreenState extends State<GpsMapScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _violations = [];
  StreamSubscription<Map<String, dynamic>>? _gpsSubscription;
  bool _mqttConnected = false;
  String? _selectedDeviceId;

  static const _defaultCenter = LatLng(30.984, -110.305);

  static const _demoPositions = [
    {'device_id': 'vaca_001', 'animal_name': 'Lupita', 'latitude': 30.984, 'longitude': -110.305, 'current_zone': 'Potrero Norte', 'speed': 0.2, 'battery_v': 3.9},
    {'device_id': 'vaca_002', 'animal_name': 'Estrella', 'latitude': 30.986, 'longitude': -110.303, 'current_zone': 'Potrero Norte', 'speed': 0.0, 'battery_v': 4.1},
    {'device_id': 'vaca_003', 'animal_name': 'Canela', 'latitude': 30.977, 'longitude': -110.302, 'current_zone': 'Corral Principal', 'speed': 0.5, 'battery_v': 3.6},
    {'device_id': 'vaca_004', 'animal_name': 'Luna', 'latitude': 30.983, 'longitude': -110.304, 'current_zone': 'Bebedero Arroyo', 'speed': 0.1, 'battery_v': 4.0},
    {'device_id': 'vaca_005', 'animal_name': 'Valentina', 'latitude': 30.992, 'longitude': -110.315, 'current_zone': null, 'speed': 1.2, 'battery_v': 3.4},
  ];

  // Geofence definitions
  final List<Polygon> _geofencePolygons = [
    // Potrero Norte (Green)
    Polygon(
      points: const [
        LatLng(30.980, -110.310),
        LatLng(30.990, -110.310),
        LatLng(30.990, -110.300),
        LatLng(30.980, -110.300),
      ],
      color: const Color(0xFF619F49).withAlpha(40),
      borderColor: const Color(0xFF619F49),
      borderStrokeWidth: 2,
      isFilled: true,
      label: 'Potrero Norte',
      labelStyle: const TextStyle(color: Color(0xFF619F49), fontSize: 11, fontWeight: FontWeight.bold),
    ),
    // Corral Principal (Orange)
    Polygon(
      points: const [
        LatLng(30.976, -110.303),
        LatLng(30.978, -110.303),
        LatLng(30.978, -110.301),
        LatLng(30.976, -110.301),
      ],
      color: const Color(0xFFFF9800).withAlpha(40),
      borderColor: const Color(0xFFFF9800),
      borderStrokeWidth: 2,
      isFilled: true,
      label: 'Corral Principal',
      labelStyle: const TextStyle(color: Color(0xFFFF9800), fontSize: 10, fontWeight: FontWeight.bold),
    ),
    // Bebedero Arroyo (Blue)
    Polygon(
      points: const [
        LatLng(30.982, -110.305),
        LatLng(30.984, -110.305),
        LatLng(30.984, -110.303),
        LatLng(30.982, -110.303),
      ],
      color: const Color(0xFF2196F3).withAlpha(45),
      borderColor: const Color(0xFF2196F3),
      borderStrokeWidth: 2,
      isFilled: true,
      label: 'Bebedero Arroyo',
      labelStyle: const TextStyle(color: Color(0xFF2196F3), fontSize: 10, fontWeight: FontWeight.bold),
    ),
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
      if (mounted) setState(() => _mqttConnected = true);
      _gpsSubscription = MqttRealtimeService.gpsStream.listen((data) {
        final deviceId = data['device_id'];
        if (mounted) {
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
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final positions = await RanchApiService.getCurrentPositions();
      final violations = await RanchApiService.getGeofenceViolations();
      if (mounted) {
        setState(() {
          _positions = positions.isNotEmpty ? positions : List<Map<String, dynamic>>.from(_demoPositions);
          _violations = violations.isNotEmpty ? violations : [_demoPositions.last];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _positions = List<Map<String, dynamic>>.from(_demoPositions);
          _violations = [_demoPositions.last];
        });
      }
    }
  }

  void _focusCow(Map<String, dynamic> pos) {
    final lat = (pos['latitude'] as num?)?.toDouble();
    final lng = (pos['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() => _selectedDeviceId = pos['device_id']);
      _mapController.move(LatLng(lat, lng), 16.5);
      _showCowModal(pos);
    }
  }

  void _showCowModal(Map<String, dynamic> pos) {
    final isOutOfZone = pos['current_zone'] == null;
    final speed = (pos['speed'] as num?)?.toDouble() ?? 0.0;
    final batV = (pos['battery_v'] as num?)?.toDouble() ?? 3.8;
    final batPct = ((batV - 3.2) / (4.2 - 3.2) * 100).clamp(0, 100).toInt();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isOutOfZone ? AppTheme.thiDanger.withAlpha(30) : AppTheme.primary.withAlpha(30),
                    child: Icon(Icons.pets_rounded, color: isOutOfZone ? AppTheme.thiDanger : AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pos['animal_name'] ?? pos['device_id'] ?? 'Animal',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'ID Collar: ${pos['device_id']}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutOfZone ? AppTheme.thiDanger.withAlpha(20) : AppTheme.thiNormal.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isOutOfZone ? AppTheme.thiDanger : AppTheme.thiNormal),
                    ),
                    child: Text(
                      isOutOfZone ? '⚠️ FUERA DE ZONA' : '✅ ${pos['current_zone']}',
                      style: TextStyle(
                        color: isOutOfZone ? AppTheme.thiDanger : AppTheme.thiNormal,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ModalMetric(icon: Icons.speed_rounded, label: 'Velocidad', value: '${speed.toStringAsFixed(1)} km/h'),
                  _ModalMetric(
                    icon: batPct < 20 ? Icons.battery_alert_rounded : Icons.battery_charging_full_rounded,
                    label: 'Batería',
                    value: '$batPct% (${batV.toStringAsFixed(1)}V)',
                    color: batPct < 20 ? AppTheme.thiDanger : AppTheme.primary,
                  ),
                  _ModalMetric(
                    icon: Icons.my_location_rounded,
                    label: 'Coordenadas',
                    value: '${(pos['latitude'] as num).toStringAsFixed(4)}, ${(pos['longitude'] as num).toStringAsFixed(4)}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
          _StatItem(icon: Icons.directions_run_rounded, label: 'Movimiento', value: '$moving', color: AppTheme.secondary),
          _StatItem(icon: _mqttConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded, label: 'MQTT',
              value: _mqttConnected ? 'LIVE' : 'DEMO',
              color: _mqttConnected ? AppTheme.thiNormal : AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    final violationIds = _violations.map((v) => v['device_id']).toSet();

    final markers = _positions.map((pos) {
      final lat = (pos['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (pos['longitude'] as num?)?.toDouble() ?? 0.0;
      final isViolation = violationIds.contains(pos['device_id']) || pos['current_zone'] == null;
      final isSelected = pos['device_id'] == _selectedDeviceId;
      final color = isViolation ? AppTheme.thiDanger : AppTheme.primary;

      return Marker(
        point: LatLng(lat, lng),
        width: 72,
        height: 52,
        child: GestureDetector(
          onTap: () => _focusCow(pos),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSelected ? Colors.white : Colors.black45, width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  pos['animal_name'] ?? pos['device_id'] ?? 'Vaca',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 1),
              Icon(
                Icons.location_on_rounded,
                color: color,
                size: isSelected ? 28 : 22,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();

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
            // Real OpenStreetMap
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 14.8,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.smartranch.app',
                ),
                PolygonLayer(polygons: _geofencePolygons),
                MarkerLayer(markers: markers),
              ],
            ),

            // Top-left label
            Positioned(
              left: 12, top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(235),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_rounded, size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Rancho Cananea — GPS Satelital',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Top-right Legend
            Positioned(
              right: 12, top: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(235),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendItem(color: AppTheme.primary, label: 'En zona'),
                    SizedBox(height: 3),
                    _LegendItem(color: AppTheme.thiDanger, label: 'Fuera de zona'),
                    SizedBox(height: 3),
                    _LegendItem(color: Color(0xFF2196F3), label: 'Bebedero'),
                    SizedBox(height: 3),
                    _LegendItem(color: Color(0xFF619F49), label: 'Potrero'),
                  ],
                ),
              ),
            ),

            // Bottom-right Map Controls (Zoom In, Zoom Out, Recenter)
            Positioned(
              right: 12, bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_in',
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom + 1);
                    },
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    child: const Icon(Icons.add, size: 18),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_zoom_out',
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom - 1);
                    },
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.textPrimary,
                    child: const Icon(Icons.remove, size: 18),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_recenter',
                    onPressed: () {
                      setState(() => _selectedDeviceId = null);
                      _mapController.move(_defaultCenter, 14.8);
                    },
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.my_location_rounded, size: 18),
                  ),
                ],
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
          final isSelected = pos['device_id'] == _selectedDeviceId;

          return GestureDetector(
            onTap: () => _focusCow(pos),
            child: Container(
              width: 155,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : (isOutOfZone ? AppTheme.thiDanger.withAlpha(90) : AppTheme.divider),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOutOfZone ? Icons.warning_amber_rounded : Icons.location_on_rounded,
                        size: 14,
                        color: isOutOfZone ? AppTheme.thiDanger : AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pos['animal_name'] ?? pos['device_id'] ?? '?',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
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
                      Icon(Icons.speed_rounded, size: 10, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '${((pos['speed'] as num?) ?? 0).toStringAsFixed(1)} km/h',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.battery_full_rounded,
                        size: 10,
                        color: ((pos['battery_v'] as num?) ?? 4) < 3.5
                            ? AppTheme.thiDanger
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${((pos['battery_v'] as num?) ?? 0).toStringAsFixed(1)}V',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
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
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _ModalMetric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;

  const _ModalMetric({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppTheme.primary),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
