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

  @override
  void initState() {
    super.initState();
    _features = widget.marca.features;
  }

  void _updateFeature(AppFeatures updated) {
    setState(() {
      _features = updated;
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
                    icon: Icons.tv,
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
                    icon: Icons.podcasts,
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
