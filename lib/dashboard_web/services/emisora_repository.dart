import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/utils/firestore_typed_value.dart';
import 'package:radio_whitelabel/dashboard_web/utils/tenant_scope.dart';

class EmisoraRepository {
  EmisoraRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  String _normalizeEmail(String ownerEmail) => ownerEmail.trim().toLowerCase();

  Query<Map<String, dynamic>> _contentQueryForClient({
    required String collection,
    required String appId,
    required String ownerEmail,
  }) {
    return _db
        .collection(collection)
        .where(EmisoraFields.appId, isEqualTo: appId)
        .where(EmisoraFields.ownerEmail, isEqualTo: _normalizeEmail(ownerEmail));
  }

  /// Busca en `marcas` el documento cuyo `ownerEmail` coincide con el usuario.
  Future<String?> resolveAppIdForOwner({required String ownerEmail}) async {
    final snap = await _db
        .collection(EmisoraFields.marcasCollection)
        .where(EmisoraFields.ownerEmail, isEqualTo: _normalizeEmail(ownerEmail))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Documento de configuración global en `marcas/{appId}`.
  Future<DocumentSnapshot<Map<String, dynamic>>?> fetchMarcaDoc({
    required String ownerEmail,
    required String appId,
  }) async {
    final doc = await _db.collection(EmisoraFields.marcasCollection).doc(appId).get();
    if (!doc.exists) return null;

    final normalized = _normalizeEmail(ownerEmail);
    final owner = doc.data()?[EmisoraFields.ownerEmail] as String?;
    if (owner != null && owner.toLowerCase() != normalized) return null;
    return doc;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchEmisorasDocsForClient({
    required String ownerEmail,
    required String appId,
  }) async {
    final snap = await _contentQueryForClient(
      collection: EmisoraFields.collection,
      ownerEmail: ownerEmail,
      appId: appId,
    ).get();
    return snap.docs;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEmisorasDocsForClient({
    required String ownerEmail,
    required String appId,
  }) {
    return _contentQueryForClient(
      collection: EmisoraFields.collection,
      ownerEmail: ownerEmail,
      appId: appId,
    ).snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchStreamingsDocsForClient({
    required String ownerEmail,
    required String appId,
  }) async {
    final snap = await _contentQueryForClient(
      collection: EmisoraFields.streamingsCollection,
      ownerEmail: ownerEmail,
      appId: appId,
    ).get();
    return snap.docs;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStreamingsDocsForClient({
    required String ownerEmail,
    required String appId,
  }) {
    return _contentQueryForClient(
      collection: EmisoraFields.streamingsCollection,
      ownerEmail: ownerEmail,
      appId: appId,
    ).snapshots();
  }

  Future<void> patchDocFields(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _db.collection(collection).doc(docId).update(data);
  }

  Future<void> mergeDocFields(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _db.collection(collection).doc(docId).set(data, SetOptions(merge: true));
  }

  Future<void> updateEmisoraFields(
    String emisoraId,
    Map<String, dynamic> data, {
    required String appId,
  }) {
    return patchDocFields(
      EmisoraFields.collection,
      emisoraId,
      {
        EmisoraFields.appId: appId,
        ...data,
      },
    );
  }

  /// Crea una emisora con `appId` y `ownerEmail` de la marca activa.
  Future<String> createEmisora({
    required String ownerEmail,
    required String appId,
    required Map<String, dynamic> data,
  }) async {
    final tenant = TenantScope.require(appId: appId, ownerEmail: ownerEmail);
    final ref = _db.collection(EmisoraFields.collection).doc();
    await ref.set({
      EmisoraFields.ownerEmail: tenant.ownerEmail,
      EmisoraFields.appId: tenant.appId,
      ...data,
    });
    return ref.id;
  }

  Future<void> sendFlashInformativo({
    required String appId,
    required String mensaje,
  }) {
    final idAlerta = 'fi_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    return patchDocFields(
      EmisoraFields.marcasCollection,
      appId,
      {
        EmisoraFields.flashInformativo: {
          EmisoraFields.appId: appId,
          EmisoraFields.flashInformativoMensaje: mensaje,
          EmisoraFields.flashInformativoTimestamp: FieldValue.serverTimestamp(),
          EmisoraFields.flashInformativoId: idAlerta,
        },
      },
    );
  }

  /// Actualiza solo `logo_url` (y su marca de tiempo) en `marcas/{appId}`.
  Future<void> updateBrandLogoUrl({
    required String appId,
    required String logoUrl,
  }) {
    return patchDocFields(
      EmisoraFields.marcasCollection,
      appId,
      {
        EmisoraFields.logoUrl: logoUrl,
        EmisoraFields.logoUrlUpdatedAt: FieldValue.serverTimestamp(),
      },
    );
  }

  /// Actualiza solo `splash_url` en `marcas/{appId}`.
  Future<void> updateBrandSplashUrl({
    required String appId,
    required String splashUrl,
  }) {
    return patchDocFields(
      EmisoraFields.marcasCollection,
      appId,
      {
        EmisoraFields.splashUrl: splashUrl,
      },
    );
  }

  /// Actualiza solo `banner_home_url` en `marcas/{appId}`.
  Future<void> updateBrandBannerHomeUrl({
    required String appId,
    required String bannerHomeUrl,
  }) {
    return patchDocFields(
      EmisoraFields.marcasCollection,
      appId,
      {
        EmisoraFields.bannerHomeUrl: bannerHomeUrl,
      },
    );
  }

  Future<void> updateBrandMasterSettings({
    required String appId,
    required String nombreGrupo,
    required String radioLabel,
    required String tvLabel,
    required String scheduleLabel,
    required String logoUrl,
    required String colorHex,
    required String splashUrl,
    required String bannerHomeUrl,
    required bool splashEnabled,
    required int splashDurationSec,
  }) {
    final advertising = FirestoreTypedValue.brandAdvertisingFields(
      splashUrl: splashUrl,
      bannerHomeUrl: bannerHomeUrl,
      splashEnabled: splashEnabled,
      splashDurationSec: splashDurationSec,
    );

    return patchDocFields(
      EmisoraFields.marcasCollection,
      appId,
      {
        EmisoraFields.appId: appId,
        EmisoraFields.nombreGrupo: nombreGrupo,
        EmisoraFields.radioLabel: radioLabel,
        EmisoraFields.tvLabel: tvLabel,
        EmisoraFields.scheduleLabel: scheduleLabel,
        EmisoraFields.logoUrl: logoUrl,
        EmisoraFields.colorHex: colorHex,
        EmisoraFields.logoUrlUpdatedAt: FieldValue.serverTimestamp(),
        ...advertising,
      },
    );
  }

  Future<void> updateStreamingFields(
    String streamingId,
    Map<String, dynamic> data, {
    required String appId,
  }) {
    return patchDocFields(
      EmisoraFields.streamingsCollection,
      streamingId,
      {
        EmisoraFields.appId: appId,
        EmisoraFields.isVideo: true,
        ...data,
      },
    );
  }

  Future<String> createStreaming({
    required String ownerEmail,
    required String appId,
    required Map<String, dynamic> data,
  }) async {
    final tenant = TenantScope.require(appId: appId, ownerEmail: ownerEmail);
    final ref = _db.collection(EmisoraFields.streamingsCollection).doc();
    await ref.set({
      EmisoraFields.ownerEmail: tenant.ownerEmail,
      EmisoraFields.appId: tenant.appId,
      EmisoraFields.isVideo: true,
      ...data,
    });
    return ref.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProgramacionDoc({
    required String targetId,
    required String appId,
  }) {
    return _db
        .collection(EmisoraFields.programacionCollection)
        .doc(targetId)
        .snapshots()
        .where((snap) {
          if (!snap.exists) return true;
          final docAppId = snap.data()?[EmisoraFields.appId] as String?;
          return docAppId == null || docAppId == appId;
        });
  }

  /// Guarda un único documento `programacion/{targetId}` con listas por día.
  Future<void> saveProgramacionTexto({
    required String ownerEmail,
    required String appId,
    required String targetId,
    required List<Map<String, dynamic>> lunes,
    required List<Map<String, dynamic>> martes,
    required List<Map<String, dynamic>> miercoles,
    required List<Map<String, dynamic>> jueves,
    required List<Map<String, dynamic>> viernes,
    required List<Map<String, dynamic>> sabado,
    required List<Map<String, dynamic>> domingo,
  }) {
    final tenant = TenantScope.require(appId: appId, ownerEmail: ownerEmail);
    final docId = targetId.trim();
    if (docId.isEmpty) {
      throw StateError('targetId vacío: no se puede guardar la programación.');
    }

    final payload = <String, dynamic>{
      EmisoraFields.ownerEmail: tenant.ownerEmail,
      EmisoraFields.appId: tenant.appId,
      EmisoraFields.targetId: docId,
      EmisoraFields.lunes: lunes,
      EmisoraFields.martes: martes,
      EmisoraFields.miercoles: miercoles,
      EmisoraFields.jueves: jueves,
      EmisoraFields.viernes: viernes,
      EmisoraFields.sabado: sabado,
      EmisoraFields.domingo: domingo,
      EmisoraFields.ultimaActualizacion: FieldValue.serverTimestamp(),
    };

    return _db
        .collection(EmisoraFields.programacionCollection)
        .doc(docId)
        .set(payload, SetOptions(merge: true));
  }
}
