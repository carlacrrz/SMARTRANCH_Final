import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Animal profile model for herd management.
class AnimalProfile {
  final int id;
  final String siniigaTag;
  final String deviceId;
  final String name;
  final String breed;
  final String sex;
  final String? birthDate;
  final double? weightKg;
  final String pasture;
  final String status;

  AnimalProfile({
    required this.id,
    required this.siniigaTag,
    this.deviceId = '',
    required this.name,
    this.breed = '',
    this.sex = 'hembra',
    this.birthDate,
    this.weightKg,
    this.pasture = '',
    this.status = 'active',
  });
}

/// Herd management screen — desktop DataTable with search/filter.
class HerdScreen extends StatefulWidget {
  const HerdScreen({super.key});

  @override
  State<HerdScreen> createState() => _HerdScreenState();
}

class _HerdScreenState extends State<HerdScreen> {
  final List<AnimalProfile> _animals = [
    AnimalProfile(id: 1, siniigaTag: 'MX-0026-0001', deviceId: 'vaca_001',
        name: 'Lupita', breed: 'Hereford', sex: 'hembra',
        birthDate: '2022-03-15', weightKg: 420, pasture: 'Potrero Norte'),
    AnimalProfile(id: 2, siniigaTag: 'MX-0026-0002', deviceId: 'vaca_002',
        name: 'Estrella', breed: 'Angus', sex: 'hembra',
        birthDate: '2021-06-22', weightKg: 380, pasture: 'Potrero Norte'),
    AnimalProfile(id: 3, siniigaTag: 'MX-0026-0003', deviceId: 'vaca_003',
        name: 'Canela', breed: 'Charolais', sex: 'hembra',
        birthDate: '2023-01-10', weightKg: 350, pasture: 'Corral Principal'),
    AnimalProfile(id: 4, siniigaTag: 'MX-0026-0004', deviceId: 'vaca_004',
        name: 'Luna', breed: 'Brahman', sex: 'hembra',
        birthDate: '2020-09-05', weightKg: 450, pasture: 'Potrero Sur'),
    AnimalProfile(id: 5, siniigaTag: 'MX-0026-0005', deviceId: 'vaca_005',
        name: 'Valentina', breed: 'Simmental', sex: 'hembra',
        birthDate: '2022-11-18', weightKg: 400, pasture: 'Potrero Sur'),
  ];

  String _searchQuery = '';
  String? _filterBreed;
  int? _hoveredIndex;

  List<AnimalProfile> get _filteredAnimals {
    var list = _animals.where((a) => a.status == 'active').toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.siniigaTag.toLowerCase().contains(q) ||
          a.breed.toLowerCase().contains(q) ||
          a.pasture.toLowerCase().contains(q)
      ).toList();
    }
    if (_filterBreed != null) {
      list = list.where((a) => a.breed == _filterBreed).toList();
    }
    return list;
  }

  List<String> get _breeds =>
      _animals.map((a) => a.breed).where((b) => b.isNotEmpty).toSet().toList()
        ..sort();

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAnimals;
    final activeCount = _animals.where((a) => a.status == 'active').length;

    return Column(
      children: [
        // Stats + Search Bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              // Stats
              _QuickStat(
                icon: Icons.pets_rounded,
                value: '$activeCount',
                label: 'Total',
                color: AppTheme.primary,
              ),
              const SizedBox(width: 16),
              _QuickStat(
                icon: Icons.female_rounded,
                value: '${_animals.where((a) => a.sex == "hembra" && a.status == "active").length}',
                label: 'Hembras',
                color: const Color(0xFFE91E63),
              ),
              const SizedBox(width: 16),
              _QuickStat(
                icon: Icons.male_rounded,
                value: '${_animals.where((a) => a.sex == "macho" && a.status == "active").length}',
                label: 'Machos',
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(width: 16),
              _QuickStat(
                icon: Icons.category_rounded,
                value: '${_breeds.length}',
                label: 'Razas',
                color: AppTheme.textSecondary,
              ),

              const Spacer(),

              // Search
              SizedBox(
                width: 260,
                height: 36,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar nombre, SINIIGA, raza...',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
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
              const SizedBox(width: 8),

              // Breed filter
              PopupMenuButton<String?>(
                icon: Icon(Icons.filter_list_rounded,
                    color: _filterBreed != null
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 20),
                tooltip: 'Filtrar por raza',
                onSelected: (value) => setState(() => _filterBreed = value),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Todas las razas')),
                  ..._breeds.map(
                    (b) => PopupMenuItem(value: b, child: Text(b)),
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
                      children: [
                        _ColHeader('Nombre', flex: 2),
                        _ColHeader('SINIIGA', flex: 2),
                        _ColHeader('Raza', flex: 2),
                        _ColHeader('Sexo', flex: 1),
                        _ColHeader('Peso', flex: 1),
                        _ColHeader('Potrero', flex: 2),
                        _ColHeader('Sensor', flex: 2),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.divider),

                  // Rows
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppTheme.divider,
                      ),
                      itemBuilder: (context, index) {
                        final animal = filtered[index];
                        final isHovered = _hoveredIndex == index;

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _hoveredIndex = index),
                          onExit: (_) =>
                              setState(() => _hoveredIndex = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            color: isHovered
                                ? AppTheme.primary.withAlpha(8)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
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
                                        style: const TextStyle(
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                // Raza
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      animal.breed,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600,
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
                                    style: const TextStyle(
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
                                          style: const TextStyle(
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
                                                style: TextStyle(
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
          ),
        ),
      ],
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
              style: const TextStyle(
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
