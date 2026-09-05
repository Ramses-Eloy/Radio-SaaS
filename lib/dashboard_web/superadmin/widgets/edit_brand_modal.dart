import 'package:flutter/material.dart';
import '../services/superadmin_repository.dart';

/// Modal para editar los datos de una marca existente.
/// Permite cambiar nombre comercial, ownerEmail, estado (activo/suspendido)
/// y enviar reset de contraseña.
class EditBrandModal extends StatefulWidget {
  const EditBrandModal({
    super.key,
    required this.marca,
    required this.repository,
  });

  final MarcaRecord marca;
  final SuperAdminRepository repository;

  @override
  State<EditBrandModal> createState() => _EditBrandModalState();
}

class _EditBrandModalState extends State<EditBrandModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late bool _active;
  bool _saving = false;
  bool _sendingReset = false;
  bool _confirmingDelete = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.marca.nombreGrupo);
    _emailController = TextEditingController(text: widget.marca.ownerEmail);
    _passwordController = TextEditingController();
    _active = widget.marca.active;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      await widget.repository.updateMarcaDetails(
        appId: widget.marca.appId,
        currentEmail: widget.marca.ownerEmail,
        nombreGrupo: _nombreController.text.trim(),
        newOwnerEmail: _emailController.text.trim() != widget.marca.ownerEmail ? _emailController.text.trim() : null,
        newPassword: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
        active: _active,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marca "${_nombreController.text.trim()}" actualizada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'El correo del propietario no es válido.');
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await widget.repository.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enlace de restablecimiento enviado a $email'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al enviar reset: $e');
    }
    if (mounted) setState(() => _sendingReset = false);
  }

  Future<void> _deleteMarca() async {
    if (!_confirmingDelete) {
      setState(() => _confirmingDelete = true);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.deleteMarca(widget.marca.appId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marca "${widget.marca.nombreGrupo}" eliminada permanentemente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                              'Editar Datos de Marca',
                              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Modifica los datos principales o restablece la contraseña de acceso.',
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
                  // ─── APP ID (no editable) ───
                  Text('Identificador Técnico (appId)', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: widget.marca.appId,
                    enabled: false,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixIcon: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No editable',
                          style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ─── NOMBRE COMERCIAL ───
                  Text('Nombre Comercial / Grupo', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(isDense: true),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  // ─── OWNER EMAIL ───
                  Text('Correo del Propietario (Owner Email)', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(isDense: true),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (!v.contains('@')) return 'Email inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // ─── RESET PASSWORD ENLACE ───
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _sendingReset ? null : _sendPasswordReset,
                      icon: _sendingReset
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset, size: 18),
                      label: const Text('O enviar enlace de restablecimiento al correo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ─── NUEVA CONTRASEÑA DIRECTA ───
                  Text('Nueva Contraseña (Opcional)', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Déjalo en blanco para no cambiar',
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // ─── ESTADO ───
                  Card(
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      title: const Text('Estado del Servicio'),
                      subtitle: Text(
                        _active
                            ? 'Activo — La app funciona normalmente.'
                            : 'Suspendido — La app mostrará mensaje de mantenimiento temporal.',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
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
                    children: [
                      // Danger action
                      TextButton.icon(
                        onPressed: _saving ? null : _deleteMarca,
                        icon: Icon(
                          _confirmingDelete ? Icons.warning_amber : Icons.delete_outline,
                          color: scheme.error,
                          size: 18,
                        ),
                        label: Text(
                          _confirmingDelete ? '¿Confirmar eliminación?' : 'Eliminar Marca',
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                      const Spacer(),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
