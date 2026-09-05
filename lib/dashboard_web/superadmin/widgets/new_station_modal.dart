import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/brand_storage_service.dart';
import '../services/superadmin_repository.dart';

class NewStationModal extends StatefulWidget {
  final String appId;
  final String ownerEmail;
  final bool isStreaming;
  final SuperAdminRepository repository;

  const NewStationModal({
    super.key,
    required this.appId,
    required this.ownerEmail,
    required this.isStreaming,
    required this.repository,
  });

  @override
  State<NewStationModal> createState() => _NewStationModalState();
}

class _NewStationModalState extends State<NewStationModal> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic fields
  final _nombreController = TextEditingController();
  final _urlController = TextEditingController();
  
  // Style fields
  final _colorHexController = TextEditingController(text: '#205CC6');
  final _colorSecundarioHexController = TextEditingController(text: '#35ACE5');
  
  // Logo upload
  Uint8List? _logoBytes;
  String? _logoContentType;
  String? _logoFileName;

  // Settings
  bool _mostrarProgramacion = false;
  
  // Social / Contact (Only for Radio)
  final _telefonoController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _xController = TextEditingController();

  bool _saving = false;
  String? _error;

  final _storageService = BrandStorageService();

  @override
  void dispose() {
    _nombreController.dispose();
    _urlController.dispose();
    _colorHexController.dispose();
    _colorSecundarioHexController.dispose();
    _telefonoController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _xController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo seleccionado.')),
      );
      return;
    }

    final contentType = BrandStorageService.mimeTypeForExtension(file.extension);
    if (contentType == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato no válido. Usa PNG o JPG.')),
      );
      return;
    }

    if (bytes.length > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen no puede superar 5 MB.')),
      );
      return;
    }

    setState(() {
      _logoBytes = bytes;
      _logoContentType = contentType;
      _logoFileName = file.name;
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String docId;

      if (widget.isStreaming) {
        docId = await widget.repository.createStreaming(
          appId: widget.appId,
          ownerEmail: widget.ownerEmail,
          nombre: _nombreController.text.trim(),
          urlVideo: _urlController.text.trim(),
          colorHex: _colorHexController.text.trim(),
        );
      } else {
        docId = await widget.repository.createEmisora(
          appId: widget.appId,
          ownerEmail: widget.ownerEmail,
          nombre: _nombreController.text.trim(),
          urlAudio: _urlController.text.trim(),
          colorHex: _colorHexController.text.trim(),
          colorSecundarioHex: _colorSecundarioHexController.text.trim(),
          mostrarProgramacion: _mostrarProgramacion,
          telefonoCabina: _telefonoController.text.trim(),
          socialWhatsapp: _whatsappController.text.trim(),
          socialFacebook: _facebookController.text.trim(),
          socialInstagram: _instagramController.text.trim(),
          socialX: _xController.text.trim(),
        );
      }

      // Upload logo if selected
      if (_logoBytes != null && _logoContentType != null) {
        try {
          String downloadUrl;
          if (widget.isStreaming) {
            downloadUrl = await _storageService.uploadStreamingLogo(
              appId: widget.appId,
              streamingId: docId,
              bytes: _logoBytes!,
              contentType: _logoContentType!,
            );
          } else {
            downloadUrl = await _storageService.uploadEmisoraLogo(
              appId: widget.appId,
              emisoraId: docId,
              bytes: _logoBytes!,
              contentType: _logoContentType!,
            );
          }
          // Update the document with the logo URL
          final collection = widget.isStreaming ? 'streamings' : 'emisoras';
          await widget.repository.db.collection(collection).doc(docId).update({
            'logo_url': downloadUrl,
          });
        } catch (e) {
          // Station was created but logo failed — not critical
          debugPrint('Logo upload failed: $e');
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.isStreaming ? 'Streaming' : 'Radio'} creada exitosamente.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _saving = false;
        });
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, {String? hint, bool required = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
            ),
            validator: required ? (v) => v == null || v.trim().isEmpty ? 'Requerido' : null : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadZone() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Logo (Opcional)', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _saving ? null : _pickLogo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: _logoBytes != null
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _logoBytes!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _logoFileName ?? 'logo',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(_logoBytes!.length / 1024).toStringAsFixed(1)} KB',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _logoBytes = null;
                              _logoContentType = null;
                              _logoFileName = null;
                            }),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 36, color: scheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            'Subir Logo',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Haz clic para seleccionar PNG o JPG (máx. 5 MB)',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeLabel = widget.isStreaming ? 'Streaming TV' : 'Radio Emisora';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nueva $typeLabel', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          'Agrega y configura todos los detalles de la estación.',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(_nombreController, 'Nombre de la Estación', hint: 'Ej. Canal Principal', required: true),
                        _buildTextField(
                          _urlController, 
                          'URL del Stream', 
                          hint: widget.isStreaming ? 'https://.../playlist.m3u8' : 'https://.../stream', 
                          required: true,
                          keyboardType: TextInputType.url,
                        ),
                        
                        const Divider(height: 32),
                        Text('Apariencia', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildLogoUploadZone(),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_colorHexController, 'Color Principal', hint: '#FFFFFF')),
                            const SizedBox(width: 16),
                            if (!widget.isStreaming)
                              Expanded(child: _buildTextField(_colorSecundarioHexController, 'Color Secundario', hint: '#000000')),
                          ],
                        ),
                        
                        if (!widget.isStreaming)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Mostrar Programación', style: textTheme.labelLarge),
                            subtitle: const Text('Habilita el tab de programación para esta estación.'),
                            value: _mostrarProgramacion,
                            onChanged: (v) => setState(() => _mostrarProgramacion = v),
                          ),

                        if (!widget.isStreaming) ...[
                          const Divider(height: 32),
                          Text('Redes Sociales y Contacto', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildTextField(_telefonoController, 'Teléfono de Cabina (Opcional)'),
                          _buildTextField(_whatsappController, 'Enlace de WhatsApp (Opcional)', hint: 'https://wa.me/...'),
                          _buildTextField(_facebookController, 'Enlace de Facebook (Opcional)'),
                          _buildTextField(_instagramController, 'Enlace de Instagram (Opcional)'),
                          _buildTextField(_xController, 'Enlace de X / Twitter (Opcional)'),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                            child: Text(_error!, style: textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _create,
                    child: _saving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Crear Estación'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
