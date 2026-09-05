import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';

/// Main screen for the "Gestión de Hato" module — animal inventory.
class HatoScreen extends StatefulWidget {
  const HatoScreen({super.key});

  @override
  State<HatoScreen> createState() => _HatoScreenState();
}

class _HatoScreenState extends State<HatoScreen> {
  List<Animal> _animals = [];
  bool _isLoading = true;
  String? _error;
  String? _filterStatus;
  String? _filterCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final animals = await RanchApiService.getAnimals(
        status: _filterStatus,
        category: _filterCategory,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      setState(() {
        _animals = animals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('🐄 Gestión de Hato'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnimals,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAnimalDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, arete o dispositivo...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _searchQuery = '';
                        _loadAnimals();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (value) {
              _searchQuery = value;
              _loadAnimals();
            },
          ),
          const SizedBox(height: 10),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Todas', null, _filterStatus),
                _filterChip('Activas', 'active', _filterStatus),
                _filterChip('Cuarentena', 'quarantine', _filterStatus),
                _filterChip('Vendidas', 'sold', _filterStatus),
                const SizedBox(width: 16),
                _categoryChip('Vacas', 'cow'),
                _categoryChip('Toros', 'bull'),
                _categoryChip('Becerros', 'calf'),
                _categoryChip('Novillonas', 'heifer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value, String? current) {
    final isSelected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withValues(alpha: 0.3),
        checkmarkColor: AppTheme.primary,
        backgroundColor: AppTheme.card,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Colors.transparent,
        ),
        onSelected: (_) {
          setState(() => _filterStatus = value);
          _loadAnimals();
        },
      ),
    );
  }

