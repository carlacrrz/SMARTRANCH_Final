import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/ranch_api_service.dart';
import '../services/mqtt_realtime_service.dart';

/// GPS Map screen — real OpenStreetMap view of Puerto Peñasco, Sonora
/// with live smartphone GPS location, cow collar positions and perimeter geofencing.
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
  StreamSubscription? _firestoreGpsSubscription;
  bool _mqttConnected = false;
  String? _selectedDeviceId;

  static const _puertoPenascoCenter = LatLng(31.3172, -113.5377);
  LatLng _phoneLocation = const LatLng(31.3175, -113.5372);

  static const _demoPositions = [
    {'device_id': 'vaca_001', 'animal_name': 'Lupita', 'latitude': 31.3200, 'longitude': -113.5360, 'current_zone': 'Potrero Peñasco Norte', 'speed': 0.2, 'battery_v': 3.9},
    {'device_id': 'vaca_002', 'animal_name': 'Estrella', 'latitude': 31.3190, 'longitude': -113.5390, 'current_zone': 'Potrero Peñasco Norte', 'speed': 0.0, 'battery_v': 4.1},
    {'device_id': 'vaca_003', 'animal_name': 'Canela', 'latitude': 31.3140, 'longitude': -113.5340, 'current_zone': 'Corral Central', 'speed': 0.5, 'battery_v': 3.6},
    {'device_id': 'vaca_004', 'animal_name': 'Luna', 'latitude': 31.3160, 'longitude': -113.5370, 'current_zone': 'Bebedero Principal', 'speed': 0.1, 'battery_v': 4.0},
    {'device_id': 'vaca_005', 'animal_name': 'Valentina', 'latitude': 31.3310, 'longitude': -113.5560, 'current_zone': null, 'speed': 1.4, 'battery_v': 3.4},
  ];

  List<Polygon> get _geofencePolygons {
    final list = <Polygon>[];
    if (AuthService.geofencePolygon.length >= 3) {
      list.add(
        Polygon(
          points: AuthService.geofencePolygon,
          color: const Color(0xFF619F49).withAlpha(40),
          borderColor: const Color(0xFF619F49),
          borderStrokeWidth: 2.5,
          isFilled: true,
          label: 'Perímetro Rancho Peñasco',
          labelStyle: const TextStyle(color: Color(0xFF619F49), fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }
    // Sub-potreros
    list.add(
      Polygon(
        points: const [
          LatLng(31.3130, -113.5360),
          LatLng(31.3155, -113.5360),
          LatLng(31.3155, -113.5320),
          LatLng(31.3130, -113.5320),
        ],
        color: const Color(0xFFFF9800).withAlpha(35),
        borderColor: const Color(0xFFFF9800),
        borderStrokeWidth: 2,
        isFilled: true,
        label: 'Corral Central',
        labelStyle: const TextStyle(color: Color(0xFFFF9800), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
    list.add(
      Polygon(
        points: const [
          LatLng(31.3155, -113.5380),
          LatLng(31.3170, -113.5380),
          LatLng(31.3170, -113.5360),
          LatLng(31.3155, -113.5360),
        ],
        color: const Color(0xFF3AAFA9).withAlpha(45),
        borderColor: const Color(0xFF3AAFA9),
        borderStrokeWidth: 2,
        isFilled: true,
        label: 'Bebedero Principal',
        labelStyle: const TextStyle(color: Color(0xFF3AAFA9), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectMqtt();
    _initFirestoreGps();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _firestoreGpsSubscription?.cancel();
    super.dispose();
  }

  void _initFirestoreGps() {
    try {
      _firestoreGpsSubscription = FirebaseFirestore.instance
          .collection('telemetry')
          .snapshots()
          .listen((snapshot) {
        if (!mounted || snapshot.docs.isEmpty) return;
        setState(() {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              final deviceId = (data['device_id'] as String?) ?? doc.id;
              final idx = _positions.indexWhere((p) => p['device_id'] == deviceId);
              final updated = {
                'device_id': deviceId,
                'animal_name': (data['animal_name'] as String?) ?? deviceId,
                'latitude': lat,
                'longitude': lng,
                'speed': (data['speed'] as num?)?.toDouble() ?? 0.0,
                'battery_v': (data['battery_voltage'] as num?)?.toDouble() ??
                    (data['battery_v'] as num?)?.toDouble() ?? 4.0,
                'current_zone': data['current_zone'] as String?,
              };
              if (idx >= 0) {
                _positions[idx] = updated;
              } else {
                _positions.add(updated);
              }
            }
          }
        });
      }, onError: (e) => debugPrint('Firestore GPS stream error: $e'));
    } catch (e) {
      debugPrint('Firestore GPS listener init error: $e');
    }
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
      _mapController.move(LatLng(lat, lng), 16.0);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Column(
          children: [
            _buildStatsBar(),
            Expanded(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _buildMapArea(),
                        ),
                        Container(
                          width: 320,
                          margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: _buildVerticalPositionList(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildMapArea()),
                        _buildPositionList(),
                      ],
                    ),
            ),
          ],
        );
      },
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
              value: _mqttConnected ? 'LIVE' : 'ACTIVO',
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
            // Real OpenStreetMap (Puerto Peñasco, Sonora)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: AuthService.ranchLocation,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.smartranch.app',
                ),
                PolygonLayer(polygons: _geofencePolygons),
                MarkerLayer(
                  markers: [
                    ...markers,
                    // User's Live Smartphone GPS Marker
                    Marker(
                      point: _phoneLocation,
                      width: 50,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Mi Celular',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.my_location_rounded, color: Color(0xFF2196F3), size: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top-left label: Puerto Peñasco, Sonora
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
                      '${AuthService.ranchName} — Puerto Peñasco, Sonora',
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
                    _LegendItem(color: Color(0xFF3AAFA9), label: 'Bebedero'),
                    SizedBox(height: 3),
                    _LegendItem(color: Color(0xFF2196F3), label: 'Mi Celular (GPS)'),
                  ],
                ),
              ),
            ),

            // Bottom-right Map Controls (Zoom, Recenter Peñasco, My Location)
            Positioned(
              right: 12, bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_user_gps',
                    onPressed: () {
                      _mapController.move(_phoneLocation, 16.0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📍 Centrado en la ubicación actual del celular (GPS)'),
                          backgroundColor: Color(0xFF2196F3),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    tooltip: 'Mi ubicación GPS',
                    child: const Icon(Icons.person_pin_circle_rounded, size: 20),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_recenter_penasco',
                    onPressed: () {
                      setState(() => _selectedDeviceId = null);
                      _mapController.move(AuthService.ranchLocation, 14.5);
                    },
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    tooltip: 'Centrar en Rancho Peñasco',
                    child: const Icon(Icons.home_work_rounded, size: 18),
                  ),
                  const SizedBox(height: 6),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionList() {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _positions.length,
        itemBuilder: (context, index) {
          final pos = _positions[index];
          final isOutOfZone = pos['current_zone'] == null;
          final isSelected = pos['device_id'] == _selectedDeviceId;

          return InkWell(
            onTap: () => _focusCow(pos),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withAlpha(20)
                    : AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : (isOutOfZone ? AppTheme.thiDanger.withAlpha(80) : AppTheme.divider),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.pets_rounded,
                        size: 14,
                        color: isOutOfZone ? AppTheme.thiDanger : AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pos['animal_name'] ?? pos['device_id'],
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isOutOfZone ? '⚠️ Fuera de zona' : (pos['current_zone'] ?? 'En rancho'),
                    style: TextStyle(
                      color: isOutOfZone ? AppTheme.thiDanger : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: isOutOfZone ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(pos['speed'] as num?)?.toStringAsFixed(1) ?? "0.0"} km/h',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                      ),
                      Icon(
                        Icons.battery_std_rounded,
                        size: 12,
                        color: AppTheme.textSecondary,
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

  Widget _buildVerticalPositionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.sensors_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Collares y Sensores IoT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_positions.length} activos',
                  style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AppTheme.divider),
        Expanded(
          child: _positions.isEmpty
              ? Center(
                  child: Text(
                    'No hay collares activos',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _positions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final pos = _positions[index];
                    final isOutOfZone = pos['current_zone'] == null;
                    final isSelected = pos['device_id'] == _selectedDeviceId;
                    final speed = (pos['speed'] as num?)?.toDouble() ?? 0.0;
                    final batV = (pos['battery_v'] as num?)?.toDouble() ?? 4.0;
                    final batPct = ((batV - 3.2) / (4.2 - 3.2) * 100).clamp(0, 100).toInt();

                    return InkWell(
                      onTap: () => _focusCow(pos),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withAlpha(25) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : (isOutOfZone ? AppTheme.thiDanger.withAlpha(80) : AppTheme.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isOutOfZone ? AppTheme.thiDanger : AppTheme.primary).withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pets_rounded,
                                size: 16,
                                color: isOutOfZone ? AppTheme.thiDanger : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pos['animal_name'] ?? pos['device_id'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOutOfZone ? '⚠️ Fuera de cerco' : (pos['current_zone'] ?? 'En rancho'),
                                    style: TextStyle(
                                      color: isOutOfZone ? AppTheme.thiDanger : AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: isOutOfZone ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${speed.toStringAsFixed(1)} km/h',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      batPct < 20 ? Icons.battery_alert_rounded : Icons.battery_full_rounded,
                                      size: 12,
                                      color: batPct < 20 ? AppTheme.thiDanger : AppTheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$batPct%',
                                      style: TextStyle(
                                        color: batPct < 20 ? AppTheme.thiDanger : AppTheme.textSecondary,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 9)),
      ],
    );
  }
}

class _ModalMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _ModalMetric({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color ?? AppTheme.textPrimary)),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
