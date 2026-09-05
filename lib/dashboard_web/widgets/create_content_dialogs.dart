import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/utils/color_hex.dart';
import 'package:radio_whitelabel/dashboard_web/utils/tenant_scope.dart';

/// Diálogos de alta con [appId] y [ownerEmail] de la sesión activa.
abstract final class CreateContentDialogs {
  static Future<String?> showCreateEmisora({
    required BuildContext context,
    required EmisoraRepository repository,
    required ClientDataStore dataStore,
  }) async {
    final TenantScope tenant;
    try {
      tenant = dataStore.requireTenant();
    } catch (e) {
      _snack(context, e.toString());
      return null;
    }

    final nombreCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva emisora'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre de la emisora',
              hintText: 'Ej. Radio Principal',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Indique un nombre.';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
          }, child: const Text('Crear')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      nombreCtrl.dispose();
      return null;
    }

    try {
      final nombre = nombreCtrl.text.trim();
      final id = await repository.createEmisora(
        ownerEmail: tenant.ownerEmail,
        appId: tenant.appId,
        data: {
          EmisoraFields.nombre: nombre,
          EmisoraFields.urlAudio: '',
          EmisoraFields.urlVideo: '',
          EmisoraFields.colorHex: ColorHex.defaultHex,
          EmisoraFields.logoUrl: '',
          EmisoraFields.isVideo: false,
          EmisoraFields.mostrarProgramacion: true,
          EmisoraFields.socialFacebook: '',
          EmisoraFields.socialWhatsapp: '',
          EmisoraFields.socialInstagram: '',
          EmisoraFields.socialX: '',
          EmisoraFields.telefonoCabina: '',
        },
      );
      dataStore.addEmisora(
        Emisora(
          id: id,
          ownerId: '',
          nombre: nombre,
          urlAudio: '',
          urlVideo: '',
          colorHex: ColorHex.defaultHex,
          logoUrl: '',
          isVideo: false,
          mostrarProgramacion: true,
          socialFacebook: '',
          socialWhatsapp: '',
          socialInstagram: '',
          socialX: '',
          telefonoCabina: '',
          currentListeners: 0,
          adClicks: 0,
          playCount: 0,
        ),
      );
      if (context.mounted) {
        _snack(context, 'Emisora creada correctamente.');
      }
      nombreCtrl.dispose();
      return id;
    } catch (e) {
      if (context.mounted) _snack(context, 'No se pudo crear: $e');
      nombreCtrl.dispose();
      return null;
    }
  }

  static Future<String?> showCreateStreaming({
    required BuildContext context,
    required EmisoraRepository repository,
    required ClientDataStore dataStore,
  }) async {
    final TenantScope tenant;
    try {
      tenant = dataStore.requireTenant();
    } catch (e) {
      _snack(context, e.toString());
      return null;
    }

    final nombreCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo canal TV'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del canal',
              hintText: 'Ej. TV En Vivo',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Indique un nombre.';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
          }, child: const Text('Crear')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      nombreCtrl.dispose();
      return null;
    }

    try {
      final nombre = nombreCtrl.text.trim();
      final id = await repository.createStreaming(
        ownerEmail: tenant.ownerEmail,
        appId: tenant.appId,
        data: {
          EmisoraFields.nombre: nombre,
          EmisoraFields.urlVideo: '',
          EmisoraFields.logoUrl: '',
        },
      );
      dataStore.addStreaming(
        Streaming(
          id: id,
          nombre: nombre,
          urlVideo: '',
          logoUrl: '',
          colorHex: '',
          playCount: 0,
        ),
      );
      if (context.mounted) {
        _snack(context, 'Canal creado correctamente.');
      }
      nombreCtrl.dispose();
      return id;
    } catch (e) {
      if (context.mounted) _snack(context, 'No se pudo crear: $e');
      nombreCtrl.dispose();
      return null;
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
