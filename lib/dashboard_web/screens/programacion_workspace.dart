import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/utils/programacion_horario_format.dart';
import 'package:radio_whitelabel/dashboard_web/utils/programacion_row_codec.dart';
import 'package:radio_whitelabel/dashboard_web/utils/tenant_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramacionWorkspace extends StatefulWidget {
  const ProgramacionWorkspace({
    super.key,
    required this.repository,
    required this.ownerEmail,
    required this.appId,
    required this.radios,
    required this.streamings,
  });

  final EmisoraRepository repository;
  final String ownerEmail;
  final String appId;
  final List<Emisora> radios;
  final List<Streaming> streamings;

  @override
  State<ProgramacionWorkspace> createState() => _ProgramacionWorkspaceState();
}

class _ProgramacionWorkspaceState extends State<ProgramacionWorkspace> with SingleTickerProviderStateMixin {
  static const List<_DayConfig> _dayConfigs = [
    _DayConfig(key: EmisoraFields.lunes, label: 'Lunes'),
    _DayConfig(key: EmisoraFields.martes, label: 'Martes'),
    _DayConfig(key: EmisoraFields.miercoles, label: 'Miércoles'),
    _DayConfig(key: EmisoraFields.jueves, label: 'Jueves'),
    _DayConfig(key: EmisoraFields.viernes, label: 'Viernes'),
    _DayConfig(key: EmisoraFields.sabado, label: 'Sábado'),
    _DayConfig(key: EmisoraFields.domingo, label: 'Domingo'),
  ];

  bool _saving = false;
  String? _targetId;
  bool _targetLoaded = false;
  String? _loadedDocId;
  String? _pendingApplyForDocId;
  bool? _lastAppliedSnapshotFromCache;
  late final Map<String, List<_RowControllers>> _rowsByDay;
  late final TabController _tabController;

  String get _targetPrefKey => 'programacion.target.${widget.ownerEmail}.${widget.appId}';

