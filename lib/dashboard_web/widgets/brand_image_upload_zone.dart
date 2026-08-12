import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/services/brand_storage_service.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/cached_dashboard_image.dart';

/// Zona de arrastre / selector para subir imágenes de marca (PNG/JPG).
class BrandImageUploadZone extends StatefulWidget {
  const BrandImageUploadZone({
    super.key,
    required this.uploading,
    required this.currentImageUrl,
    required this.onUpload,
    required this.uploadButtonLabel,
    required this.uploadingLabel,
    required this.emptyPreviewText,
    this.previewHeight,
    this.previewWidth,
    this.previewFit = BoxFit.contain,
    this.icon = Icons.cloud_upload_outlined,
  });

  final bool uploading;
  final String currentImageUrl;
  final Future<void> Function(Uint8List bytes, String contentType) onUpload;
  final String uploadButtonLabel;
  final String uploadingLabel;
  final String emptyPreviewText;
  final double? previewHeight;
  final double? previewWidth;
  final BoxFit previewFit;
  final IconData icon;

  @override
  State<BrandImageUploadZone> createState() => _BrandImageUploadZoneState();
}

class _BrandImageUploadZoneState extends State<BrandImageUploadZone> {
  bool _dragging = false;
  Uint8List? _localBytes;

  bool get _hasImage => widget.currentImageUrl.trim().startsWith('http') || _localBytes != null;

  Future<void> _pickFile() async {
    if (widget.uploading) return;

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

    await _processBytes(bytes, file.extension);
  }

  Future<void> _processBytes(Uint8List bytes, String? extension) async {
    final contentType = BrandStorageService.mimeTypeForExtension(extension);
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

    try {
      await widget.onUpload(bytes, contentType);
      if (mounted) {
        setState(() => _localBytes = bytes);
      }
    } catch (_) {
      // El padre muestra el error concreto.
    }
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    if (widget.uploading) return;
    setState(() => _dragging = false);

    if (details.files.isEmpty) return;
    final file = details.files.first;

    final extension = file.name.split('.').lastOrNull;
    final bytes = await file.readAsBytes();
    await _processBytes(bytes, extension);
  }

  Widget _buildLocalImage() {
    Widget image = Image.memory(
      _localBytes!,
      width: widget.previewWidth != null ? widget.previewWidth! * 1.6 : double.infinity,
      height: widget.previewHeight != null
          ? widget.previewHeight! * (widget.previewWidth != null ? 1.6 : 2.5)
          : (widget.previewWidth != null ? widget.previewWidth! * 1.6 : 180),
      fit: widget.previewFit,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
    );
    if (widget.previewFit == BoxFit.cover) {
      image = ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
    }
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: _onDrop,
          child: Material(
            color: _dragging ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.uploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _dragging ? scheme.primary : scheme.outlineVariant,
                    width: _dragging ? 2 : 1,
                  ),
                ),
                child: widget.uploading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.uploadingLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, size: 40, color: scheme.primary),
                          const SizedBox(height: 10),
                          Text(
                            widget.uploadButtonLabel,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Arrastra PNG o JPG aquí, o haz clic para seleccionar',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: !_hasImage
              ? Text(
                  widget.emptyPreviewText,
                  key: const ValueKey('no_image'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                )
              : ClipRRect(
                  key: ValueKey<String>(widget.currentImageUrl),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: scheme.surfaceContainerHighest,
                    padding: widget.previewFit == BoxFit.contain ? const EdgeInsets.all(16) : EdgeInsets.zero,
                    width: double.infinity,
                    height: widget.previewWidth != null
                        // Logo cuadrado: contenedor más grande centrado
                        ? null
                        // Banner/splash: altura generosa
                        : (widget.previewHeight != null ? widget.previewHeight! * 2.5 : 180),
                    child: widget.previewWidth != null
                        ? Center(
                            child: _localBytes != null
                                ? _buildLocalImage()
                                : CachedDashboardImage(
                                    url: widget.currentImageUrl,
                                    width: widget.previewWidth! * 1.6,
                                    height: widget.previewHeight != null
                                        ? widget.previewHeight! * 1.6
                                        : widget.previewWidth! * 1.6,
                                    fit: widget.previewFit,
                                    borderRadius: widget.previewFit == BoxFit.cover
                                        ? BorderRadius.circular(12)
                                        : null,
                                  ),
                          )
                        : _localBytes != null
                            ? _buildLocalImage()
                            : CachedDashboardImage(
                                url: widget.currentImageUrl,
                                width: double.infinity,
                                height: widget.previewHeight != null
                                    ? widget.previewHeight! * 2.5
                                    : 180,
                                fit: widget.previewFit,
                                borderRadius: widget.previewFit == BoxFit.cover
                                    ? BorderRadius.circular(12)
                                    : null,
                              ),
                  ),
                ),
        ),
      ],
    );
  }
}
