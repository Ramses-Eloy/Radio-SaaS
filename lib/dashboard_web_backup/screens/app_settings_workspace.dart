import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/models/app_info.dart';
import 'package:radio_whitelabel/dashboard_web/services/brand_storage_service.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/utils/firestore_typed_value.dart';
import 'package:radio_whitelabel/dashboard_web/utils/url_field.dart';
import 'package:radio_whitelabel/dashboard_web/widgets/brand_image_upload_zone.dart';

class AppSettingsWorkspace extends StatefulWidget {
  const AppSettingsWorkspace({
    super.key,
    required this.info,
    required this.appId,
    required this.repository,
    required this.ownerEmail,
    required this.dataStore,
  });

  final AppInfo info;
  /// Identificador de aplicación (documento `marcas/{appId}`).
  final String appId;
  final EmisoraRepository repository;
  final String ownerEmail;
  final ClientDataStore dataStore;

  @override
  State<AppSettingsWorkspace> createState() => _AppSettingsWorkspaceState();
}

class _AppSettingsWorkspaceState extends State<AppSettingsWorkspace> {
  final _nombreGrupo = TextEditingController();
  final _radioLabel = TextEditingController();
  final _tvLabel = TextEditingController();
  final _logoUrl = TextEditingController();
  final _splashUrl = TextEditingController();
  final _bannerHomeUrl = TextEditingController();
  final _splashDuration = TextEditingController();
  final _flashInformativo = TextEditingController();

  bool _saving = false;
  bool _uploadingLogo = false;
  bool _uploadingSplash = false;
  bool _uploadingBanner = false;
  bool _lanzandoFlashInformativo = false;
  bool _splashEnabled = false;

  final BrandStorageService _brandStorage = BrandStorageService();

