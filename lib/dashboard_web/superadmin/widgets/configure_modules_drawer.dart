import 'package:flutter/material.dart';
import '../../../models/app_features.dart';
import '../services/superadmin_repository.dart';

/// Drawer lateral (Dialog) para configurar los módulos activos de una marca.
/// Incluye presets rápidos (Solo Player / Full Suite) y 5 switches independientes.
class ConfigureModulesDrawer extends StatefulWidget {
  const ConfigureModulesDrawer({
    super.key,
    required this.marca,
    required this.repository,
  });

  final MarcaRecord marca;
  final SuperAdminRepository repository;

  @override
  State<ConfigureModulesDrawer> createState() => _ConfigureModulesDrawerState();
}

class _ConfigureModulesDrawerState extends State<ConfigureModulesDrawer> {
  late AppFeatures _features;
  bool _saving = false;
  String? _activePreset;

  @override
  void initState() {
    super.initState();
    _features = widget.marca.features;
    _syncPresetLabel();
  }

  void _syncPresetLabel() {
    if (_features == AppFeatures.presetSoloPlayer()) {
      _activePreset = 'Solo Player';
    } else if (_features == AppFeatures.presetFullSuite()) {
      _activePreset = 'Full Suite';
    } else {
      _activePreset = null; // Personalizado
    }
  }

  void _applyPreset(AppFeatures preset, String label) {
    setState(() {
      _features = preset;
      _activePreset = label;
    });
  }

  void _updateFeature(AppFeatures updated) {
    setState(() {
      _features = updated;
      _syncPresetLabel();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.repository.updateMarcaFeatures(widget.marca.appId, _features);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Módulos actualizados para ${widget.marca.nombreGrupo}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── HEADER ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurar Módulos',
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            children: [
                              TextSpan(
                                text: widget.marca.nombreGrupo,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '  (appId: ${widget.marca.appId})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ─── PLAN PRESETS ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAN PRESETS',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PresetCard(
                          icon: Icons.radio,
                          label: 'Solo Player',
                          selected: _activePreset == 'Solo Player',
                          scheme: scheme,
                          onTap: () => _applyPreset(AppFeatures.presetSoloPlayer(), 'Solo Player'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PresetCard(
                          icon: Icons.diamond,
                          label: 'Full Suite',
                          selected: _activePreset == 'Full Suite',
                          scheme: scheme,
                          onTap: () => _applyPreset(AppFeatures.presetFullSuite(), 'Full Suite'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ─── MODULE CONFIGURATION ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'MODULE CONFIGURATION',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _ModuleSwitch(
                    icon: Icons.radio,
                    title: 'Radio Streaming',
                    subtitle: 'Core audio player module',
                    value: _features.enableRadio,
                    onChanged: (v) => _updateFeature(_features.copyWith(enableRadio: v)),
                    scheme: scheme,
                  ),
                  const Divider(height: 1),
                  _ModuleSwitch(
                    icon: Icons.live_tv,
                    title: 'TV / Video Stream',
                    subtitle: 'Video player integration',
                    value: _features.enableTv,
                    onChanged: (v) => _updateFeature(_features.copyWith(enableTv: v)),
                    scheme: scheme,
                  ),
                  const Divider(height: 1),
                  _ModuleSwitch(
                    icon: Icons.calendar_month,
                    title: 'Programming Grid',
                    subtitle: 'Schedule & show management',
                    value: _features.enableSchedule,
                    onChanged: (v) => _updateFeature(_features.copyWith(enableSchedule: v)),
                    scheme: scheme,
                  ),
                  const Divider(height: 1),
                  _ModuleSwitch(
                    icon: Icons.settings,
                    title: 'Advanced Settings',
                    subtitle: 'Client self-service config',
                    value: _features.enableSettings,
                    onChanged: (v) => _updateFeature(_features.copyWith(enableSettings: v)),
                    scheme: scheme,
                  ),
                  const Divider(height: 1),
                  _ModuleSwitch(
                    icon: Icons.cell_tower,
                    title: 'Multi-Emisora',
                    subtitle: 'Network selector UI',
                    value: _features.enableMultiStation,
                    onChanged: (v) => _updateFeature(_features.copyWith(enableMultiStation: v)),
                    scheme: scheme,
                  ),
                ],
              ),
            ),
            // ─── FOOTER ───
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar Cambios'),
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

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleSwitch extends StatelessWidget {
  const _ModuleSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.scheme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        secondary: Icon(
          icon,
          color: value ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: value ? null : scheme.onSurfaceVariant,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
