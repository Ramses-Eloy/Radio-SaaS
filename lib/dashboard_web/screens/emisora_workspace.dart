import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/services/brand_storage_service.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/utils/color_hex.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/brand_image_upload_zone.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/mobile_app_preview.dart';
class EmisoraWorkspace extends StatefulWidget {
  const EmisoraWorkspace({
    super.key,
    required this.emisora,
    required this.appId,
    required this.repository,
    required this.ownerEmail,
    required this.dataStore,
  });

  final Emisora emisora;
  final String appId;
  final EmisoraRepository repository;
  final String ownerEmail;
  final ClientDataStore dataStore;

  @override
  State<EmisoraWorkspace> createState() => _EmisoraWorkspaceState();
}

class _EmisoraWorkspaceState extends State<EmisoraWorkspace> {
  final _nombre = TextEditingController();
  final _urlAudio = TextEditingController();
  final _hex = TextEditingController();
  final _hexSecundario = TextEditingController();
  final _logoUrl = TextEditingController();
  final _facebook = TextEditingController();
  final _whatsapp = TextEditingController();
  final _instagram = TextEditingController();
  final _x = TextEditingController();
  final _telefonoCabina = TextEditingController();

  bool _saving = false;
  bool _uploadingLogo = false;
  bool _mostrarProgramacion = true;

  final BrandStorageService _brandStorage = BrandStorageService();