  @override
  void initState() {
    super.initState();
    _populate(widget.info);
    _logoUrl.addListener(() {
      if (mounted) setState(() {});
    });
    _splashUrl.addListener(() {
      if (mounted) setState(() {});
    });
    _bannerHomeUrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant AppSettingsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.id != widget.info.id ||
        oldWidget.info.nombreGrupo != widget.info.nombreGrupo) {
      _populate(widget.info);
    }
  }

  void _populate(AppInfo i) {
    _nombreGrupo.text = i.nombreGrupo;
    _radioLabel.text = i.radioLabel;
    _tvLabel.text = i.tvLabel;
    _logoUrl.text = i.logoUrl;
    _splashUrl.text = i.splashUrl;
    _bannerHomeUrl.text = i.bannerHomeUrl;
    _splashEnabled = FirestoreTypedValue.toFirestoreBool(i.splashEnabled);
    _splashDuration.text = '${FirestoreTypedValue.toFirestoreInt(i.splashDurationSec, min: 1, max: 5)}';
  }

  @override
  void dispose() {
    _nombreGrupo.dispose();
    _radioLabel.dispose();
    _tvLabel.dispose();
    _logoUrl.dispose();
    _splashUrl.dispose();
    _bannerHomeUrl.dispose();
    _splashDuration.dispose();
    _flashInformativo.dispose();
    super.dispose();
  }


  bool get _isUploadingImage => _uploadingLogo || _uploadingSplash || _uploadingBanner;

  int _parseSplashDuration() {
    final n = int.tryParse(_splashDuration.text.trim());
    if (n == null) return 3;
    return n.clamp(1, 5);
  }

  Future<void> _uploadLogo(Uint8List bytes, String contentType) async {
    setState(() => _uploadingLogo = true);
    try {
      final downloadUrl = await _brandStorage.uploadBrandLogo(
        appId: widget.appId,
        bytes: bytes,
        contentType: contentType,
      );
      await widget.repository.updateBrandLogoUrl(
        appId: widget.appId,
        logoUrl: downloadUrl,
      );
      if (!mounted) return;
      _logoUrl.text = downloadUrl;
      widget.dataStore.patchAppInfo(widget.info.copyWith(logoUrl: downloadUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logotipo subido y guardado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir el logotipo: $e')),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _uploadSplash(Uint8List bytes, String contentType) async {
    setState(() => _uploadingSplash = true);
    try {
      final downloadUrl = await _brandStorage.uploadBrandSplash(
        appId: widget.appId,
        bytes: bytes,
        contentType: contentType,
      );
      await widget.repository.updateBrandSplashUrl(
        appId: widget.appId,
        splashUrl: downloadUrl,
      );
      if (!mounted) return;
      _splashUrl.text = downloadUrl;
      widget.dataStore.patchAppInfo(widget.info.copyWith(splashUrl: downloadUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Splash subido y guardado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir el splash: $e')),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _uploadingSplash = false);
    }
  }

  Future<void> _uploadBanner(Uint8List bytes, String contentType) async {
    setState(() => _uploadingBanner = true);
    try {
      final downloadUrl = await _brandStorage.uploadBrandBannerHome(
        appId: widget.appId,
        bytes: bytes,
        contentType: contentType,
      );
      await widget.repository.updateBrandBannerHomeUrl(
        appId: widget.appId,
        bannerHomeUrl: downloadUrl,
      );
      if (!mounted) return;
      _bannerHomeUrl.text = downloadUrl;
      widget.dataStore.patchAppInfo(widget.info.copyWith(bannerHomeUrl: downloadUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Banner subido y guardado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir el banner: $e')),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _save() async {
    final splashUrl = FirestoreTypedValue.toFirestoreString(_splashUrl.text);
    final bannerHomeUrl = FirestoreTypedValue.toFirestoreString(_bannerHomeUrl.text);
    final splashEnabled = FirestoreTypedValue.toFirestoreBool(_splashEnabled);
    final splashDurationSec = FirestoreTypedValue.toFirestoreInt(
      _parseSplashDuration(),
      min: 1,
      max: 5,
    );

    if (!UrlField.isValidOptionalImageUrl(splashUrl) || !UrlField.isValidOptionalImageUrl(bannerHomeUrl)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las URLs de publicidad deben empezar por http:// o https:// (o dejarse vacías).')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.updateBrandMasterSettings(
        appId: widget.appId,
        nombreGrupo: _nombreGrupo.text.trim(),
        radioLabel: _radioLabel.text.trim(),
        tvLabel: _tvLabel.text.trim(),
        logoUrl: _logoUrl.text.trim(),
        colorHex: widget.info.colorHex,
        splashUrl: splashUrl,
        bannerHomeUrl: bannerHomeUrl,
        splashEnabled: splashEnabled,
        splashDurationSec: splashDurationSec,
      );
      if (!mounted) return;
      widget.dataStore.patchAppInfo(
        widget.info.copyWith(
          nombreGrupo: _nombreGrupo.text.trim(),
          radioLabel: _radioLabel.text.trim(),
          tvLabel: _tvLabel.text.trim(),
          logoUrl: _logoUrl.text.trim(),
          colorHex: widget.info.colorHex,
          splashUrl: splashUrl,
          bannerHomeUrl: bannerHomeUrl,
          splashEnabled: splashEnabled,
          splashDurationSec: splashDurationSec,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _lanzarFlashInformativo() async {
    final texto = _flashInformativo.text.trim();
    if (texto.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un mensaje para el Avance Informativo.')),
      );
      return;
    }
    _flashInformativo.clear();
    if (mounted) setState(() => _lanzandoFlashInformativo = true);
    try {
      await widget.repository.sendFlashInformativo(
        appId: widget.appId,
        mensaje: texto,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avance Informativo enviado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      _flashInformativo.text = texto;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar el Avance Informativo: $e')));
    } finally {
      if (mounted) setState(() => _lanzandoFlashInformativo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, isMobile ? 12 : 16, isMobile ? 12 : 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajustes de Aplicación',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Configura la apariencia visual de tu aplicación.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configuración de marca', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Estos campos cambian textos y enlaces visibles en la app.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _nombreGrupo,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del grupo / marca',
                          helperText: 'Se muestra como título principal en la app.',
                          hintText: 'Ej. Grupo SIRA',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Botones de la pantalla principal',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _radioLabel,
                              decoration: const InputDecoration(
                                labelText: 'Texto del botón “Radio”',
                                helperText: 'Nombre del botón de Radio en la página principal.',
                                hintText: 'Ej. RADIO',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _tvLabel,
                              decoration: const InputDecoration(
                                labelText: 'Texto del botón “TV / Video”',
                                helperText: 'Nombre del botón de TV/Video en la página principal.',
                                hintText: 'Ej. TV',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Imagen de marca',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      BrandImageUploadZone(
                        uploading: _uploadingLogo,
                        currentImageUrl: _logoUrl.text,
                        onUpload: _uploadLogo,
                        uploadButtonLabel: 'Subir Logotipo',
                        uploadingLabel: 'Subiendo logotipo…',
                        emptyPreviewText: 'Aún no hay logo. Sube una imagen para previsualizarla.',
                        previewWidth: 72,
                        previewHeight: 72,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Publicidad (Splash / Banner)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Imágenes publicitarias mostradas en la app móvil al iniciar y en la pantalla principal.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Splash publicitario',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Imagen a pantalla completa al abrir la app.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      BrandImageUploadZone(
                        uploading: _uploadingSplash,
                        currentImageUrl: _splashUrl.text,
                        onUpload: _uploadSplash,
                        uploadButtonLabel: 'Subir Splash',
                        uploadingLabel: 'Subiendo splash…',
                        emptyPreviewText: 'Aún no hay splash. Sube una imagen para previsualizarla.',
                        previewHeight: 80,
                        previewFit: BoxFit.cover,
                        icon: Icons.fullscreen_outlined,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Banner Home',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Banner en la pantalla principal de la app.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      BrandImageUploadZone(
                        uploading: _uploadingBanner,
                        currentImageUrl: _bannerHomeUrl.text,
                        onUpload: _uploadBanner,
                        uploadButtonLabel: 'Subir Banner',
                        uploadingLabel: 'Subiendo banner…',
                        emptyPreviewText: 'Aún no hay banner. Sube una imagen para previsualizarla.',
                        previewHeight: 56,
                        previewFit: BoxFit.cover,
                        icon: Icons.view_day_outlined,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activar Splash publicitario'),
                        subtitle: Text(
                          'Si está desactivado, la app no mostrará el splash aunque haya URL.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        value: _splashEnabled,
                        onChanged: (v) => setState(() => _splashEnabled = FirestoreTypedValue.toFirestoreBool(v)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _splashDuration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duración del Splash (segundos)',
                          helperText: 'Máximo 5 segundos. Valor entre 1 y 5.',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        onChanged: (_) {
                          final n = int.tryParse(_splashDuration.text.trim());
                          if (n != null && n > 5 && mounted) {
                            _splashDuration.text = '5';
                            _splashDuration.selection = const TextSelection.collapsed(offset: 1);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _flashInformativo,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Enviar Avance Informativo a la App (Pop-up)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                            minimumSize: const Size(260, 56),
                          ),
                          onPressed: _lanzandoFlashInformativo ? null : _lanzarFlashInformativo,
                          child: _lanzandoFlashInformativo
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : const Text('Lanzar Avance Informativo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: (_saving || _isUploadingImage) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_saving ? 'Guardando…' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

