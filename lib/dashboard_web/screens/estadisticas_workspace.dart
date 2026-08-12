import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/utils/color_hex.dart';
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
  String _timeFilter = '24H';

  String get _targetPrefKey => 'estadisticas.target.${widget.ownerEmail}.${widget.appId}';

  @override
  void initState() {
    super.initState();
    _loadLastTarget();
  }

  List<_TargetOption> _targets(List<Emisora> radios, List<Streaming> streamings) {
    final global = const _TargetOption(id: 'GLOBAL_ALL', label: 'Estadísticas Globales', type: 'Todas las emisoras');
    return [
      global,
      ...radios.map((r) => _TargetOption(id: r.id, label: r.nombre, type: 'Radio', entity: r)),
      ...streamings.map((s) => _TargetOption(id: s.id, label: s.nombre, type: 'Streaming', entity: s)),
    ];
  }

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
          _targetId = 'GLOBAL_ALL';
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

  void _exportCsv(BuildContext context) {
    // Datos simulados (pronto vendrán de Firebase)
    List<List<dynamic>> rows = [
      ['Estacion / Streaming', 'Oyentes Unicos', 'Duracion Promedio', 'Picos'],
      ['La Movida', 1200, '45 min', 1500],
      ['RetroMusic', 800, '30 min', 1000],
      ['Streaming Beta', 300, '20 min', 400],
    ];
    String csvData = csv.encode(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "reporte_estadisticas.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte Excel (CSV) generado')));
  }

  Future<void> _exportPdf(BuildContext context) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte de Estadisticas', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: const <List<String>>[
                  <String>['Estacion / Streaming', 'Oyentes Unicos', 'Duracion Promedio', 'Picos'],
                  <String>['La Movida', '1200', '45 min', '1500'],
                  <String>['RetroMusic', '800', '30 min', '1000'],
                  <String>['Streaming Beta', '300', '20 min', '400'],
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'reporte_estadisticas.pdf');
  }

  Widget _buildSparkline(Color color, List<double> data) {
    if (data.isEmpty) return const SizedBox();
    return SizedBox(
      height: 30,
      width: 60,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: data.reduce((a, b) => a > b ? a : b) * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, String change, bool positive, Color accent, List<double> trendData, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: positive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        positive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: positive ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        change,
                        style: TextStyle(
                          color: positive ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildSparkline(accent, trendData),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMainChart() {
    final scheme = Theme.of(context).colorScheme;
    // Mock Data for the chart
    final spots = const [
      FlSpot(0, 0),
      FlSpot(4, 0),
      FlSpot(8, 0),
      FlSpot(12, 0),
      FlSpot(16, 0),
      FlSpot(20, 0),
      FlSpot(24, 0),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tendencias de Tráfico',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Row(
                children: ['1H', '24H', '7D'].map((f) {
                  final sel = _timeFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () => setState(() => _timeFilter = f),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? scheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: sel ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _timeFilter == '24H' ? 6 : (_timeFilter == '7D' ? 1 : 10),
                      getTitlesWidget: (val, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${val.toInt()}${_timeFilter == '7D' ? 'd' : ':00'}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 50,
                      reservedSize: 42,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox.shrink();
                        return Text(
                          '${val.toInt()}k',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: scheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.5),
                          scheme.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGeoBar(String flag, String country, double percent, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              country,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${(percent * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGeolocationPanel() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución Geográfica (Top 5)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Basado en IPs concurrentes',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildGeoBar('🇵🇦', 'Panamá', 0.0, scheme.primary),
        ],
      ),
    );
  }

  Widget _buildActiveNodes(List<_TargetOption> targets) {
    final scheme = Theme.of(context).colorScheme;
    
    // Create an explicit global option
    final globalOption = targets.firstWhere((t) => t.id == 'GLOBAL_ALL');
    final specificTargets = targets.where((t) => t.id != 'GLOBAL_ALL').toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen Individual',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Icon(Icons.filter_list, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 16),
          _buildNodeCard(globalOption),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          ...specificTargets.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildNodeCard(t),
              )),
        ],
      ),
    );
  }

  Widget _buildNodeCard(_TargetOption t) {
    final scheme = Theme.of(context).colorScheme;
    final isSel = _targetId == t.id;
    final isGlobal = t.id == 'GLOBAL_ALL';
    
    // Mock values
    final listeners = '0';
    final baseColor = isGlobal ? scheme.primary : (t.entity is Emisora ? (ColorHex.tryParse((t.entity as Emisora).colorHex) ?? scheme.tertiary) : scheme.secondary);

    return InkWell(
      onTap: () {
        setState(() => _targetId = t.id);
        _saveLastTarget(t.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSel ? scheme.primaryContainer.withValues(alpha: 0.2) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.3),
            width: isSel ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.label,
                    style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Saludable',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Oyentes Activos', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(listeners, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataStore,
      builder: (context, _) {
        final store = widget.dataStore;
        final data = store.data;
        final scheme = Theme.of(context).colorScheme;
        final isMobile = MediaQuery.of(context).size.width < 1000;

        if (!_targetLoaded || data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final targets = _targets(data.radios, data.streamings);
        if (targets.isEmpty) {
          return const Scaffold(body: Center(child: Text('No hay radios ni streamings.')));
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: scheme.surface,
                surfaceTintColor: scheme.surfaceTint,
                elevation: 2,
                shadowColor: scheme.shadow.withValues(alpha: 0.1),
                title: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estadísticas Globales',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Rendimiento en tiempo real de tu red de emisoras.',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        )
                      ],
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        if (!isMobile)
                          PopupMenuButton<String>(
                            tooltip: 'Exportar Reporte',
                            offset: const Offset(0, 40),
                            onSelected: (val) {
                              if (val == 'csv') _exportCsv(context);
                              if (val == 'pdf') _exportPdf(context);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'csv',
                                child: Row(
                                  children: const [
                                    Icon(Icons.table_view, size: 20),
                                    SizedBox(width: 8),
                                    Text('Descargar Excel (CSV)'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'pdf',
                                child: Row(
                                  children: const [
                                    Icon(Icons.picture_as_pdf, size: 20),
                                    SizedBox(width: 8),
                                    Text('Descargar PDF'),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.file_download_outlined, size: 18, color: scheme.onPrimary),
                                  const SizedBox(width: 8),
                                  Text('Exportar Reporte', style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
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
                      child: Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isMobile ? 0 : 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // KPIs
                                Flex(
                                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                                  children: [
                                    _buildKPICard('Oyentes Activos', '0', '0%', true, scheme.primary, const [0, 0, 0, 0, 0, 0, 0], Icons.graphic_eq),
                                    SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 16 : 0),
                                    _buildKPICard('Reproducciones (24h)', '0', '0%', true, scheme.tertiary, const [0, 0, 0, 0, 0, 0, 0], Icons.play_circle_outline),
                                    SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 16 : 0),
                                    _buildKPICard('Clics Publicitarios', '0', '0%', false, scheme.secondary, const [0, 0, 0, 0, 0, 0, 0], Icons.campaign_outlined),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildMainChart(),
                                const SizedBox(height: 24),
                                _buildGeolocationPanel(),
                              ],
                            ),
                          ),
                          SizedBox(width: isMobile ? 0 : 24, height: isMobile ? 24 : 0),
                          // Sidebar / Active Nodes
                          if (!isMobile)
                            Expanded(
                              flex: 3,
                              child: _buildActiveNodes(targets),
                            )
                          else
                            _buildActiveNodes(targets),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    this.entity,
  });

  final String id;
  final String label;
  final String type;
  final dynamic entity;
}