  List<_TargetOption> get _targets => [
        ...widget.radios
            .where((r) => r.mostrarProgramacion)
            .map((r) => _TargetOption(id: r.id, label: r.nombre, type: 'Radio')),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dayConfigs.length, vsync: this);
    _rowsByDay = {
      for (final day in _dayConfigs) day.key: <_RowControllers>[_RowControllers.empty()],
    };
    _targetId = _targets.isNotEmpty ? _targets.first.id : null;
    _loadLastTarget();
  }

  Future<void> _loadLastTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_targetPrefKey);
      if (!mounted) return;
      if (saved != null && _targets.any((t) => t.id == saved)) {
        setState(() {
          _targetId = saved;
          _targetLoaded = true;
        });
      } else {
        setState(() => _targetLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _targetLoaded = true);
    }
  }

  Future<void> _saveLastTarget(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_targetPrefKey, id);
    } catch (_) {}
  }

  void _disposeRows(List<_RowControllers> rows) {
    for (final row in rows) {
      row.dispose();
    }
  }

  List<_RowControllers> _parseRowsForDay(dynamic dayData) {
    if (dayData is List) {
      final parsed = <({int index, _RowControllers row})>[];
      for (var i = 0; i < dayData.length; i++) {
        final item = dayData[i];
        if (item is Map) {
          final h = (item['h'] ?? '').toString();
          final p = (item['p'] ?? '').toString();
          final t = (item['t'] ?? '').toString();
          final idx = (item[EmisoraFields.index] as num?)?.toInt() ?? i;
          parsed.add((index: idx, row: _RowControllers.fromHorarioString(h: h, p: p, t: t)));
        }
      }
      if (parsed.isNotEmpty) {
        parsed.sort((a, b) => a.index.compareTo(b.index));
        return parsed.map((e) => e.row).toList();
      }
    }
    if (dayData is String && dayData.trim().isNotEmpty) {
      return [_RowControllers.fromHorarioString(h: '', p: dayData.trim(), t: '')];
    }
    return <_RowControllers>[_RowControllers.empty()];
  }

  void _fillFromDocData(Map<String, dynamic> data) {
    for (final day in _dayConfigs) {
      final oldRows = _rowsByDay[day.key] ?? const <_RowControllers>[];
      _disposeRows(oldRows);
      _rowsByDay[day.key] = _parseRowsForDay(data[day.key]);
    }
  }

  void _resetRowsToEmpty() {
    for (final day in _dayConfigs) {
      final oldRows = _rowsByDay[day.key] ?? const <_RowControllers>[];
      _disposeRows(oldRows);
      _rowsByDay[day.key] = <_RowControllers>[_RowControllers.empty()];
    }
  }

  void _applyProgramacionSnapshotIfCurrent(DocumentSnapshot<Map<String, dynamic>> doc) {
    final target = _targetId;
    if (target == null || doc.id != target) return;
    final cacheToServer = _loadedDocId == doc.id &&
        _lastAppliedSnapshotFromCache == true &&
        !doc.metadata.isFromCache;
    if (_loadedDocId == doc.id && !cacheToServer) return;
    if (_pendingApplyForDocId == doc.id) return;
    _pendingApplyForDocId = doc.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingApplyForDocId = null;
      if (!mounted) return;
      if (_targetId != doc.id) return;
      final cacheToServerInner = _loadedDocId == doc.id &&
          _lastAppliedSnapshotFromCache == true &&
          !doc.metadata.isFromCache;
      if (_loadedDocId == doc.id && !cacheToServerInner) return;
      setState(() {
        _loadedDocId = doc.id;
        _lastAppliedSnapshotFromCache = doc.metadata.isFromCache;
        _fillFromDocData(doc.data() ?? const <String, dynamic>{});
      });
    });
  }

  List<Map<String, dynamic>> _toJsonRows(String dayKey) {
    final rows = _rowsByDay[dayKey] ?? const <_RowControllers>[];
    return ProgramacionRowCodec.encodeDayRows(
      rows: rows.map(
        (row) => (
          h: row.horarioEncoded,
          p: row.pCtrl.text,
          t: row.tCtrl.text,
        ),
      ),
    );
  }

  void _addRow(String dayKey) {
    setState(() {
      _rowsByDay[dayKey]!.add(_RowControllers.empty());
    });
  }

  void _removeRow(String dayKey, int index) {
    setState(() {
      final rows = _rowsByDay[dayKey]!;
      if (rows.length == 1) {
        rows.first.clear();
        return;
      }
      final removed = rows.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _openCopyDialog(String sourceDayKey, String label) async {
    final Map<String, bool> selectedDays = {
      for (final day in _dayConfigs)
        if (day.key != sourceDayKey) day.key: false
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Copiar programación de $label'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _dayConfigs.where((day) => day.key != sourceDayKey).map((day) {
                    return CheckboxListTile(
                      title: Text(day.label),
                      value: selectedDays[day.key],
                      onChanged: (val) {
                        setDialogState(() => selectedDays[day.key] = val ?? false);
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Copiar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _copyToSpecificDays(sourceDayKey, selectedDays);
    }
  }

  void _copyToSpecificDays(String sourceDayKey, Map<String, bool> selectedDays) {
    setState(() {
      final sourceRows = _rowsByDay[sourceDayKey] ?? const <_RowControllers>[];
      final payload = sourceRows
          .map(
            (row) => {
              'h': row.horarioEncoded,
              'p': row.pCtrl.text,
              't': row.tCtrl.text,
            },
          )
          .toList();

      for (final day in _dayConfigs) {
        if (day.key == sourceDayKey || selectedDays[day.key] != true) continue;
        _disposeRows(_rowsByDay[day.key]!);
        _rowsByDay[day.key] = payload
            .map(
              (r) => _RowControllers.fromHorarioString(
                h: r['h'] ?? '',
                p: r['p'] ?? '',
                t: r['t'] ?? '',
              ),
            )
            .toList();
        if (_rowsByDay[day.key]!.isEmpty) {
          _rowsByDay[day.key] = <_RowControllers>[_RowControllers.empty()];
        }
      }
    });
  }

  Future<void> _pickTime(BuildContext context, _RowControllers row, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? row.startTime : row.endTime) ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        row.startTime = picked;
      } else {
        row.endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final targetId = _targetId;
    if (targetId == null) return;
    setState(() => _saving = true);
    try {
      final tenant = TenantScope.require(
        appId: widget.appId,
        ownerEmail: widget.ownerEmail,
      );
      await widget.repository.saveProgramacionTexto(
            ownerEmail: tenant.ownerEmail,
            appId: tenant.appId,
            targetId: targetId,
            lunes: _toJsonRows(EmisoraFields.lunes),
            martes: _toJsonRows(EmisoraFields.martes),
            miercoles: _toJsonRows(EmisoraFields.miercoles),
            jueves: _toJsonRows(EmisoraFields.jueves),
            viernes: _toJsonRows(EmisoraFields.viernes),
            sabado: _toJsonRows(EmisoraFields.sabado),
            domingo: _toJsonRows(EmisoraFields.domingo),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programación actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final rows in _rowsByDay.values) {
      _disposeRows(rows);
    }
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTableHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40), // Spacing for drag handle
          Expanded(
            flex: 1,
            child: Text('HORA INICIO', style: _headerStyle(context)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Text('HORA FIN', style: _headerStyle(context)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Text('PROGRAMA', style: _headerStyle(context)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Text('CATEGORÍA / DJ', style: _headerStyle(context)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text('ACCIONES', style: _headerStyle(context), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
  }

  Widget _buildRowItem(BuildContext context, _RowControllers row, int index, String dayKey) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      // Fallback for mobile: standard stacked form fields
      return Padding(
        key: ObjectKey(row),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_indicator, color: scheme.onSurfaceVariant),
                  ),
                  IconButton(
                    onPressed: () => _removeRow(dayKey, index),
                    icon: Icon(Icons.close, size: 20, color: scheme.error),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerField(
                      label: 'Inicio',
                      value: row.startTime,
                      onTap: () => _pickTime(context, row, isStart: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TimePickerField(
                      label: 'Fin',
                      value: row.endTime,
                      onTap: () => _pickTime(context, row, isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _MinimalTextField(
                controller: row.pCtrl,
                hintText: 'Nombre del Programa',
              ),
              const SizedBox(height: 8),
              _MinimalTextField(
                controller: row.tCtrl,
                hintText: 'Categoría / DJ',
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      key: ObjectKey(row),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Container(
                width: 40,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: scheme.primary), // Dot indicator
                    const SizedBox(width: 8),
                    Icon(Icons.drag_indicator, size: 20, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: _TimePickerField(
              label: '',
              value: row.startTime,
              onTap: () => _pickTime(context, row, isStart: true),
              isDense: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _TimePickerField(
              label: '',
              value: row.endTime,
              onTap: () => _pickTime(context, row, isStart: false),
              isDense: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: _MinimalTextField(
              controller: row.pCtrl,
              hintText: 'Espacio disponible',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: _MinimalTextField(
              controller: row.tCtrl,
              hintText: '--',
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 80,
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => _removeRow(dayKey, index),
              tooltip: 'Eliminar fila',
              icon: Icon(Icons.delete_outline, size: 20, color: scheme.onSurfaceVariant),
              hoverColor: scheme.errorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabContent(BuildContext context, _DayConfig day) {
    final rows = _rowsByDay[day.key]!;
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isMobile) _buildTableHeader(context),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                shadowColor: scheme.shadow.withValues(alpha: 0.4),
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = rows.removeAt(oldIndex);
                rows.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              return _buildRowItem(context, rows[index], index, day.key);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (!_targetLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_targets.isEmpty) {
      return const Center(child: Text('No hay radios ni streamings para programar.'));
    }
    _targetId ??= _targets.first.id;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey<String>(_targetId!),
      stream: widget.repository.watchProgramacionDoc(
        targetId: _targetId!,
        appId: widget.appId,
      ),
      builder: (context, snap) {
        final doc = snap.data;
        if (doc != null && doc.id == _targetId!) {
          _applyProgramacionSnapshotIfCurrent(doc);
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              backgroundColor: scheme.surface,
              surfaceTintColor: scheme.surfaceTint,
              elevation: 2,
              shadowColor: scheme.shadow.withValues(alpha: 0.1),
              title: Text(
                'Gestión de Programación',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Guardando…' : 'Guardar Cambios'),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 24, isMobile ? 12 : 24, 60),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header and Dropdown Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Parrilla de Programación',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Administra los bloques de emisión semanal para radio y feeds de video en vivo.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isMobile)
                              SizedBox(
                                width: 250,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey<String>(_targetId!),
                                  initialValue: _targetId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: scheme.outlineVariant),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: scheme.outlineVariant),
                                    ),
                                    filled: true,
                                    fillColor: scheme.surfaceContainerLow,
                                  ),
                                  items: _targets
                                      .map(
                                        (t) => DropdownMenuItem<String>(
                                          value: t.id,
                                          child: Text('${t.label} (${t.type})', overflow: TextOverflow.ellipsis),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() {
                                      _targetId = v;
                                      _loadedDocId = null;
                                      _lastAppliedSnapshotFromCache = null;
                                      _pendingApplyForDocId = null;
                                      _resetRowsToEmpty();
                                    });
                                    _saveLastTarget(v);
                                  },
                                ),
                              ),
                          ],
                        ),
                        if (isMobile) const SizedBox(height: 16),
                        if (isMobile)
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>(_targetId!),
                            initialValue: _targetId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _targets
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text('${t.label} (${t.type})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _targetId = v;
                                _loadedDocId = null;
                                _lastAppliedSnapshotFromCache = null;
                                _pendingApplyForDocId = null;
                                _resetRowsToEmpty();
                              });
                              _saveLastTarget(v);
                            },
                          ),
                        const SizedBox(height: 24),

                        // Main Schedule Container
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top actions of the table
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: TabBar(
                                        controller: _tabController,
                                        isScrollable: true,
                                        dividerColor: Colors.transparent,
                                        indicatorSize: TabBarIndicatorSize.label,
                                        indicator: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: scheme.primary, width: 3),
                                          ),
                                        ),
                                        labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        unselectedLabelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        tabs: _dayConfigs.map((d) => Tab(text: d.label)).toList(),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            final currentDay = _dayConfigs[_tabController.index];
                                            _openCopyDialog(currentDay.key, currentDay.label);
                                          },
                                          icon: Icon(Icons.copy_all, size: 18, color: scheme.primary),
                                          label: const Text('Copiar a otros días'),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          onPressed: () {
                                            final currentDay = _dayConfigs[_tabController.index];
                                            _addRow(currentDay.key);
                                          },
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Añadir Slot'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: scheme.primaryContainer,
                                            foregroundColor: scheme.onPrimaryContainer,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                              // Tab Bar View content
                              AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, child) {
                                  // TabBarView doesn't shrinkwrap well inside a scrollview, so we use an IndexedStack logic
                                  final currentDay = _dayConfigs[_tabController.index];
                                  return _buildDayTabContent(context, currentDay);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TargetOption {
  const _TargetOption({
    required this.id,
    required this.label,
    required this.type,
  });

  final String id;
  final String label;
  final String type;
}

class _DayConfig {
  const _DayConfig({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class _RowControllers {
  _RowControllers({
    this.startTime,
    this.endTime,
    required String p,
    required String t,
  })  : pCtrl = TextEditingController(text: p),
        tCtrl = TextEditingController(text: t);

  factory _RowControllers.empty() => _RowControllers(p: '', t: '');

  factory _RowControllers.fromHorarioString({
    required String h,
    required String p,
    required String t,
  }) {
    final parsed = ProgramacionHorarioFormat.parse(h);
    return _RowControllers(
      startTime: parsed.start,
      endTime: parsed.end,
      p: p,
      t: t,
    );
  }

  TimeOfDay? startTime;
  TimeOfDay? endTime;
  final TextEditingController pCtrl;
  final TextEditingController tCtrl;

  String get horarioEncoded => ProgramacionHorarioFormat.build(
        start: startTime,
        end: endTime,
      );

  void clear() {
    startTime = null;
    endTime = null;
    pCtrl.clear();
    tCtrl.clear();
  }

  void dispose() {
    pCtrl.dispose();
    tCtrl.dispose();
  }
}

// Minimal TextField for the data rows
class _MinimalTextField extends StatelessWidget {
  const _MinimalTextField({
    required this.controller,
    required this.hintText,
    this.fontWeight,
  });

  final TextEditingController controller;
  final String hintText;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: fontWeight,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.transparent,
        hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.isDense = false,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = value != null ? ProgramacionHorarioFormat.format(value!) : null;

    if (isDense) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (display == null) Icon(Icons.access_time, size: 16, color: scheme.onSurfaceVariant),
              if (display == null) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  display ?? 'Fijar hora',
                  overflow: TextOverflow.ellipsis,
                  style: display != null
                      ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                      : Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time_outlined, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          display ?? 'Seleccionar',
          style: display != null
              ? Theme.of(context).textTheme.bodyMedium
              : Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