  Widget _categoryChip(String label, String value) {
    final isSelected = _filterCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.secondary.withValues(alpha: 0.3),
        checkmarkColor: AppTheme.secondary,
        backgroundColor: AppTheme.card,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.secondary : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.secondary : Colors.transparent,
        ),
        onSelected: (_) {
          setState(() {
            _filterCategory = isSelected ? null : value;
          });
          _loadAnimals();
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('Error al cargar animales',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnimals,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_animals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐄', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Sin animales registrados',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Agrega tu primer animal con el botón +',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadAnimals,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _animals.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                '${_animals.length} animal${_animals.length == 1 ? '' : 'es'}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            );
          }
          return _buildAnimalTile(_animals[index - 1]);
        },
      ),
    );
  }

  Widget _buildAnimalTile(Animal animal) {
    final statusColor = switch (animal.status) {
      'active' => AppTheme.primary,
      'quarantine' => AppTheme.thiAlert,
      'sold' => AppTheme.textSecondary,
      'dead' => Colors.grey,
      _ => AppTheme.textSecondary,
    };

    final categoryIcon = switch (animal.category) {
      'cow' => '🐄',
      'bull' => '🐂',
      'calf' => '🐮',
      'heifer' => '🐄',
      'steer' => '🐃',
      _ => '🐄',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToAnimalProfile(animal),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: Text(categoryIcon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            animal.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            animal.statusDisplay,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (animal.earTag != null) ...[
                          Icon(Icons.label_outline,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text(animal.earTag!,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        Text(animal.categoryDisplay,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        if (animal.breed != null) ...[
                          const Text(' · ',
                              style: TextStyle(color: AppTheme.textSecondary)),
                          Text(animal.breed!,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (animal.weightKg != null) ...[
                          const Icon(Icons.monitor_weight_outlined,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text('${animal.weightKg!.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        const Icon(Icons.cake_outlined,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(animal.ageDisplay,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        if (animal.deviceId != null) ...[
                          const Spacer(),
                          Icon(Icons.sensors,
                              size: 14, color: AppTheme.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text('GPS',
                              style: TextStyle(
                                  color: AppTheme.primary.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAnimalProfile(Animal animal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalProfileScreen(animal: animal),
      ),
    );
  }

  void _showAddAnimalDialog() {
    final nameCtrl = TextEditingController();
    final earTagCtrl = TextEditingController();
    final breedCtrl = TextEditingController();
    final deviceIdCtrl = TextEditingController();
    String sex = 'female';
    String category = 'cow';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Registrar Animal',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              _sheetField(nameCtrl, 'Nombre *', Icons.pets),
              const SizedBox(height: 12),
              _sheetField(earTagCtrl, 'Arete SINIIGA', Icons.label_outline),
              const SizedBox(height: 12),
              _sheetField(breedCtrl, 'Raza', Icons.category),
              const SizedBox(height: 12),
              _sheetField(deviceIdCtrl, 'Device ID (ESP32)', Icons.sensors),
              const SizedBox(height: 16),
              // Sex selector
              Row(
                children: [
                  const Text('Sexo: ',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Hembra'),
                    selected: sex == 'female',
                    selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                    onSelected: (_) => setSheetState(() => sex = 'female'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Macho'),
                    selected: sex == 'male',
                    selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                    onSelected: (_) => setSheetState(() => sex = 'male'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category selector
              Row(
                children: [
                  const Text('Categoría: ',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _catChip('Vaca', 'cow', category,
                            (v) => setSheetState(() => category = v)),
                        _catChip('Toro', 'bull', category,
                            (v) => setSheetState(() => category = v)),
                        _catChip('Becerro', 'calf', category,
                            (v) => setSheetState(() => category = v)),
                        _catChip('Novillona', 'heifer', category,
                            (v) => setSheetState(() => category = v)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await RanchApiService.createAnimal({
                      'name': nameCtrl.text,
                      'ear_tag': earTagCtrl.text.isEmpty
                          ? null
                          : earTagCtrl.text,
                      'breed':
                          breedCtrl.text.isEmpty ? null : breedCtrl.text,
                      'device_id': deviceIdCtrl.text.isEmpty
                          ? null
                          : deviceIdCtrl.text,
                      'sex': sex,
                      'category': category,
                      'status': 'active',
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadAnimals();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _catChip(
      String label, String value, String current, ValueChanged<String> onTap) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppTheme.secondary.withValues(alpha: 0.3),
      onSelected: (_) => onTap(value),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ============================================================
//  Animal Profile Screen (detailed view)
// ============================================================

class AnimalProfileScreen extends StatefulWidget {
  final Animal animal;
  const AnimalProfileScreen({super.key, required this.animal});

  @override
  State<AnimalProfileScreen> createState() => _AnimalProfileScreenState();
}

class _AnimalProfileScreenState extends State<AnimalProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _fullProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile =
          await RanchApiService.getAnimalFullProfile(widget.animal.id);
      setState(() {
        _fullProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animal = widget.animal;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // App bar with animal info
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.2),
                      AppTheme.surface,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          animal.name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            animal.categoryDisplay,
                            style: const TextStyle(
                                color: AppTheme.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (animal.earTag != null)
                          _infoChip(Icons.label_outline, animal.earTag!),
                        if (animal.breed != null)
                          _infoChip(Icons.category, animal.breed!),
                        _infoChip(Icons.cake_outlined, animal.ageDisplay),
                        if (animal.weightKg != null)
                          _infoChip(Icons.monitor_weight_outlined,
                              '${animal.weightKg!.toStringAsFixed(0)} kg'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline), text: 'Info'),
                Tab(icon: Icon(Icons.medical_services_outlined), text: 'Salud'),
                Tab(icon: Icon(Icons.favorite_outline), text: 'Reprod.'),
                Tab(icon: Icon(Icons.monitor_weight_outlined), text: 'Peso'),
              ],
            ),
          ),

          // Tab content
          SliverFillRemaining(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInfoTab(animal),
                      _buildMedicalTab(),
                      _buildReproductiveTab(),
                      _buildWeightTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Animal animal) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard('Identificación', [
          _detailRow('Nombre', animal.name),
          _detailRow('Arete SINIIGA', animal.earTag ?? '—'),
          _detailRow('Device ID', animal.deviceId ?? 'Sin dispositivo'),
          _detailRow('Sexo', animal.sex == 'female' ? 'Hembra' : 'Macho'),
          _detailRow('Categoría', animal.categoryDisplay),
          _detailRow('Raza', animal.breed ?? '—'),
        ]),
        const SizedBox(height: 12),
        _sectionCard('Estado', [
          _detailRow('Status', animal.statusDisplay),
          _detailRow('Peso actual', animal.weightKg != null
              ? '${animal.weightKg!.toStringAsFixed(1)} kg'
              : '—'),
          _detailRow('Edad', animal.ageDisplay),
          _detailRow('Fecha nacimiento', animal.birthDate != null
              ? '${animal.birthDate!.day}/${animal.birthDate!.month}/${animal.birthDate!.year}'
              : '—'),
        ]),
        if (animal.notes != null && animal.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionCard('Notas', [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(animal.notes!,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _buildMedicalTab() {
    final records = (_fullProfile?['medical_records'] as List<dynamic>?) ?? [];
    if (records.isEmpty) {
      return _emptyState('💉', 'Sin registros médicos');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final r = records[index] as Map<String, dynamic>;
        final record = MedicalRecord.fromJson(r);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(record.recordTypeDisplay.split(' ').first,
                style: const TextStyle(fontSize: 24)),
            title: Text(record.productName ?? record.recordType,
                style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Text(
              '${record.dose ?? ''} · ${record.administeredBy ?? ''}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            trailing: record.recordedAt != null
                ? Text(
                    '${record.recordedAt!.day}/${record.recordedAt!.month}',
                    style:
                        const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildReproductiveTab() {
    final events =
        (_fullProfile?['reproductive_events'] as List<dynamic>?) ?? [];
    if (events.isEmpty) {
      return _emptyState('💕', 'Sin eventos reproductivos');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index] as Map<String, dynamic>;
        final event = ReproductiveEvent.fromJson(e);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(event.eventTypeDisplay.split(' ').first,
                style: const TextStyle(fontSize: 24)),
            title: Text(event.eventTypeDisplay,
                style: const TextStyle(color: AppTheme.textPrimary)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.bullOrSemen != null)
                  Text('Toro/Semen: ${event.bullOrSemen}',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                if (event.expectedBirthDate != null)
                  Text(
                    'Parto esperado: ${event.expectedBirthDate!.day}/${event.expectedBirthDate!.month}/${event.expectedBirthDate!.year}',
                    style: const TextStyle(color: AppTheme.thiAlert),
                  ),
              ],
            ),
            trailing: event.recordedAt != null
                ? Text(
                    '${event.recordedAt!.day}/${event.recordedAt!.month}',
                    style:
                        const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildWeightTab() {
    final weights =
        (_fullProfile?['weight_records'] as List<dynamic>?) ?? [];
    if (weights.isEmpty) {
      return _emptyState('⚖️', 'Sin registros de peso');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: weights.length,
      itemBuilder: (context, index) {
        final w = weights[index] as Map<String, dynamic>;
        final record = WeightRecord.fromJson(w);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.monitor_weight_outlined,
                color: AppTheme.primary, size: 28),
            title: Text('${record.weightKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18)),
            subtitle: record.bodyConditionScore != null
                ? Text('CC: ${record.bodyConditionScore}/9',
                    style: const TextStyle(color: AppTheme.textSecondary))
                : null,
            trailing: record.recordedAt != null
                ? Text(
                    '${record.recordedAt!.day}/${record.recordedAt!.month}/${record.recordedAt!.year}',
                    style:
                        const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _emptyState(String emoji, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