  @override
  void initState() {
    super.initState();
    _populate(widget.emisora);
    _logoUrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant EmisoraWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emisora.id != widget.emisora.id) {
      _populate(widget.emisora);
    }
  }

  void _populate(Emisora e) {
    _nombre.text = e.nombre;
    _urlAudio.text = e.urlAudio;
    _hex.text = ColorHex.normalize(e.colorHex);
    _hexSecundario.text = ColorHex.normalize(e.colorSecundarioHex);
    _logoUrl.text = e.logoUrl;
    _facebook.text = e.socialFacebook;
    _whatsapp.text = e.socialWhatsapp;
    _instagram.text = e.socialInstagram;
    _x.text = e.socialX;
    _telefonoCabina.text = e.telefonoCabina;
    _mostrarProgramacion = e.mostrarProgramacion;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _urlAudio.dispose();
    _hex.dispose();
    _hexSecundario.dispose();
    _logoUrl.dispose();
    _facebook.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _x.dispose();
    _telefonoCabina.dispose();
    super.dispose();
  }

  Future<void> _openColorPicker() async {
    final scheme = Theme.of(context).colorScheme;
    Color pickerColor = ColorHex.tryParse(_hex.text) ?? ColorHex.tryParse(ColorHex.defaultHex)!;

    final Color? result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Color de la marca'),
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
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(pickerColor),
              child: const Text('Aplicar'),
            ),
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
    Color pickerColor = ColorHex.tryParse(_hexSecundario.text) ?? ColorHex.tryParse(ColorHex.defaultHex)!;

    final Color? result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Color Secundario'),
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
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(pickerColor),
              child: const Text('Aplicar'),
            ),
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
      final downloadUrl = await _brandStorage.uploadEmisoraLogo(
        appId: widget.appId,
        emisoraId: widget.emisora.id,
        bytes: bytes,
        contentType: contentType,
      );
      await widget.repository.updateEmisoraFields(
        widget.emisora.id,
        {EmisoraFields.logoUrl: downloadUrl},
        appId: widget.appId,
      );
      if (!mounted) return;
      _logoUrl.text = downloadUrl;
      widget.dataStore.patchEmisora(widget.emisora.copyWith(logoUrl: downloadUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo subido y guardado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir el logo: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.updateEmisoraFields(
        widget.emisora.id,
        {
          EmisoraFields.nombre: _nombre.text.trim(),
          EmisoraFields.urlAudio: _urlAudio.text.trim(),
          EmisoraFields.urlVideo: widget.emisora.urlVideo,
          EmisoraFields.colorHex: ColorHex.normalize(_hex.text),
          EmisoraFields.colorSecundarioHex: ColorHex.normalize(_hexSecundario.text),
          EmisoraFields.logoUrl: _logoUrl.text.trim(),
          EmisoraFields.isVideo: false,
          EmisoraFields.mostrarProgramacion: _mostrarProgramacion,
          EmisoraFields.socialFacebook: _facebook.text.trim(),
          EmisoraFields.socialWhatsapp: _whatsapp.text.trim(),
          EmisoraFields.socialInstagram: _instagram.text.trim(),
          EmisoraFields.socialX: _x.text.trim(),
          EmisoraFields.telefonoCabina: _telefonoCabina.text.trim(),
        },
        appId: widget.appId,
      );
      if (!mounted) return;
      widget.dataStore.patchEmisora(
        widget.emisora.copyWith(
          nombre: _nombre.text.trim(),
          urlAudio: _urlAudio.text.trim(),
          colorHex: ColorHex.normalize(_hex.text),
          colorSecundarioHex: ColorHex.normalize(_hexSecundario.text),
          logoUrl: _logoUrl.text.trim(),
          isVideo: false,
          mostrarProgramacion: _mostrarProgramacion,
          socialFacebook: _facebook.text.trim(),
          socialWhatsapp: _whatsapp.text.trim(),
          socialInstagram: _instagram.text.trim(),
          socialX: _x.text.trim(),
          telefonoCabina: _telefonoCabina.text.trim(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios guardados. La app móvil puede leerlos al instante.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.emisora;
    final swatch = ColorHex.tryParse(e.colorHex) ?? scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sticky Header with Title and Save Button
        Material(
          color: scheme.surface,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 48,
                  decoration: BoxDecoration(
                    color: swatch,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.radio, size: 36, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Personaliza los datos de tu emisora de audio.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando…' : 'Guardar Cambios'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _ManagementTab(
            nombre: _nombre,
            urlAudio: _urlAudio,
            hex: _hex,
            hexSecundario: _hexSecundario,
            logoUrl: _logoUrl,
            mostrarProgramacion: _mostrarProgramacion,
            onMostrarProgramacionChanged: (v) => setState(() => _mostrarProgramacion = v),
            facebook: _facebook,
            whatsapp: _whatsapp,
            instagram: _instagram,
            x: _x,
            telefonoCabina: _telefonoCabina,
            onPickColor: _openColorPicker,
            onPickColorSecundario: _openColorSecundarioPicker,
            uploadingLogo: _uploadingLogo,
            onUploadLogo: _uploadLogo,
          ),
        ),
      ],
    );
  }
}

class _ManagementTab extends StatelessWidget {
  const _ManagementTab({
    required this.nombre,
    required this.urlAudio,
    required this.hex,
    required this.hexSecundario,
    required this.logoUrl,
    required this.mostrarProgramacion,
    required this.onMostrarProgramacionChanged,
    required this.facebook,
    required this.whatsapp,
    required this.instagram,
    required this.x,
    required this.telefonoCabina,
    required this.onPickColor,
    required this.onPickColorSecundario,
    required this.uploadingLogo,
    required this.onUploadLogo,
  });

  final TextEditingController nombre;
  final TextEditingController urlAudio;
  final TextEditingController hex;
  final TextEditingController hexSecundario;
  final TextEditingController logoUrl;
  final bool mostrarProgramacion;
  final ValueChanged<bool> onMostrarProgramacionChanged;
  final TextEditingController facebook;
  final TextEditingController whatsapp;
  final TextEditingController instagram;
  final TextEditingController x;
  final TextEditingController telefonoCabina;
  final VoidCallback onPickColor;
  final VoidCallback onPickColorSecundario;
  final bool uploadingLogo;
  final Future<void> Function(Uint8List bytes, String contentType) onUploadLogo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos generales',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nombre visible de la estación.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la estación',
                    helperText: 'Este nombre se verá en la lista de estaciones en la app.',
                    hintText: 'Ej. Radio Costa FM',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apariencia visual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Colores usados en el reproductor de la app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                Text(
                  'Color corporativo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: hex,
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
                        controller: hex,
                        decoration: const InputDecoration(
                          labelText: 'Código hex',
                          hintText: '#1E3A5F',
                          prefixIcon: Icon(Icons.color_lens_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        onPressed: onPickColor,
                        icon: const Icon(Icons.palette_outlined, size: 20),
                        label: const Text('Selector'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Color secundario',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: hexSecundario,
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
                        controller: hexSecundario,
                        decoration: const InputDecoration(
                          labelText: 'Código hex',
                          hintText: '#35ACE5',
                          prefixIcon: Icon(Icons.color_lens_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        onPressed: onPickColorSecundario,
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
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Programación',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Controla si la app muestra la sección de horarios para esta emisora.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar sección de programación'),
                  subtitle: Text(
                    mostrarProgramacion ? 'Visible' : 'Oculta',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  value: mostrarProgramacion,
                  onChanged: onMostrarProgramacionChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streaming',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enlace de transmisión de audio.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: urlAudio,
                  decoration: const InputDecoration(
                    labelText: 'Enlace de audio (URL)',
                    helperText: 'Ejemplo: enlace del stream MP3/AAC. Pega la URL completa.',
                    hintText: 'https://…/stream.mp3',
                    prefixIcon: Icon(Icons.headphones),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redes y contacto',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pega enlaces completos para que funcionen al tocar en la app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: telefonoCabina,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Cabina',
                    helperText: 'Número de contacto de la cabina de esta emisora.',
                    hintText: 'Ej. +34 600 000 000',
                    prefixIcon: Icon(Icons.phone_in_talk_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: facebook,
                  decoration: const InputDecoration(
                    labelText: 'Facebook',
                    helperText: 'URL del perfil o página de Facebook.',
                    prefixIcon: Icon(Icons.facebook),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: whatsapp,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp',
                    helperText: 'Número o enlace. Recomendado: https://wa.me/…',
                    prefixIcon: Icon(Icons.chat),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: instagram,
                  decoration: const InputDecoration(
                    labelText: 'Instagram',
                    helperText: 'URL del perfil de Instagram.',
                    prefixIcon: Icon(Icons.camera_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: x,
                  decoration: const InputDecoration(
                    labelText: 'X',
                    helperText: 'URL del perfil de X (Twitter).',
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logo de la emisora',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sube un archivo PNG o JPG. Se guardará en Firebase Storage.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                BrandImageUploadZone(
                  uploading: uploadingLogo,
                  currentImageUrl: logoUrl.text,
                  onUpload: onUploadLogo,
                  uploadButtonLabel: 'Subir Logo',
                  uploadingLabel: 'Subiendo logo…',
                  emptyPreviewText: 'Aún no hay logo. Sube una imagen para previsualizarla.',
                  previewWidth: 72,
                  previewHeight: 72,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ValueListenableBuilder(
            valueListenable: logoUrl,
            builder: (context, _, child) {
              return ValueListenableBuilder(
                valueListenable: hex,
                builder: (context, _, child) {
                  return ValueListenableBuilder(
                    valueListenable: hexSecundario,
                    builder: (context, _, child) {
                      return ValueListenableBuilder(
                        valueListenable: nombre,
                        builder: (context, _, child) {
                          return MobileAppPreview(
                            brandName: nombre.text,
                            logoUrl: logoUrl.text,
                            primaryColorHex: hex.text,
                            secondaryColorHex: hexSecundario.text,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 13, child: leftColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 10, child: rightColumn),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rightColumn,
                    const SizedBox(height: 24),
                    leftColumn,
                  ],
                ),
        ),
      ),
    );
  }
}
