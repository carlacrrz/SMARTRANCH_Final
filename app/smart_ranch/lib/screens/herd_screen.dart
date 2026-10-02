import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';
import '../widgets/crud_dialogs.dart';

/// Animal profile model for herd management.
class AnimalProfile {
  final int id;
  final String siniigaTag;
  final String deviceId;
  final String name;
  final String breed;
  final String sex;
  final String category;
  final String? birthDate;
  final double? weightKg;
  final String pasture;
  final String status;
  final String notes;
  final int batteryLevel;

  AnimalProfile({
    required this.id,
    required this.siniigaTag,
    this.deviceId = '',
    required this.name,
    this.breed = '',
    this.sex = 'hembra',
    this.category = 'vaca',
    this.birthDate,
    this.weightKg,
    this.pasture = '',
    this.status = 'active',
    this.notes = 'En pastoreo regular. Sin anomalías.',
    this.batteryLevel = 92,
  });
}

/// Herd management screen — desktop DataTable with search/filter.
class HerdScreen extends StatefulWidget {
  const HerdScreen({super.key});

  @override
  State<HerdScreen> createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> {
  List<AnimalProfile> _animals = [];
  bool _isLoading = false;
  StreamSubscription? _animalsSub;

  String _searchQuery = '';
  String? _filterBreed;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _loadAnimals();
    _initFirestoreAnimals();
  }

  @override
  void dispose() {
    _animalsSub?.cancel();
    super.dispose();
  }

  void _initFirestoreAnimals() {
    try {
      _animalsSub = FirebaseFirestore.instance.collection('animals').snapshots().listen((snapshot) {
        if (!mounted) return;
        _loadAnimals();
      }, onError: (e) => debugPrint('Firestore animals stream error: $e'));
    } catch (e) {
      debugPrint('Firestore animals init error: $e');
    }
  }

  Future<void> _loadAnimals() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final animals = await RanchApiService.getAnimals();
      final records = await RanchApiService.getWeightRecords();
      final latestWeight = <int, double>{};
      for (final r in records) {
        if (!latestWeight.containsKey(r.animalId)) {
          latestWeight[r.animalId] = r.weightKg;
        }
      }
      if (!mounted) return;
      setState(() {
        _animals = animals.map((a) => AnimalProfile(
          id: a.id,
          siniigaTag: (a.earTag != null && a.earTag!.isNotEmpty) ? a.earTag! : 'S/N',
          deviceId: a.deviceId ?? '',
          name: a.name,
          breed: a.breed ?? 'Brangus',
          sex: a.sex,
          category: a.category,
          birthDate: a.birthDate != null ? a.birthDate!.toIso8601String().split('T').first : null,
          weightKg: latestWeight[a.id] ?? a.weightKg,
          pasture: 'Potrero Principal',
          status: a.status,
          notes: a.notes ?? '',
          batteryLevel: 92,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<AnimalProfile> get _filteredAnimals {
    var list = _animals.where((a) => a.status == 'active').toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.siniigaTag.toLowerCase().contains(q) ||
          a.breed.toLowerCase().contains(q) ||
          a.pasture.toLowerCase().contains(q) ||
          a.deviceId.toLowerCase().contains(q) ||
          '#${a.id}'.contains(q)
      ).toList();
    }
    if (_filterBreed != null && _filterBreed!.isNotEmpty && _filterBreed != 'Todas las razas') {
      list = list.where((a) => a.breed.toLowerCase() == _filterBreed!.toLowerCase()).toList();
    }
    return list;
  }

  List<String> get _breeds =>
      _animals.map((a) => a.breed).where((b) => b.isNotEmpty).toSet().toList()
        ..sort();

  void _showAnimalDetails(AnimalProfile animal) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.divider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar + Name + ID + Close
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withAlpha(60)),
                      ),
                      child: Icon(Icons.pets_rounded, color: AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                animal.name,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${animal.id}',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SINIIGA: ${animal.siniigaTag}',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: AppTheme.divider, height: 1),
                const SizedBox(height: 16),

