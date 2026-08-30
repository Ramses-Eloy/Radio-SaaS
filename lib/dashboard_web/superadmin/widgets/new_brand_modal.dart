import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/app_features.dart';
import '../services/superadmin_repository.dart';

/// Modal para registrar una nueva marca / cliente en el SaaS.
/// Crea automáticamente: documento en `marcas/{appId}`, emisora inicial en
/// `emisoras` con todos los campos estándar, y usuario en Firebase Auth.
class NewBrandModal extends StatefulWidget {
  const NewBrandModal({super.key, required this.repository});

  final SuperAdminRepository repository;

  @override
  State<NewBrandModal> createState() => _NewBrandModalState();
}

class _NewBrandModalState extends State<NewBrandModal> {
  final _formKey = GlobalKey<FormState>();
  final _appIdController = TextEditingController();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedPlan = 'Solo Player';
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  AppFeatures get _planFeatures => _selectedPlan == 'Full Suite'
      ? AppFeatures.presetFullSuite()
      : AppFeatures.presetSoloPlayer();

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // Guardar las credenciales actuales del SuperAdmin para re-autenticarlo después
    final currentUser = FirebaseAuth.instance.currentUser;
    final superAdminEmail = currentUser?.email;

    final errorMsg = await widget.repository.createNewMarca(
      appId: _appIdController.text.trim().toLowerCase(),
      nombreGrupo: _nombreController.text.trim(),
      ownerEmail: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text,
      features: _planFeatures,
    );

    if (errorMsg != null) {
      if (mounted) setState(() { _saving = false; _error = errorMsg; });
      return;
    }

    // Si Firebase Auth creó un nuevo usuario y cambió la sesión activa,
    // re-autenticar al SuperAdmin no es posible sin su password.
    // La solución más robusta es verificar si la sesión cambió.
    final postUser = FirebaseAuth.instance.currentUser;
    if (postUser?.email != superAdminEmail) {
      // La sesión cambió al nuevo usuario creado — cerrar sesión del nuevo
      // y notificar que necesita volver a iniciar sesión.
      await FirebaseAuth.instance.signOut();
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marca "${_nombreController.text.trim()}" creada exitosamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── HEADER ───
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar Nueva Marca / Cliente',
                              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configura el identificador técnico y las credenciales iniciales del cliente.',
                              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ─── FORM FIELDS (2 columns) ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Identificador de Marca (appId)', style: textTheme.labelMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _appIdController,
                              decoration: InputDecoration(
                                hintText: 'radio_urbana',
                                helperText: 'Solo letras minúsculas, números y _',
                                helperMaxLines: 2,
                                isDense: true,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v.trim())) {
                                  return 'Solo letras minúsculas, números y _';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Text('Correo del Propietario', style: textTheme.labelMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'director@radiourbana.com',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                if (!v.contains('@')) return 'Email inválido';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Column 2
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nombre Comercial / Grupo', style: textTheme.labelMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nombreController,
                              decoration: InputDecoration(
                                hintText: 'Radio Urbana 101.5 FM',
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            Text('Contraseña Inicial', style: textTheme.labelMedium),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                if (v.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ─── PLAN SELECTOR ───
                  Text(
                    'Seleccionar Plan',
                    style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          title: 'Plan Básico: Solo Player',
                          description: 'Incluye reproductor de audio, redes sociales, banners publicitarios y telemetría.',
                          icon: Icons.radio,
                          selected: _selectedPlan == 'Solo Player',
                          scheme: scheme,
                          onTap: () => setState(() => _selectedPlan = 'Solo Player'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanCard(
                          title: 'Plan Full Suite',
                          description: 'Incluye todo lo anterior + Canales de Video/TV + Parrilla de Programación + Multi-Emisora.',
                          icon: Icons.diamond,
                          selected: _selectedPlan == 'Full Suite',
                          scheme: scheme,
                          onTap: () => setState(() => _selectedPlan = 'Full Suite'),
                        ),
                      ),
                    ],
                  ),
                  // ─── ERROR ───
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: scheme.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // ─── FOOTER ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _create,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Crear y Activar Marca'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: selected ? scheme.primary : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
