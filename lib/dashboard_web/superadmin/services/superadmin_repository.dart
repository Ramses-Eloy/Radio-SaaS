import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../models/app_features.dart';

/// Repositorio exclusivo del SuperAdmin para gestionar marcas / tenants.
/// Maneja lectura global de marcas, actualización de módulos y alta automatizada.
class SuperAdminRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Public accessor for Firestore (used by callers that need direct updates after creation).
  FirebaseFirestore get db => _db;

  /// Correo del SuperAdmin con acceso total.
  static const String superAdminEmail = 'rsarsanedasg@gmail.com';

  /// Verifica si un correo es el SuperAdmin.
  static bool isSuperAdmin(String? email) {
    if (email == null) return false;
    return email.trim().toLowerCase() == superAdminEmail;
  }

  // ─────────────────────────────────────────────
  // LECTURA
  // ─────────────────────────────────────────────

  /// Obtiene la lista completa de todas las marcas registradas en el SaaS.
  /// Devuelve documentos raw de `marcas` para consumir en la tabla del SuperAdmin.
  Future<List<MarcaRecord>> fetchAllMarcas() async {
    final snap = await _db.collection('marcas').get();
    return snap.docs.map((doc) => MarcaRecord.fromFirestore(doc)).toList();
  }

  /// Stream en tiempo real de todas las marcas (para actualizaciones live en la tabla).
  Stream<List<MarcaRecord>> streamAllMarcas() {
    return _db.collection('marcas').snapshots().map((snap) {
      return snap.docs.map((doc) => MarcaRecord.fromFirestore(doc)).toList();
    });
  }

  // ─────────────────────────────────────────────
  // ACTUALIZACIÓN DE MÓDULOS
  // ─────────────────────────────────────────────

  /// Actualiza los feature flags de una marca específica en Firestore.
  Future<void> updateMarcaFeatures(String appId, AppFeatures features) async {
    await _db.collection('marcas').doc(appId).set({
      'features': features.toMap(),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────
  // ALTA AUTOMATIZADA DE NUEVA MARCA
  // ─────────────────────────────────────────────

  /// Crea una nueva marca completa en Firebase:
  /// 1. Documento en `marcas/{appId}` con configuración estándar y features.
  /// 2. Documento inicial en `emisoras` con todos los campos pre-rellenados.
  /// 3. Usuario en Firebase Auth con email y contraseña.
  ///
  /// Retorna `null` si fue exitoso, o un `String` con el mensaje de error.
  Future<String?> createNewMarca({
    required String appId,
    required String nombreGrupo,
    required String ownerEmail,
    required String password,
    required AppFeatures features,
  }) async {
    final normalizedAppId = appId.trim().toLowerCase();
    final normalizedEmail = ownerEmail.trim().toLowerCase();

    try {
      // Llamar a la Cloud Function `createBrand`
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('createBrand');
      
      final result = await callable.call({
        'appId': normalizedAppId,
        'nombreGrupo': nombreGrupo,
        'ownerEmail': normalizedEmail,
        'password': password,
        'features': features.toMap(),
      });
      
      if (result.data['success'] == true) {
        return null; // Éxito
      } else {
        return 'Error inesperado del servidor al crear la marca.';
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        return 'Ya existe una marca con el identificador "$normalizedAppId".';
      }
      return 'Error [${e.code}]: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  // ─────────────────────────────────────────────
  // EDICIÓN DE MARCA
  // ─────────────────────────────────────────────

  /// Actualiza los datos editables de una marca existente.
  Future<void> updateMarcaDetails({
    required String appId,
    required String currentEmail, // email actual de la marca, para buscar el Auth User
    String? nombreGrupo,
    String? newOwnerEmail,
    String? newPassword,
    bool? active,
  }) async {
    // 1. Actualizar en Firebase Auth mediante Cloud Function (solo si cambia correo o contraseña)
    if (newOwnerEmail != null || (newPassword != null && newPassword.trim().isNotEmpty)) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('updateUserCredentials');
        await callable.call({
          'appId': appId,
          'currentEmail': currentEmail,
          'newEmail': newOwnerEmail,
          'newPassword': newPassword,
        });
      } catch (e) {
        throw Exception('Error actualizando credenciales en Auth: $e');
      }
    }

    final batch = _db.batch();

    // 2. Actualizar marca
    final updates = <String, dynamic>{};
    if (nombreGrupo != null) updates['nombre_grupo'] = nombreGrupo;
    if (active != null) updates['active'] = active;
    
    if (updates.isNotEmpty) {
      batch.set(_db.collection('marcas').doc(appId), updates, SetOptions(merge: true));
    }



    await batch.commit();
  }

  /// Actualiza la contraseña de un usuario por su email.
  /// Nota: Esto requiere Firebase Admin SDK en backend, por lo que en el frontend
  /// usamos el flujo de reset de contraseña por correo.
  Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  /// Elimina una marca y todos sus documentos asociados (emisoras, streamings, programación).
  Future<void> deleteMarca(String appId) async {
    final batch = _db.batch();

    // Eliminar marca
    batch.delete(_db.collection('marcas').doc(appId));

    // Eliminar emisoras asociadas
    final emisoras = await _db.collection('emisoras').where('appId', isEqualTo: appId).get();
    for (final doc in emisoras.docs) {
      batch.delete(doc.reference);
      // Eliminar programación de cada emisora
      final progDoc = _db.collection('programacion').doc(doc.id);
      batch.delete(progDoc);
    }

    // Eliminar streamings asociados
    final streamings = await _db.collection('streamings').where('appId', isEqualTo: appId).get();
    for (final doc in streamings.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // GESTIÓN DE EMISORAS (RADIOS)
  // ─────────────────────────────────────────────

  Stream<List<SuperAdminEmisoraRecord>> streamEmisoras(String appId) {
    return _db.collection('emisoras').where('appId', isEqualTo: appId).snapshots().map((snap) {
      return snap.docs.map((doc) => SuperAdminEmisoraRecord.fromFirestore(doc)).toList();
    });
  }

  Future<String> _getNextSequentialId(String collection, String appId) async {
    final snapshot = await _db.collection(collection).where('appId', isEqualTo: appId).get();
    int maxSuffix = 0;
    for (final doc in snapshot.docs) {
      final parts = doc.id.split('_');
      if (parts.length > 1) {
        final suffix = int.tryParse(parts.last);
        if (suffix != null && suffix > maxSuffix) {
          maxSuffix = suffix;
        }
      }
    }
    return '${appId}_${maxSuffix + 1}';
  }

  Future<String> _getNextStreamingId(String appId) async {
    final snapshot = await _db.collection('streamings').where('appId', isEqualTo: appId).get();
    if (snapshot.docs.isEmpty) {
      return '${appId}_live';
    }
    int maxSuffix = 1;
    for (final doc in snapshot.docs) {
      final parts = doc.id.split('_live');
      if (parts.length > 1) {
        final suffixStr = parts.last;
        if (suffixStr.isEmpty) {
          if (1 > maxSuffix) maxSuffix = 1;
        } else {
          final suffix = int.tryParse(suffixStr);
          if (suffix != null && suffix > maxSuffix) {
            maxSuffix = suffix;
          }
        }
      }
    }
    return '${appId}_live${maxSuffix + 1}';
  }

  Future<String> createEmisora({
    required String appId,
    required String ownerEmail,
    required String nombre,
    required String urlAudio,
    String logoUrl = '',
    String colorHex = '#205CC6',
    String colorSecundarioHex = '#35ACE5',
    bool mostrarProgramacion = false,
    String telefonoCabina = '',
    String socialWhatsapp = '',
    String socialFacebook = '',
    String socialInstagram = '',
    String socialX = '',
  }) async {
    final newId = await _getNextSequentialId('emisoras', appId);
    final docRef = _db.collection('emisoras').doc(newId);
    
    await docRef.set({
      'appId': appId,
      'ownerEmail': ownerEmail,
      'nombre': nombre,
      'slogan': '',
      'logo_url': logoUrl,
      'color_hex': colorHex,
      'color_secundario_hex': colorSecundarioHex,
      'mostrar_programacion': mostrarProgramacion,
      'isVideo': false,
      'url_audio': urlAudio,
      'url_video': '',
      'telefono_cabina': telefonoCabina,
      'social_whatsapp': socialWhatsapp,
      'social_facebook': socialFacebook,
      'social_instagram': socialInstagram,
      'social_x': socialX,
      'social_tiktok': '',
      'youtube_url': '',
      'created_at': FieldValue.serverTimestamp(),
    });
    
    return newId;
  }

  Future<void> deleteEmisora(String id) async {
    await _db.collection('emisoras').doc(id).delete();
  }

  // ─────────────────────────────────────────────
  // GESTIÓN DE STREAMINGS (TV)
  // ─────────────────────────────────────────────

  Stream<List<SuperAdminStreamingRecord>> streamStreamings(String appId) {
    return _db.collection('streamings').where('appId', isEqualTo: appId).snapshots().map((snap) {
      return snap.docs.map((doc) => SuperAdminStreamingRecord.fromFirestore(doc)).toList();
    });
  }

  Future<String> createStreaming({
    required String appId,
    required String ownerEmail,
    required String nombre,
    required String urlVideo,
    String logoUrl = '',
    String colorHex = '#10B981',
  }) async {
    final newId = await _getNextStreamingId(appId);
    final docRef = _db.collection('streamings').doc(newId);
    
    await docRef.set({
      'appId': appId,
      'ownerEmail': ownerEmail,
      'nombre': nombre,
      'url_video': urlVideo,
      'logo_url': logoUrl,
      'color_hex': colorHex,
      'color_secundario_hex': '#059669',
      'created_at': FieldValue.serverTimestamp(),
    });

    return newId;
  }

  Future<void> deleteStreaming(String id) async {
    await _db.collection('streamings').doc(id).delete();
  }
}

/// Modelo de datos para representar una marca/tenant en la tabla del SuperAdmin.
class MarcaRecord {
  final String appId;
  final String nombreGrupo;
  final String ownerEmail;
  final String logoUrl;
  final String colorHex;
  final AppFeatures features;
  final bool active;
  final DateTime? createdAt;

  const MarcaRecord({
    required this.appId,
    required this.nombreGrupo,
    required this.ownerEmail,
    required this.logoUrl,
    required this.colorHex,
    required this.features,
    required this.active,
    this.createdAt,
  });

  /// Determina el nombre del plan basándose en las features activas.
  String get planLabel {
    if (features.enableTv && features.enableSchedule && features.enableMultiStation) {
      return 'Full Suite';
    }
    return 'Solo Player';
  }

  factory MarcaRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['created_at'];
    DateTime? created;
    if (ts is Timestamp) {
      created = ts.toDate();
    }

    return MarcaRecord(
      appId: doc.id,
      nombreGrupo: data['nombre_grupo'] as String? ?? doc.id,
      ownerEmail: (data['ownerEmail'] as String? ?? '').trim().toLowerCase(),
      logoUrl: data['logo_url'] as String? ?? '',
      colorHex: data['color_hex'] as String? ?? '#205CC6',
      features: AppFeatures.fromMap(data),
      active: data['active'] as bool? ?? true,
      createdAt: created,
    );
  }
}

/// Modelo ligero para emisoras (Radios) en el Super Admin
class SuperAdminEmisoraRecord {
  final String id;
  final String appId;
  final String nombre;
  final String urlAudio;
  final bool isVideo;

  const SuperAdminEmisoraRecord({
    required this.id,
    required this.appId,
    required this.nombre,
    required this.urlAudio,
    required this.isVideo,
  });

  factory SuperAdminEmisoraRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SuperAdminEmisoraRecord(
      id: doc.id,
      appId: data['appId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      urlAudio: data['url_audio'] as String? ?? '',
      isVideo: data['isVideo'] as bool? ?? false,
    );
  }
}

/// Modelo ligero para streamings (TV) en el Super Admin
class SuperAdminStreamingRecord {
  final String id;
  final String appId;
  final String nombre;
  final String urlVideo;
  final bool isVideo;

  const SuperAdminStreamingRecord({
    required this.id,
    required this.appId,
    required this.nombre,
    required this.urlVideo,
    required this.isVideo,
  });

  factory SuperAdminStreamingRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SuperAdminStreamingRecord(
      id: doc.id,
      appId: data['appId'] as String? ?? '',
      nombre: data['nombre'] as String? ?? 'Sin nombre',
      urlVideo: data['url_video'] as String? ?? '',
      isVideo: data['isVideo'] as bool? ?? true,
    );
  }
}