                // IoT Collar Section
                Text(
                  'COLLAR INTELIGENTE (IoT)',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              animal.deviceId.isNotEmpty ? animal.deviceId : 'Sin sensor vinculado',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sensor NFC & GPS activo • En línea',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.battery_charging_full_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${animal.batteryLevel}%',
                              style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details Grid
                Text(
                  'DATOS GENERALES',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Raza', value: animal.breed, icon: Icons.category_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoTile(label: 'Sexo', value: animal.sex == 'hembra' ? 'Hembra' : 'Macho', icon: animal.sex == 'hembra' ? Icons.female_rounded : Icons.male_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Categoría', value: animal.category.toUpperCase(), icon: Icons.pets_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoTile(label: 'Peso Actual', value: animal.weightKg != null ? '${animal.weightKg!.toStringAsFixed(0)} kg' : '--', icon: Icons.monitor_weight_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _InfoTile(label: 'Ubicación / Potrero', value: animal.pasture, icon: Icons.location_on_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _InfoTile(label: 'Nacimiento', value: animal.birthDate ?? 'N/D', icon: Icons.event_rounded)),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes
                Text('Notas:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(animal.notes, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5)),

                const SizedBox(height: 20),

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final saved = await showAddWeightDialog(context, animalId: animal.id);
                          if (saved == true) {
                            _loadAnimals();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Peso registrado y actualizado en el inventario'),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                        label: const Text('Pesar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final saved = await showAddMedicalDialog(context, animalId: animal.id);
                          if (saved == true) {
                            _loadAnimals();
                          }
                        },
                        icon: const Icon(Icons.medical_services_outlined, size: 16),
                        label: const Text('Salud'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAnimals;
    final activeCount = _animals.where((a) => a.status == 'active').length;

    return Column(
      children: [
        // Stats + Search Bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
              // Stats Row — evenly centered across full width
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.pets_rounded,
                        value: '$activeCount',
                        label: 'Total',
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppTheme.divider),
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.female_rounded,
                        value: '${_animals.where((a) => a.sex == "hembra" && a.status == "active").length}',
                        label: 'Hembras',
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppTheme.divider),
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.male_rounded,
                        value: '${_animals.where((a) => a.sex == "macho" && a.status == "active").length}',
                        label: 'Machos',
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ),
                  Container(height: 32, width: 1, color: AppTheme.divider),
                  Expanded(
                    child: Center(
                      child: _QuickStat(
                        icon: Icons.category_rounded,
                        value: '${_breeds.length}',
                        label: 'Razas',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),

              // Search & Filter Row — centered
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar nombre, arete, ID, sensor...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: AppTheme.textSecondary, size: 18),
                            filled: true,
                            fillColor: AppTheme.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTheme.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Breed filter
                  PopupMenuButton<String?>(
                    icon: Icon(Icons.filter_list_rounded,
                        color: _filterBreed != null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        size: 22),
                    tooltip: 'Filtrar por raza',
                    onSelected: (value) {
                      setState(() {
                        _filterBreed = (value == null || value == 'Todas las razas' || value.isEmpty)
                            ? null
                            : value;
                      });
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem<String?>(value: null, child: Text('Todas las razas')),
                      ..._breeds.map(
                        (b) => PopupMenuItem<String?>(value: b, child: Text(b)),
                      ),
                    ],
                  ),

                  // Filter chip when active
                  if (_filterBreed != null) ...[
                    const SizedBox(width: 6),
                    InputChip(
                      label: Text(_filterBreed!, style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.primary.withAlpha(20),
                      deleteIconColor: AppTheme.primary,
                      onDeleted: () => setState(() => _filterBreed = null),
                    ),
                  ],

                  const SizedBox(width: 8),

                  // Add animal button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final saved = await showAddAnimalDialog(context);
                      if (saved == true) {
                        _loadAnimals();
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Registrar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // DataTable
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pets_outlined, size: 48, color: AppTheme.textSecondary.withAlpha(120)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No se encontraron animales con ese criterio'
                                  : 'No hay ganado registrado en este rancho',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Presiona "Registrar" para dar de alta animales con su arete y collar.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: constraints.maxWidth > 850 ? constraints.maxWidth : 850,
                            child: Column(
                              children: [
                                // Column Headers
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(10)),
                                  ),
                                  child: Row(
                                    children: const [
                                      _ColHeader('ID', flex: 1),
                                      _ColHeader('Nombre', flex: 2),
                                      _ColHeader('Arete SINIIGA', flex: 2),
                                      _ColHeader('Raza', flex: 2),
                                      _ColHeader('Sexo', flex: 1),
                                      _ColHeader('Peso', flex: 1),
                                      _ColHeader('Potrero', flex: 2),
                                      _ColHeader('Sensor / Collar', flex: 2),
                                    ],
                                  ),
                                ),
                                Divider(height: 1, color: AppTheme.divider),

                                // Rows
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color: AppTheme.divider,
                                    ),
                                    itemBuilder: (context, index) {
                                      final animal = filtered[index];
                                      final isHovered = _hoveredIndex == index;

                                return InkWell(
                                  onTap: () => _showAnimalDetails(animal),
                                  onHover: (hovering) {
                                    setState(() {
                                      _hoveredIndex = hovering ? index : null;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    color: isHovered
                                        ? AppTheme.primary.withAlpha(12)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        // ID
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '#${animal.id}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ),
                                        // Nombre
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Icon(
                                                animal.sex == 'hembra'
                                                    ? Icons.female_rounded
                                                    : Icons.male_rounded,
                                                size: 16,
                                                color: animal.sex == 'hembra'
                                                    ? const Color(0xFFE91E63)
                                                    : const Color(0xFF2196F3),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                animal.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // SINIIGA
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            animal.siniigaTag,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        // Raza
                                        Expanded(
                                          flex: 2,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withAlpha(20),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                animal.breed,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Sexo
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            animal.sex == 'hembra' ? 'H' : 'M',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                        // Peso
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            animal.weightKg != null
                                                ? '${animal.weightKg!.toStringAsFixed(0)} kg'
                                                : '--',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        // Potrero
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Icon(Icons.location_on_rounded,
                                                  size: 12,
                                                  color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  animal.pasture,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Sensor
                                        Expanded(
                                          flex: 2,
                                          child: animal.deviceId.isNotEmpty
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primary
                                                        .withAlpha(12),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.sensors_rounded,
                                                          size: 12,
                                                          color: AppTheme.primary),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        animal.deviceId,
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppTheme.primary,
                                                          fontFamily: 'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : Text(
                                                  'Sin sensor',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textSecondary
                                                        .withAlpha(80),
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String label;
  final int flex;
  const _ColHeader(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
