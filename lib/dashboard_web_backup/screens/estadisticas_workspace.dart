import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/metric_card.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/simple_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EstadisticasWorkspace extends StatefulWidget {
  const EstadisticasWorkspace({
    super.key,
    required this.ownerEmail,
    required this.appId,
    required this.dataStore,
  });

  final String ownerEmail;
  final String appId;
  final ClientDataStore dataStore;

  @override
  State<EstadisticasWorkspace> createState() => _EstadisticasWorkspaceState();
}

class _EstadisticasWorkspaceState extends State<EstadisticasWorkspace> {
  String? _targetId;
  bool _targetLoaded = false;

  String get _targetPrefKey => 'estadisticas.target.${widget.ownerEmail}.${widget.appId}';

  @override
  void initState() {
    super.initState();
    _loadLastTarget();
  }

  List<_TargetOption> _targets(List<Emisora> radios, List<Streaming> streamings) => [
        ...radios.map((r) => _TargetOption(id: r.id, label: r.nombre, type: 'Radio')),
        ...streamings.map((s) => _TargetOption(id: s.id, label: s.nombre, type: 'Streaming')),
      ];

  Future<void> _loadLastTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_targetPrefKey);
      if (!mounted) return;
      final data = widget.dataStore.data;
      final targets = data != null ? _targets(data.radios, data.streamings) : <_TargetOption>[];
      if (saved != null && targets.any((t) => t.id == saved)) {
        setState(() {
          _targetId = saved;
          _targetLoaded = true;
        });
      } else {
        setState(() {
          _targetId = targets.isNotEmpty ? targets.first.id : null;
          _targetLoaded = true;
        });
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

  _TargetOption? _selectedTarget(List<_TargetOption> targets) {
    final id = _targetId;
    if (id == null) return null;
    for (final t in targets) {
      if (t.id == id) return t;
    }
    return null;
  }

  Emisora? _radioFor(String id, List<Emisora> radios) {
    for (final r in radios) {
      if (r.id == id) return r;
    }
    return null;
  }

  Streaming? _streamingFor(String id, List<Streaming> streamings) {
    for (final s in streamings) {
      if (s.id == id) return s;
    }
    return null;
  }

  String _updatedLabel(DateTime? t) {
    if (t == null) {
      return 'Las métricas se actualizan desde la app móvil. Usa «Actualizar métricas» para traer los últimos valores.';
    }
    final local =
        '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return 'Última actualización de métricas: $local';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataStore,
      builder: (context, _) {
        final store = widget.dataStore;
        final data = store.data;
        final scheme = Theme.of(context).colorScheme;
        final isMobile = MediaQuery.of(context).size.width < 700;

        if (!_targetLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data == null) {
          return const Center(child: Text('Sin datos cargados.'));
        }

        final radios = data.radios;
        final streamings = data.streamings;
        final targets = _targets(radios, streamings);

        if (targets.isEmpty) {
          return const Center(child: Text('No hay radios ni streamings para consultar estadísticas.'));
        }

        if (_targetId != null && !targets.any((t) => t.id == _targetId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _targetId = targets.first.id);
          });
        }
        _targetId ??= targets.first.id;

        final target = _selectedTarget(targets)!;
        final radio = _radioFor(target.id, radios);
        final streaming = _streamingFor(target.id, streamings);
        final isRadio = radio != null;

        final currentListeners = radio?.currentListeners ?? 0;
        final adClicks = radio?.adClicks ?? 0;
        final playCount = radio?.playCount ?? streaming?.playCount ?? 0;
        final refMax = isRadio
            ? [currentListeners, adClicks, playCount, 1].reduce((a, b) => a > b ? a : b)
            : [playCount, 1].reduce((a, b) => a > b ? a : b);

        final totalRadiosPlay = radios.fold<int>(0, (sum, r) => sum + r.playCount);
        final totalStreamingsPlay = streamings.fold<int>(0, (sum, s) => sum + s.playCount);
        final totalListeners = radios.fold<int>(0, (sum, r) => sum + r.currentListeners);
        final totalAdClicks = radios.fold<int>(0, (sum, r) => sum + r.adClicks);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 16, isMobile ? 12 : 24, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estadísticas',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Consulta el rendimiento de tus emisoras y canales.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: store.refreshingMetrics
                            ? null
                            : () => store.refreshMetricsFromFirestore(widget.ownerEmail),
                        icon: store.refreshingMetrics
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(store.refreshingMetrics ? 'Actualizando…' : 'Actualizar métricas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _updatedLabel(store.metricsSyncedAt ?? store.lastSyncedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Filtro por señal', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>(_targetId!),
                            initialValue: _targetId,
                            items: targets
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text('${t.label} (${t.type})'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _targetId = v);
                              _saveLastTarget(v);
                            },
                            decoration: const InputDecoration(labelText: 'Emisora / streaming'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen — ${target.label}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isRadio) ...[
                    const SizedBox(height: 12),
                    MetricCard(
                      title: 'Oyentes actuales',
                      value: '$currentListeners',
                      icon: Icons.groups_2_outlined,
                      subtitle: 'Personas escuchando ahora',
                      accent: scheme.tertiary,
                    ),
                    const SizedBox(height: 12),
                    MetricCard(
                      title: 'Clics en publicidad',
                      value: '$adClicks',
                      icon: Icons.ads_click,
                      subtitle: 'Interacciones con anuncios',
                      accent: scheme.secondary,
                    ),
                  ],
                  const SizedBox(height: 12),
                  MetricCard(
                    title: 'Eventos Play',
                    value: '$playCount',
                    icon: Icons.play_circle_outline,
                    subtitle: 'Reproducciones registradas',
                    accent: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comparativa rápida',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          if (isRadio) ...[
                            SimpleBar(
                              label: 'Oyentes actuales',
                              value: currentListeners,
                              max: refMax,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(height: 20),
                            SimpleBar(
                              label: 'Clics en publicidad',
                              value: adClicks,
                              max: refMax,
                              color: scheme.secondary,
                            ),
                            const SizedBox(height: 20),
                          ],
                          SimpleBar(
                            label: 'Eventos Play',
                            value: playCount,
                            max: refMax,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Totales de la cuenta (datos en caché)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  MetricCard(
                    title: 'Play — todas las radios',
                    value: '$totalRadiosPlay',
                    icon: Icons.radio_outlined,
                    subtitle: '${radios.length} emisora(s)',
                    accent: scheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  MetricCard(
                    title: 'Play — todos los streamings',
                    value: '$totalStreamingsPlay',
                    icon: Icons.live_tv_outlined,
                    subtitle: '${streamings.length} canal(es)',
                    accent: scheme.tertiary,
                  ),
                  if (radios.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    MetricCard(
                      title: 'Oyentes — todas las radios',
                      value: '$totalListeners',
                      icon: Icons.groups_2_outlined,
                      subtitle: 'Total de oyentes en todas las emisoras',
                      accent: scheme.tertiary,
                    ),
                    const SizedBox(height: 12),
                    MetricCard(
                      title: 'Clics publicidad — todas las radios',
                      value: '$totalAdClicks',
                      icon: Icons.ads_click,
                      subtitle: 'Total de clics en anuncios',
                      accent: scheme.secondary,
                    ),
                  ],
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
