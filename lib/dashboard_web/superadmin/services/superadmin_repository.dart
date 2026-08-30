import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/app_features.dart';

/// Repositorio exclusivo del SuperAdmin para gestionar marcas / tenants.
/// Maneja lectura global de marcas, actualización de módulos y alta automatizada.
class SuperAdminRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

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

    // Validar que el appId no exista
    final existing = await _db.collection('marcas').doc(normalizedAppId).get();
    if (existing.exists) {
      return 'Ya existe una marca con el identificador "$normalizedAppId".';
    }

    try {
      // 1. Crear documento en `marcas/{appId}`
      await _db.collection('marcas').doc(normalizedAppId).set({
        'appId': normalizedAppId,
        'nombre_grupo': nombreGrupo,
        'ownerEmail': normalizedEmail,
        'logo_url': '',
        'color_hex': '#205CC6',
        'splash_url': '',
        'banner_home_url': '',
        'splash_enabled': true,
        'splash_duration_sec': 5,
        'radio_label': 'En Vivo',
        'tv_label': 'Video Live',
        'schedule_label': 'Programación',
        'features': features.toMap(),
        'created_at': FieldValue.serverTimestamp(),
        'active': true,
      });

      // 2. Crear emisora inicial en `emisoras` con todos los campos estándar
      final emisoraRef = _db.collection('emisoras').doc('${normalizedAppId}_1');
      await emisoraRef.set({
        'appId': normalizedAppId,
        'ownerEmail': normalizedEmail,
        'nombre': nombreGrupo,
        'slogan': 'La mejor música',
        'logo_url': '',
        'color_hex': '#205CC6',
        'color_secundario_hex': '#35ACE5',
        'mostrar_programacion': features.enableSchedule,
        'url_audio': '',
        'url_video': '',
        'telefono_cabina': '',
        'social_whatsapp': '',
        'social_facebook': '',
        'social_instagram': '',
        'social_x': '',
        'social_tiktok': '',
      });

      // 3. Crear usuario en Firebase Auth
      // Nota: Esto requiere que el proyecto tenga habilitada la autenticación
      // por email/password. Si ya existe el usuario, se captura el error.
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        // Cerrar la sesión recién creada para mantener al SuperAdmin logueado
        // Firebase Auth automáticamente loguea al usuario recién creado,
        // así que necesitamos re-autenticar al SuperAdmin
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // El usuario ya existe en Auth, no es un error fatal
        } else {
          // Revertir documentos creados si falla Auth
          await _db.collection('marcas').doc(normalizedAppId).delete();
          await emisoraRef.delete();
          return 'Error al crear el usuario: ${e.message}';
        }
      }

      return null; // Éxito
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
    String? nombreGrupo,
    String? ownerEmail,
    bool? active,
  }) async {
    final updates = <String, dynamic>{};
    if (nombreGrupo != null) updates['nombre_grupo'] = nombreGrupo;
    if (ownerEmail != null) updates['ownerEmail'] = ownerEmail.trim().toLowerCase();
    if (active != null) updates['active'] = active;
    if (updates.isNotEmpty) {
      await _db.collection('marcas').doc(appId).set(updates, SetOptions(merge: true));
    }
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
