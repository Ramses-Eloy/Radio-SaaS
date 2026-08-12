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

class _ProgramacionWorkspaceState extends State<ProgramacionWorkspace> {
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

  String get _targetPrefKey => 'programacion.target.${widget.ownerEmail}.${widget.appId}';

  List<_TargetOption> get _targets => [
        ...widget.radios
            .where((r) => r.mostrarProgramacion)
            .map((r) => _TargetOption(id: r.id, label: r.nombre, type: 'Radio')),
      ];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Widget _buildDaySection(BuildContext context, _DayConfig day) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _rowsByDay[day.key]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Programación ${day.label}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCopyDialog(day.key, day.label),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copiar a otros días'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Arrastra las filas para reordenar la programación.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: rows.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = rows.removeAt(oldIndex);
                  rows.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final row = rows[index];
                return Padding(
                  key: ObjectKey(row),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 6),
                          child: Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _TimePickerField(
                                label: 'Hora de Inicio',
                                value: row.startTime,
                                onTap: () => _pickTime(context, row, isStart: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TimePickerField(
                                label: 'Hora de Fin',
                                value: row.endTime,
                                onTap: () => _pickTime(context, row, isStart: false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: row.pCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Programa',
                            hintText: 'SALUD Y VIDA',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: row.tCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Categoría/DJ',
                            hintText: 'VARIADO',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _removeRow(day.key, index),
                        tooltip: 'Eliminar fila',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 22,
                          color: scheme.onError,
                          semanticLabel: 'Eliminar fila',
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          minimumSize: const Size(40, 40),
                          padding: const EdgeInsets.all(6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _addRow(day.key),
                icon: const Icon(Icons.add),
                label: const Text('Añadir Fila'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;

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

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 16, isMobile ? 12 : 24, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gestión de Programación',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Administra la parrilla de horarios de tus estaciones.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selector de señal', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>(_targetId!),
                            initialValue: _targetId,
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
                            decoration: const InputDecoration(labelText: 'Señal'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._dayConfigs.map((day) => _buildDaySection(context, day)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Guardar Todo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = value != null ? ProgramacionHorarioFormat.format(value!) : null;

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
