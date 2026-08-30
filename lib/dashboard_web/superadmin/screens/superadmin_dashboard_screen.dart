import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/theme_controller.dart';
import '../../utils/color_hex.dart';
import '../services/superadmin_repository.dart';
import '../widgets/configure_modules_drawer.dart';
import '../widgets/new_brand_modal.dart';
import '../widgets/edit_brand_modal.dart';

/// Pantalla principal del SuperAdmin: muestra la tabla de todas las marcas
/// registradas en el SaaS con acciones para configurar módulos, crear y editar.
class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final SuperAdminRepository _repo = SuperAdminRepository();
  StreamSubscription? _marcasSub;
  List<MarcaRecord> _marcas = [];
  bool _loading = true;
  String _searchQuery = '';
  String _planFilter = 'Todos'; // Todos | Solo Player | Full Suite

  @override
  void initState() {
    super.initState();
    _marcasSub = _repo.streamAllMarcas().listen((marcas) {
      if (mounted) {
        setState(() {
          _marcas = marcas;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _marcasSub?.cancel();
    super.dispose();
  }

  List<MarcaRecord> get _filteredMarcas {
    var list = _marcas;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) {
        return m.appId.toLowerCase().contains(q) ||
            m.nombreGrupo.toLowerCase().contains(q) ||
            m.ownerEmail.toLowerCase().contains(q);
      }).toList();
    }
    if (_planFilter == 'Solo Player') {
      list = list.where((m) => m.planLabel == 'Solo Player').toList();
    } else if (_planFilter == 'Full Suite') {
      list = list.where((m) => m.planLabel == 'Full Suite').toList();
    }
    return list;
  }

  void _openModulesDrawer(MarcaRecord marca) {
    showDialog(
      context: context,
      builder: (ctx) => ConfigureModulesDrawer(
        marca: marca,
        repository: _repo,
      ),
    );
  }

  void _openNewBrandModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewBrandModal(repository: _repo),
    );
  }

  void _openEditBrandModal(MarcaRecord marca) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditBrandModal(marca: marca, repository: _repo),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          // ─── SIDEBAR ───
          _SuperAdminSidebar(
            scheme: scheme,
            textTheme: textTheme,
            onSignOut: _signOut,
          ),
          // ─── MAIN CONTENT ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── METRIC CARDS ───
                _MetricBar(
                  scheme: scheme,
                  textTheme: textTheme,
                  totalMarcas: _marcas.length,
                  soloPlayerCount: _marcas.where((m) => m.planLabel == 'Solo Player').length,
                  fullSuiteCount: _marcas.where((m) => m.planLabel == 'Full Suite').length,
                ),
                const SizedBox(height: 4),
                // ─── SEARCH + FILTERS + NEW BRAND BUTTON ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Gestión de Marcas y Clientes',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, appId o email…',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PlanFilterChips(
                        current: _planFilter,
                        onChanged: (v) => setState(() => _planFilter = v),
                        scheme: scheme,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _openNewBrandModal,
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva Marca'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ─── TABLE ───
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _MarcasTable(
                          marcas: _filteredMarcas,
                          scheme: scheme,
                          textTheme: textTheme,
                          onConfigureModules: _openModulesDrawer,
                          onEdit: _openEditBrandModal,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// SIDEBAR
// ═══════════════════════════════════════════════
class _SuperAdminSidebar extends StatelessWidget {
  const _SuperAdminSidebar({
    required this.scheme,
    required this.textTheme,
    required this.onSignOut,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo / Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cell_tower, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radio SaaS',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Master Console',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Theme toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: const Text('Modo oscuro'),
                      subtitle: Text(
                        isDark ? 'Activado' : 'Desactivado',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      value: isDark,
                      onChanged: (v) async {
                        final next = v ? ThemeMode.dark : ThemeMode.light;
                        themeModeNotifier.value = next;
                        await persistThemePreference(next);
                      },
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 24),
            // Nav items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.business),
                  title: const Text('Marcas y Clientes'),
                  selected: true,
                ),
              ),
            ),
            const Spacer(),
            // SuperAdmin badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUPER ADMIN',
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            SuperAdminRepository.superAdminEmail,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: onSignOut,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// METRIC BAR (Top KPI Cards)
// ═══════════════════════════════════════════════
class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.scheme,
    required this.textTheme,
    required this.totalMarcas,
    required this.soloPlayerCount,
    required this.fullSuiteCount,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final int totalMarcas;
  final int soloPlayerCount;
  final int fullSuiteCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Row(
        children: [
          Expanded(
            child: _KpiCard(
              icon: Icons.business,
              iconColor: scheme.primary,
              label: 'Total Marcas',
              value: '$totalMarcas Registradas',
              scheme: scheme,
              textTheme: textTheme,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _KpiCard(
              icon: Icons.radio,
              iconColor: const Color(0xFF38BDF8),
              label: 'Solo Player',
              value: '$soloPlayerCount emisoras',
              scheme: scheme,
              textTheme: textTheme,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _KpiCard(
              icon: Icons.live_tv,
              iconColor: const Color(0xFF10B981),
              label: 'Full Suite',
              value: '$fullSuiteCount emisoras',
              scheme: scheme,
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.scheme,
    required this.textTheme,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// PLAN FILTER CHIPS
// ═══════════════════════════════════════════════
class _PlanFilterChips extends StatelessWidget {
  const _PlanFilterChips({
    required this.current,
    required this.onChanged,
    required this.scheme,
  });

  final String current;
  final ValueChanged<String> onChanged;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Todos', label: Text('Todos')),
        ButtonSegment(value: 'Solo Player', label: Text('Solo Player')),
        ButtonSegment(value: 'Full Suite', label: Text('Full Suite')),
      ],
      selected: {current},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// MARCAS TABLE
// ═══════════════════════════════════════════════
class _MarcasTable extends StatelessWidget {
  const _MarcasTable({
    required this.marcas,
    required this.scheme,
    required this.textTheme,
    required this.onConfigureModules,
    required this.onEdit,
  });

  final List<MarcaRecord> marcas;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ValueChanged<MarcaRecord> onConfigureModules;
  final ValueChanged<MarcaRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    if (marcas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No se encontraron marcas',
              style: textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Card(
        child: Column(
          children: [
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _HeaderCell('MARCA / LOGO', flex: 3),
                  _HeaderCell('OWNER EMAIL', flex: 3),
                  _HeaderCell('PLAN', flex: 2),
                  _HeaderCell('MÓDULOS', flex: 3),
                  _HeaderCell('ESTADO', flex: 1),
                  _HeaderCell('ACCIONES', flex: 2),
                ],
              ),
            ),
            const Divider(height: 1),
            // Table rows
            ...marcas.map((m) => _MarcaRow(
                  marca: m,
                  scheme: scheme,
                  textTheme: textTheme,
                  onConfigureModules: () => onConfigureModules(m),
                  onEdit: () => onEdit(m),
                )),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.flex = 1});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MarcaRow extends StatelessWidget {
  const _MarcaRow({
    required this.marca,
    required this.scheme,
    required this.textTheme,
    required this.onConfigureModules,
    required this.onEdit,
  });

  final MarcaRecord marca;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onConfigureModules;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final brandColor = ColorHex.tryParse(marca.colorHex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          // MARCA / LOGO
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: brandColor ?? scheme.primaryContainer,
                  backgroundImage: marca.logoUrl.isNotEmpty ? NetworkImage(marca.logoUrl) : null,
                  child: marca.logoUrl.isEmpty
                      ? Text(
                          marca.nombreGrupo.isNotEmpty
                              ? marca.nombreGrupo.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marca.nombreGrupo,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'appId: ${marca.appId}',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // OWNER EMAIL
          Expanded(
            flex: 3,
            child: Text(
              marca.ownerEmail,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // PLAN BADGE
          Expanded(
            flex: 2,
            child: _PlanBadge(plan: marca.planLabel),
          ),
          // MÓDULOS (mini icons)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _ModuleIcon(
                  icon: Icons.radio,
                  enabled: marca.features.enableRadio,
                  tooltip: 'Audio',
                  scheme: scheme,
                ),
                _ModuleIcon(
                  icon: Icons.live_tv,
                  enabled: marca.features.enableTv,
                  tooltip: 'TV',
                  scheme: scheme,
                ),
                _ModuleIcon(
                  icon: Icons.calendar_month,
                  enabled: marca.features.enableSchedule,
                  tooltip: 'Programación',
                  scheme: scheme,
                ),
                _ModuleIcon(
                  icon: Icons.settings,
                  enabled: marca.features.enableSettings,
                  tooltip: 'Ajustes',
                  scheme: scheme,
                ),
                _ModuleIcon(
                  icon: Icons.cell_tower,
                  enabled: marca.features.enableMultiStation,
                  tooltip: 'Multi-Emisora',
                  scheme: scheme,
                ),
              ],
            ),
          ),
          // ESTADO
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: marca.active
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : scheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                marca.active ? 'Activo' : 'Suspendido',
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(
                  color: marca.active ? const Color(0xFF10B981) : scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // ACCIONES
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Tooltip(
                  message: 'Configurar Módulos',
                  child: IconButton(
                    icon: const Icon(Icons.settings_suggest_outlined, size: 20),
                    onPressed: onConfigureModules,
                  ),
                ),
                Tooltip(
                  message: 'Editar Marca',
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});
  final String plan;

  @override
  Widget build(BuildContext context) {
    final isFullSuite = plan == 'Full Suite';
    final color = isFullSuite ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          plan,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.scheme,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$tooltip: ${enabled ? 'Activo' : 'Inactivo'}',
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF10B981) : scheme.onSurfaceVariant.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
