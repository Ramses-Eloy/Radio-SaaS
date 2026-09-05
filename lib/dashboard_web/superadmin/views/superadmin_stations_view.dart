import 'dart:async';
import 'package:flutter/material.dart';
import '../services/superadmin_repository.dart';
import '../widgets/new_station_modal.dart';

class SuperAdminStationsView extends StatefulWidget {
  final SuperAdminRepository repository;
  final List<MarcaRecord> marcas;

  const SuperAdminStationsView({
    super.key,
    required this.repository,
    required this.marcas,
  });

  @override
  State<SuperAdminStationsView> createState() => _SuperAdminStationsViewState();
}

class _SuperAdminStationsViewState extends State<SuperAdminStationsView> {
  String? _selectedAppId;
  
  StreamSubscription? _emisorasSub;
  StreamSubscription? _streamingsSub;

  List<SuperAdminEmisoraRecord> _emisoras = [];
  List<SuperAdminStreamingRecord> _streamings = [];

  bool _loading = false;

  @override
  void dispose() {
    _emisorasSub?.cancel();
    _streamingsSub?.cancel();
    super.dispose();
  }

  void _onMarcaSelected(String? appId) {
    setState(() {
      _selectedAppId = appId;
      _emisoras = [];
      _streamings = [];
      _loading = true;
    });

    _emisorasSub?.cancel();
    _streamingsSub?.cancel();

    if (appId != null) {
      _emisorasSub = widget.repository.streamEmisoras(appId).listen((list) {
        if (mounted) setState(() { _emisoras = list; _loading = false; });
      });
      _streamingsSub = widget.repository.streamStreamings(appId).listen((list) {
        if (mounted) setState(() { _streamings = list; });
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _openNewStationModal(bool isStreaming) {
    if (_selectedAppId == null) return;
    final marca = widget.marcas.firstWhere((m) => m.appId == _selectedAppId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewStationModal(
        appId: _selectedAppId!,
        ownerEmail: marca.ownerEmail,
        isStreaming: isStreaming,
        repository: widget.repository,
      ),
    );
  }

  Future<void> _deleteEmisora(SuperAdminEmisoraRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Radio'),
        content: Text('¿Estás seguro de que deseas eliminar "${record.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Eliminar')
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.deleteEmisora(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Radio eliminada')));
      }
    }
  }

  Future<void> _deleteStreaming(SuperAdminStreamingRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Streaming TV'),
        content: Text('¿Estás seguro de que deseas eliminar "${record.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Eliminar')
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.deleteStreaming(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Streaming eliminado')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── HEADER ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Text(
                'Gestión de Estaciones y Streams',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              // SELECTOR DE MARCA
              Container(
                width: 300,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Seleccionar Marca...'),
                    value: _selectedAppId,
                    items: widget.marcas.map((m) {
                      return DropdownMenuItem(
                        value: m.appId,
                        child: Text('${m.nombreGrupo} (${m.appId})'),
                      );
                    }).toList(),
                    onChanged: _onMarcaSelected,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ─── CONTENT ───
        Expanded(
          child: _selectedAppId == null
              ? Center(
                  child: Text(
                    'Selecciona una marca arriba para gestionar sus estaciones.',
                    style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // RADIOS
                          Expanded(
                            child: _StationCard(
                              title: 'Radios (Emisoras)',
                              icon: Icons.radio,
                              iconColor: const Color(0xFF38BDF8),
                              scheme: scheme,
                              textTheme: textTheme,
                              onAdd: () => _openNewStationModal(false),
                              child: _emisoras.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Center(child: Text('No hay radios registradas.')),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _emisoras.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (ctx, i) {
                                        final e = _emisoras[i];
                                        return ListTile(
                                          title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          subtitle: Text(e.urlAudio.isEmpty ? 'Sin URL' : e.urlAudio),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteEmisora(e),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // STREAMINGS
                          Expanded(
                            child: _StationCard(
                              title: 'Streamings (Video/TV)',
                              icon: Icons.tv,
                              iconColor: const Color(0xFF10B981),
                              scheme: scheme,
                              textTheme: textTheme,
                              onAdd: () => _openNewStationModal(true),
                              child: _streamings.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Center(child: Text('No hay streamings registrados.')),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _streamings.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (ctx, i) {
                                        final s = _streamings[i];
                                        return ListTile(
                                          title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          subtitle: Text(s.urlVideo.isEmpty ? 'Sin URL' : s.urlVideo),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _deleteStreaming(s),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.scheme,
    required this.textTheme,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
