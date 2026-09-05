import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/app_features.dart';
import '../services/superadmin_repository.dart';
import 'new_station_modal.dart';

class ManageBrandDialog extends StatefulWidget {
  const ManageBrandDialog({
    super.key,
    required this.marca,
    required this.repository,
  });

  final MarcaRecord marca;
  final SuperAdminRepository repository;

  @override
  State<ManageBrandDialog> createState() => _ManageBrandDialogState();
}

class _ManageBrandDialogState extends State<ManageBrandDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Datos Generales ---
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late bool _active;
  bool _savingGeneral = false;
  bool _sendingReset = false;
  bool _confirmingDelete = false;
  String? _errorGeneral;
  bool _obscurePassword = true;

  // --- Módulos ---
  late AppFeatures _features;
  bool _savingModules = false;

  // --- Contenido (Radios y TV) ---
  StreamSubscription? _emisorasSub;
  StreamSubscription? _streamingsSub;
  List<SuperAdminEmisoraRecord> _emisoras = [];
  List<SuperAdminStreamingRecord> _streamings = [];
  bool _loadingContent = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Init General
    _nombreController = TextEditingController(text: widget.marca.nombreGrupo);
    _emailController = TextEditingController(text: widget.marca.ownerEmail);
    _passwordController = TextEditingController();
    _active = widget.marca.active;

    // Init Módulos
    _features = widget.marca.features;

    // Init Content
    _emisorasSub = widget.repository.streamEmisoras(widget.marca.appId).listen((list) {
      if (mounted) setState(() { _emisoras = list; _loadingContent = false; });
    });
    _streamingsSub = widget.repository.streamStreamings(widget.marca.appId).listen((list) {
      if (mounted) setState(() { _streamings = list; });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emisorasSub?.cancel();
    _streamingsSub?.cancel();
    super.dispose();
  }

  // ==========================================
  // Lógica: Datos Generales
  // ==========================================
  Future<void> _saveGeneral() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _savingGeneral = true; _errorGeneral = null; });
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos generales actualizados')));
      }
    } catch (e) {
      if (mounted) setState(() => _errorGeneral = e.toString());
    } finally {
      if (mounted) setState(() => _savingGeneral = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorGeneral = 'El correo no es válido.');
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await widget.repository.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset enviado a $email')));
      }
    } catch (e) {
      if (mounted) setState(() => _errorGeneral = 'Error al enviar reset: $e');
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  Future<void> _deleteMarca() async {
    if (!_confirmingDelete) {
      setState(() => _confirmingDelete = true);
      return;
    }
    setState(() => _savingGeneral = true);
    try {
      await widget.repository.deleteMarca(widget.marca.appId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marca eliminada permanentemente')));
      }
    } catch (e) {
      if (mounted) setState(() { _savingGeneral = false; _errorGeneral = 'Error al eliminar: $e'; _confirmingDelete = false; });
    }
  }

  // ==========================================
  // Lógica: Módulos
  // ==========================================
  Future<void> _saveModules() async {
    setState(() => _savingModules = true);
    try {
      await widget.repository.updateMarcaFeatures(widget.marca.appId, _features);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Módulos actualizados')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingModules = false);
    }
  }

  // ==========================================
  // Lógica: Radios y Streamings
  // ==========================================
  void _openNewStationModal(bool isStreaming) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NewStationModal(
        appId: widget.marca.appId,
        ownerEmail: widget.marca.ownerEmail,
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Radio eliminada')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Streaming eliminado')));
    }
  }

  // ==========================================
  // UI Builders
  // ==========================================

  Widget _buildGeneralTab() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorGeneral != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(_errorGeneral!, style: TextStyle(color: scheme.onErrorContainer)),
              ),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre Comercial', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo del Propietario (Admin)', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || !v.contains('@') ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Nueva Contraseña (opcional)',
                border: const OutlineInputBorder(),
                helperText: 'Déjalo en blanco si no deseas cambiarla.',
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
            SwitchListTile(
              title: const Text('Marca Activa'),
              subtitle: const Text('Si se desactiva, los administradores de esta marca no podrán iniciar sesión.'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _savingGeneral ? null : _saveGeneral,
                    icon: _savingGeneral ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                    label: const Text('Guardar Cambios Generales'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Acciones de Seguridad', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sendingReset ? null : _sendPasswordReset,
                    icon: _sendingReset ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_reset),
                    label: const Text('Enviar Reset de Contraseña'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: _confirmingDelete ? scheme.error : scheme.error.withValues(alpha: 0.5), width: _confirmingDelete ? 2 : 1),
                    ),
                    onPressed: _savingGeneral ? null : _deleteMarca,
                    icon: const Icon(Icons.delete_forever),
                    label: Text(_confirmingDelete ? 'Haz clic de nuevo para CONFIRMAR' : 'Eliminar Marca (Peligro)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Activa o desactiva las funciones para esta marca. Los cambios afectarán la interfaz que ven sus administradores y usuarios.'),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Módulo Radio'),
            subtitle: const Text('Permite gestionar múltiples estaciones de radio y URLs de audio.'),
            value: _features.enableRadio,
            onChanged: (v) => setState(() => _features = _features.copyWith(enableRadio: v)),
            secondary: const Icon(Icons.radio),
          ),
          SwitchListTile(
            title: const Text('Módulo TV (Streaming)'),
            subtitle: const Text('Permite gestionar múltiples canales de video/TV.'),
            value: _features.enableTv,
            onChanged: (v) => setState(() => _features = _features.copyWith(enableTv: v)),
            secondary: const Icon(Icons.tv),
          ),
          SwitchListTile(
            title: const Text('Módulo Programación'),
            subtitle: const Text('Activa la grilla de programas y horarios para las estaciones o canales.'),
            value: _features.enableSchedule,
            onChanged: (v) => setState(() => _features = _features.copyWith(enableSchedule: v)),
            secondary: const Icon(Icons.calendar_month),
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _savingModules ? null : _saveModules,
            icon: _savingModules ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: const Text('Guardar Configuración de Módulos'),
          )
        ],
      ),
    );
  }

  Widget _buildStationList(bool isStreaming) {
    if (_loadingContent) return const Center(child: CircularProgressIndicator());

    final items = isStreaming ? _streamings : _emisoras;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isStreaming ? 'Streamings de TV' : 'Estaciones de Radio',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _openNewStationModal(isStreaming),
                icon: const Icon(Icons.add),
                label: Text(isStreaming ? 'Nuevo Streaming' : 'Nueva Radio'),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('No hay registros de ${isStreaming ? 'TV' : 'Radio'}.', style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final name = isStreaming ? (item as SuperAdminStreamingRecord).nombre : (item as SuperAdminEmisoraRecord).nombre;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.podcasts)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ID: ${isStreaming ? (item as SuperAdminStreamingRecord).id : (item as SuperAdminEmisoraRecord).id}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          if (isStreaming) {
                            _deleteStreaming(item as SuperAdminStreamingRecord);
                          } else {
                            _deleteEmisora(item as SuperAdminEmisoraRecord);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: scheme.surface),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: scheme.surfaceContainerHigh,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.domain, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.marca.nombreGrupo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('App ID: ${widget.marca.appId}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Datos Generales', icon: Icon(Icons.settings)),
                Tab(text: 'Módulos', icon: Icon(Icons.extension)),
                Tab(text: 'Radios', icon: Icon(Icons.radio)),
                Tab(text: 'TV & Streaming', icon: Icon(Icons.tv)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(),
                  _buildModulesTab(),
                  _buildStationList(false), // Radios
                  _buildStationList(true), // TV
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
