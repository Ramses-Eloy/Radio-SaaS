import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/models/app_info.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/screens/app_settings_workspace.dart';
import 'package:radio_whitelabel/dashboard_web/screens/emisora_workspace.dart';
import 'package:radio_whitelabel/dashboard_web/screens/estadisticas_workspace.dart';
import 'package:radio_whitelabel/dashboard_web/screens/programacion_workspace.dart';
import 'package:radio_whitelabel/dashboard_web/screens/streaming_workspace.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/theme/theme_controller.dart';
import 'package:radio_whitelabel/dashboard_web/utils/color_hex.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/brand_identity_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.dataStore,
  });

  final EmisoraRepository repository;
  final ClientDataStore dataStore;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _sectionIndex = 0; // 0 = Ajustes, 1 = Radios, 2 = Streamings, 3 = Programacion, 4 = Estadisticas
  String? _selectedRadioId;
  String? _selectedStreamingId;

  Future<void> _signOut() {
    widget.dataStore.clear();
    return FirebaseAuth.instance.signOut();
  }

  void _selectRadio(String? id) => setState(() => _selectedRadioId = id);
  void _selectStreaming(String? id) => setState(() => _selectedStreamingId = id);

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      widget.dataStore.ensureLoaded(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final ownerEmail = (user.email ?? '').trim().toLowerCase();

    final scheme = Theme.of(context).colorScheme;

    if (ownerEmail.isEmpty) {
      return Scaffold(body: _MissingEmailState(scheme: scheme));
    }

    return ListenableBuilder(
      listenable: widget.dataStore,
      builder: (context, _) {
        final store = widget.dataStore;
        if (store.initializing && store.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (store.error != null && store.data == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudieron cargar los datos. ${store.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => store.ensureLoaded(ownerEmail),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = store.data;
        if (data == null) {
          return Scaffold(
            body: Center(
              child: FilledButton.icon(
                onPressed: () => store.ensureLoaded(ownerEmail),
                icon: const Icon(Icons.refresh),
                label: const Text('Cargar datos'),
              ),
            ),
          );
        }

        final prefix = store.currentAppId ?? data.prefix;
        final info = data.info;
        final radios = data.radios;
        final streamings = data.streamings;
        final unknown = data.unknownIds;

        if (_selectedRadioId != null && !radios.any((r) => r.id == _selectedRadioId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedRadioId = null);
          });
        }
        if (_sectionIndex == 1 && radios.length == 1 && _selectedRadioId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedRadioId = radios.first.id);
          });
        }

        if (_selectedStreamingId != null && !streamings.any((s) => s.id == _selectedStreamingId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedStreamingId = null);
          });
        }
        if (_sectionIndex == 2 && streamings.length == 1 && _selectedStreamingId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedStreamingId = streamings.first.id);
          });
        }

        void onSectionChanged(int i) {
          final enteringStats = i == 4 && _sectionIndex != 4;
          setState(() => _sectionIndex = i);
          if (enteringStats) {
            store.refreshMetricsFromFirestore(ownerEmail);
          }
        }

        final sidebar = _Sidebar(
          userEmail: user.email ?? 'Usuario',
          dataStore: store,
          prefix: prefix,
          sectionIndex: _sectionIndex,
          onSectionChanged: onSectionChanged,
          radios: radios,
          selectedRadioId: _selectedRadioId,
          onSelectRadio: _selectRadio,
          streamings: streamings,
          selectedStreamingId: _selectedStreamingId,
          onSelectStreaming: _selectStreaming,
          onSignOut: _signOut,
        );

        final content = Container(
          color: scheme.surface,
          child: _Body(
            sectionIndex: _sectionIndex,
            ownerEmail: ownerEmail,
            writeOwnerEmail: store.writeOwnerEmail ?? ownerEmail,
            prefix: prefix,
            info: info,
            radios: radios,
            selectedRadioId: _selectedRadioId,
            onSelectRadio: _selectRadio,
            streamings: streamings,
            selectedStreamingId: _selectedStreamingId,
            onSelectStreaming: _selectStreaming,
            repository: widget.repository,
            dataStore: widget.dataStore,
            scheme: scheme,
            unknownIds: unknown,
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 960;
            if (isMobile) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    _sectionIndex == 0
                        ? 'Opciones Generales'
                        : _sectionIndex == 1
                            ? 'Radios'
                            : _sectionIndex == 2
                                ? 'Streamings TV'
                                : _sectionIndex == 3
                                    ? 'Gestión de Programación'
                                    : 'Estadísticas',
                  ),
                ),
                drawer: Drawer(
                  child: SafeArea(child: sidebar),
                ),
                body: content,
              );
            }

            return Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sidebar,
                  Expanded(child: content),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NoAssignmentState extends StatelessWidget {
  const _NoAssignmentState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radio_outlined, size: 56, color: scheme.primary.withValues(alpha: 0.75)),
                const SizedBox(height: 16),
                Text(
                  'Aún no tiene una radio asignada',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Su cuenta está activa, pero aún no tiene emisoras asignadas. '
                  'Contacte al administrador de la plataforma para activar su radio.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.sectionIndex,
    required this.ownerEmail,
    required this.writeOwnerEmail,
    required this.prefix,
    required this.info,
    required this.radios,
    required this.selectedRadioId,
    required this.onSelectRadio,
    required this.streamings,
    required this.selectedStreamingId,
    required this.onSelectStreaming,
    required this.repository,
    required this.dataStore,
    required this.scheme,
    required this.unknownIds,
  });

  final int sectionIndex;
  final String ownerEmail;
  final String writeOwnerEmail;
  final String? prefix;
  final AppInfo? info;
  final List<Emisora> radios;
  final String? selectedRadioId;
  final ValueChanged<String?> onSelectRadio;
  final List<Streaming> streamings;
  final String? selectedStreamingId;
  final ValueChanged<String?> onSelectStreaming;
  final EmisoraRepository repository;
  final ClientDataStore dataStore;
  final ColorScheme scheme;
  final List<String> unknownIds;

  Emisora? _selectedRadio() {
    if (radios.isEmpty) return null;
    if (radios.length == 1) return radios.first;
    if (selectedRadioId == null) return null;
    final found = radios.where((r) => r.id == selectedRadioId);
    return found.isEmpty ? null : found.first;
  }

  Streaming? _selectedStreaming() {
    if (streamings.isEmpty) return null;
    if (streamings.length == 1) return streamings.first;
    if (selectedStreamingId == null) return null;
    final found = streamings.where((s) => s.id == selectedStreamingId);
    return found.isEmpty ? null : found.first;
  }

  @override
  Widget build(BuildContext context) {
    if (prefix == null) {
      return _NoPrefixState(scheme: scheme);
    }
    if (info == null && radios.isEmpty && streamings.isEmpty) {
      return _NoAssignmentState(scheme: scheme);
    }

    Widget content;
    if (sectionIndex == 0) {
      content = info == null
          ? _MissingInfoState(prefix: prefix!, scheme: scheme)
          : AppSettingsWorkspace(
              key: ValueKey(info!.id),
              info: info!,
              appId: prefix!,
              repository: repository,
              ownerEmail: ownerEmail,
              dataStore: dataStore,
            );
    } else if (sectionIndex == 1) {
      final selected = _selectedRadio();
      content = radios.isEmpty
          ? _EmptySectionState(
              icon: Icons.radio_outlined,
              title: 'Sin radios de audio',
              message:
                  'Aún no tiene emisoras de audio asignadas. Contacte al administrador si necesita activar una.',
              scheme: scheme,
            )
          : selected == null
              ? _PickRadioState(scheme: scheme)
              : EmisoraWorkspace(
                  key: ValueKey(selected.id),
                  emisora: selected,
                  appId: prefix!,
                  repository: repository,
                  ownerEmail: ownerEmail,
                  dataStore: dataStore,
                );
    } else if (sectionIndex == 2) {
      final selected = _selectedStreaming();
      content = streamings.isEmpty
          ? _EmptySectionState(
              icon: Icons.live_tv_outlined,
              title: 'Sin streamings TV',
              message:
                  'Aún no tiene canales de TV en directo. Contacte al administrador si necesita activar uno.',
              scheme: scheme,
            )
          : selected == null
              ? _PickStreamingState(scheme: scheme)
              : StreamingWorkspace(
                  key: ValueKey(selected.id),
                  streaming: selected,
                  appId: prefix!,
                  repository: repository,
                  ownerEmail: ownerEmail,
                  dataStore: dataStore,
                );
    } else if (sectionIndex == 3) {
      content = ProgramacionWorkspace(
        repository: repository,
        ownerEmail: writeOwnerEmail,
        appId: prefix!,
        radios: radios,
        streamings: streamings,
      );
    } else {
      content = EstadisticasWorkspace(
        ownerEmail: ownerEmail,
        appId: prefix!,
        dataStore: dataStore,
      );
    }

    if (unknownIds.isEmpty) return content;

    return Column(
      children: [
        MaterialBanner(
          leading: const Icon(Icons.info_outline),
          content: Text('Hay contenido con formatos no reconocidos: ${unknownIds.join(', ')}. Contacte con soporte si persiste.'),
          actions: [
            TextButton(onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(), child: const Text('Ocultar')),
          ],
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.userEmail,
    required this.dataStore,
    required this.prefix,
    required this.sectionIndex,
    required this.onSectionChanged,
    required this.radios,
    required this.selectedRadioId,
    required this.onSelectRadio,
    required this.streamings,
    required this.selectedStreamingId,
    required this.onSelectStreaming,
    required this.onSignOut,
  });

  final String userEmail;
  final ClientDataStore dataStore;
  final String? prefix;
  final int sectionIndex;
  final ValueChanged<int> onSectionChanged;
  final List<Emisora> radios;
  final String? selectedRadioId;
  final ValueChanged<String?> onSelectRadio;
  final List<Streaming> streamings;
  final String? selectedStreamingId;
  final ValueChanged<String?> onSelectStreaming;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: 272,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (prefix != null)
              BrandIdentityHeader(
                dataStore: dataStore,
                userEmail: userEmail,
                compact: true,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.podcasts, color: scheme.primary, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dataStore.initializing ? 'Cargando…' : 'Panel',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            userEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: _NavList(sectionIndex: sectionIndex, onSectionChanged: onSectionChanged),
            ),
            if (sectionIndex == 1) ...[
              const Divider(height: 1),
              Expanded(
                child: radios.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        itemCount: radios.length,
                        itemBuilder: (context, i) {
                          final e = radios[i];
                          final isSel = selectedRadioId == e.id;
                          final brand = ColorHex.tryParse(e.colorHex);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: isSel ? scheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                leading: CircleAvatar(
                                  backgroundColor: brand ?? scheme.surfaceContainerHighest,
                                  foregroundColor: brand != null ? Colors.white : scheme.primary,
                                  child: Text(
                                    e.nombre.isNotEmpty ? e.nombre.substring(0, 1).toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(e.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 8),
                                    _Badge(label: 'AUDIO', color: scheme.secondaryContainer),
                                  ],
                                ),
                                selected: isSel,
                                onTap: () => onSelectRadio(e.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ] else if (sectionIndex == 2) ...[
              const Divider(height: 1),
              Expanded(
                child: streamings.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        itemCount: streamings.length,
                        itemBuilder: (context, i) {
                          final s = streamings[i];
                          final isSel = selectedStreamingId == s.id;
                          final brand = ColorHex.tryParse(s.colorHex);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: isSel ? scheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                leading: CircleAvatar(
                                  backgroundColor: brand ?? scheme.tertiaryContainer,
                                  foregroundColor: brand != null ? Colors.white : scheme.onTertiaryContainer,
                                  child: Text(
                                    s.nombre.isNotEmpty ? s.nombre.substring(0, 1).toUpperCase() : 'T',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(s.nombre, maxLines: 2, overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    _Badge(label: 'TV', color: scheme.tertiaryContainer),
                                  ],
                                ),
                                selected: isSel,
                                onTap: () => onSelectStreaming(s.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ] else ...[
              const Divider(height: 1),
              const SizedBox(height: 8),
            ],
            const Divider(height: 1),
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

class _NavList extends StatelessWidget {
  const _NavList({
    required this.sectionIndex,
    required this.onSectionChanged,
  });

  final int sectionIndex;
  final ValueChanged<int> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavItem(
          selected: sectionIndex == 0,
          icon: Icons.settings_outlined,
          label: 'Opciones Generales',
          onTap: () => onSectionChanged(0),
        ),
        const SizedBox(height: 4),
        _NavItem(
          selected: sectionIndex == 1,
          icon: Icons.radio_outlined,
          label: 'Radios',
          onTap: () => onSectionChanged(1),
        ),
        const SizedBox(height: 4),
        _NavItem(
          selected: sectionIndex == 2,
          icon: Icons.live_tv_outlined,
          label: 'Streamings TV',
          onTap: () => onSectionChanged(2),
        ),
        const SizedBox(height: 4),
        _NavItem(
          selected: sectionIndex == 3,
          icon: Icons.calendar_month_outlined,
          label: 'Gestión de Programación',
          onTap: () => onSectionChanged(3),
        ),
        const SizedBox(height: 4),
        _NavItem(
          selected: sectionIndex == 4,
          icon: Icons.bar_chart_outlined,
          label: 'Estadísticas',
          onTap: () => onSectionChanged(4),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon),
        title: Text(label),
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PickRadioState extends StatelessWidget {
  const _PickRadioState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 56, color: scheme.primary.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  'Seleccione una radio',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Elija una emisora en el menú de la izquierda para editarla.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickStreamingState extends StatelessWidget {
  const _PickStreamingState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 56, color: scheme.primary.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text(
                  'Seleccione un streaming',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Elija un canal en el menú de la izquierda para editarlo.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingInfoState extends StatelessWidget {
  const _MissingInfoState({required this.prefix, required this.scheme});

  final String prefix;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return _EmptySectionState(
      icon: Icons.settings_outlined,
      title: 'Sin opciones generales',
      message: 'No se encontró la configuración general de su marca. Contacte con soporte si el problema continúa.',
      scheme: scheme,
    );
  }
}

class _MissingEmailState extends StatelessWidget {
  const _MissingEmailState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return _EmptySectionState(
      icon: Icons.mail_outline,
      title: 'Sin correo en la sesión',
      message: 'La cuenta autenticada no tiene email disponible. Use un proveedor con email (password/Google).',
      scheme: scheme,
    );
  }
}

class _NoPrefixState extends StatelessWidget {
  const _NoPrefixState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return _EmptySectionState(
      icon: Icons.rule_folder_outlined,
      title: 'Sin marca asignada',
      message:
          'No hay ninguna marca vinculada a su correo electrónico. Contacte al administrador para activar su acceso.',
      scheme: scheme,
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({
    required this.icon,
    required this.title,
    required this.message,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final String message;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: scheme.primary.withValues(alpha: 0.75)),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
