import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/services/brand_storage_service.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/utils/firestore_typed_value.dart';
import 'package:radio_whitelabel/dashboard_web/utils/color_hex.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/brand_image_upload_zone.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/mobile_app_preview.dart';

class StreamingWorkspace extends StatefulWidget {
  const StreamingWorkspace({
    super.key,
    required this.streaming,
    required this.appId,
    required this.repository,
    required this.ownerEmail,
    required this.dataStore,
  });

  final Streaming streaming;
  final String appId;
  final EmisoraRepository repository;
  final String ownerEmail;
  final ClientDataStore dataStore;

  @override
  State<StreamingWorkspace> createState() => _StreamingWorkspaceState();
}

class _StreamingWorkspaceState extends State<StreamingWorkspace> {
  final _nombre = TextEditingController();
  final _urlVideo = TextEditingController();
  final _logoUrl = TextEditingController();
  final _hex = TextEditingController();
  final _hexSecundario = TextEditingController();

  bool _saving = false;
  bool _uploadingLogo = false;
  bool _mostrarEnCarrusel = false;

  final BrandStorageService _brandStorage = BrandStorageService();

  @override
  void initState() {
    super.initState();
    _populate(widget.streaming);
    _logoUrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant StreamingWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streaming.id != widget.streaming.id) _populate(widget.streaming);
  }

  void _populate(Streaming s) {
    _nombre.text = s.nombre;
    _urlVideo.text = s.urlVideo;
    _logoUrl.text = s.logoUrl;
    _hex.text = ColorHex.normalize(s.colorHex);
    _hexSecundario.text = ColorHex.normalize(s.colorSecundarioHex);
    _mostrarEnCarrusel = s.mostrarEnCarrusel;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _urlVideo.dispose();
    _logoUrl.dispose();
    _hex.dispose();
    _hexSecundario.dispose();
    super.dispose();
  }

  Future<void> _openColorPicker() async {
    final scheme = Theme.of(context).colorScheme;
    Color pickerColor = ColorHex.tryParse(_hex.text) ?? scheme.primary;

    final Color? result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Color corporativo'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (c) => setDialogState(() => pickerColor = c),
                  enableAlpha: false,
                  hexInputBar: true,
                  labelTypes: const [],
                  displayThumbColor: true,
                  pickerAreaHeightPercent: 0.62,
                  pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8)),
                  paletteType: PaletteType.hsvWithHue,
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(pickerColor), child: const Text('Aplicar')),
          ],
          surfaceTintColor: scheme.surfaceTint,
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _hex.text = ColorHex.toRgbHex(result));
    }
  }

  Future<void> _openColorSecundarioPicker() async {
    final scheme = Theme.of(context).colorScheme;
    Color pickerColor = ColorHex.tryParse(_hexSecundario.text) ?? scheme.primary;

    final Color? result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Color secundario'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (c) => setDialogState(() => pickerColor = c),
                  enableAlpha: false,
                  hexInputBar: true,
                  labelTypes: const [],
                  displayThumbColor: true,
                  pickerAreaHeightPercent: 0.62,
                  pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8)),
                  paletteType: PaletteType.hsvWithHue,
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(pickerColor), child: const Text('Aplicar')),
          ],
          surfaceTintColor: scheme.surfaceTint,
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _hexSecundario.text = ColorHex.toRgbHex(result));
    }
  }

  Future<void> _uploadLogo(Uint8List bytes, String contentType) async {
    setState(() => _uploadingLogo = true);
    try {
      final downloadUrl = await _brandStorage.uploadStreamingLogo(
        appId: widget.appId,
        streamingId: widget.streaming.id,
        bytes: bytes,
        contentType: contentType,
      );
      await widget.repository.updateStreamingFields(
        widget.streaming.id,
        {EmisoraFields.logoUrl: downloadUrl},
        appId: widget.appId,
      );
      if (!mounted) return;
      _logoUrl.text = downloadUrl;
      widget.dataStore.patchStreaming(widget.streaming.copyWith(logoUrl: downloadUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen del canal subida y guardada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir la imagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        EmisoraFields.nombre: _nombre.text.trim(),
        EmisoraFields.urlVideo: FirestoreTypedValue.toFirestoreString(_urlVideo.text),
        EmisoraFields.logoUrl: FirestoreTypedValue.toFirestoreString(_logoUrl.text),
        EmisoraFields.colorHex: ColorHex.normalize(_hex.text),
        EmisoraFields.colorSecundarioHex: ColorHex.normalize(_hexSecundario.text),
        EmisoraFields.mostrarEnCarrusel: _mostrarEnCarrusel,
      };
      await widget.repository.updateStreamingFields(
        widget.streaming.id,
        payload,
        appId: widget.appId,
      );
      widget.dataStore.patchStreaming(
        widget.streaming.copyWith(
          nombre: payload[EmisoraFields.nombre] as String,
          urlVideo: payload[EmisoraFields.urlVideo] as String,
          logoUrl: payload[EmisoraFields.logoUrl] as String,
          colorHex: payload[EmisoraFields.colorHex] as String,
          colorSecundarioHex: payload[EmisoraFields.colorSecundarioHex] as String,
          mostrarEnCarrusel: _mostrarEnCarrusel,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: true,
          backgroundColor: scheme.surface,
          surfaceTintColor: scheme.surfaceTint,
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.1),
          title: Text(
            widget.streaming.nombre,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Guardando…' : 'Guardar Cambios'),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 24, isMobile ? 12 : 24, 60),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildConfigForm(scheme),
                          ),
                          const SizedBox(width: 48),
                          Expanded(
                            flex: 3,
                            child: _buildPreview(),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildConfigForm(scheme),
                          const SizedBox(height: 32),
                          _buildPreview(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configura tu canal de video en directo.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Canal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Campos esenciales para listar y reproducir el live en la app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    helperText: 'Nombre visible en la lista de canales TV.',
                    hintText: 'Ej. TV En Vivo',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _urlVideo,
                  decoration: const InputDecoration(
                    labelText: 'URL del stream',
                    helperText: 'Enlace de video (HLS .m3u8, MP4, YouTube, etc.).',
                    hintText: 'https://…/playlist.m3u8',
                    prefixIcon: Icon(Icons.videocam_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                // ── Acceso directo en carrusel de estaciones ──────────────
                Container(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    secondary: Icon(Icons.tv_rounded, color: scheme.primary),
                    title: Text(
                      'Mostrar en barra de estaciones',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Al activarlo, este canal aparecerá en la barra superior de la app junto a las emisoras de radio. Al tocarlo, abrirá la pantalla de TV.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    value: _mostrarEnCarrusel,
                    onChanged: (val) => setState(() => _mostrarEnCarrusel = val),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Imagen del canal',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sube un archivo PNG o JPG. Se guardará en Firebase Storage automáticamente.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                BrandImageUploadZone(
                  uploading: _uploadingLogo,
                  currentImageUrl: _logoUrl.text,
                  onUpload: _uploadLogo,
                  uploadButtonLabel: 'Subir Imagen del Canal',
                  uploadingLabel: 'Subiendo imagen…',
                  emptyPreviewText: 'Aún no hay imagen. Sube una para previsualizarla.',
                  previewWidth: 72,
                  previewHeight: 72,
                ),
                const SizedBox(height: 24),
                Text(
                  'Color corporativo',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _hex,
                      builder: (context, value, _) {
                        final c = ColorHex.tryParse(value.text) ?? scheme.primary;
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hex,
                        decoration: const InputDecoration(
                          labelText: 'Color (hex)',
                          helperText: 'Ejemplo: #E53935',
                          prefixIcon: Icon(Icons.color_lens_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        onPressed: _openColorPicker,
                        icon: const Icon(Icons.palette_outlined, size: 20),
                        label: const Text('Selector'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Color secundario',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _hexSecundario,
                      builder: (context, value, _) {
                        final c = ColorHex.tryParse(value.text) ?? scheme.primary;
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hexSecundario,
                        decoration: const InputDecoration(
                          labelText: 'Color Secundario (hex)',
                          helperText: 'Ejemplo: #35ACE5',
                          prefixIcon: Icon(Icons.color_lens_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        onPressed: _openColorSecundarioPicker,
                        icon: const Icon(Icons.palette_outlined, size: 20),
                        label: const Text('Selector'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Previsualización',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Así se verá el canal en la aplicación móvil.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: MobileAppPreview(
            brandName: _nombre.text.isEmpty ? widget.streaming.nombre : _nombre.text,
            logoUrl: _logoUrl.text,
            primaryColorHex: _hex.text,
            secondaryColorHex: _hexSecundario.text,
            isStreaming: true,
          ),
        ),
      ],
    );
  }
}
