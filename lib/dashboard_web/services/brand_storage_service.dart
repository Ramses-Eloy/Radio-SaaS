import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Subida de activos de marca en Firebase Storage (rutas white-label fijas).
class BrandStorageService {
  BrandStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const _allowedMimeTypes = {'image/png', 'image/jpeg'};
  static const _maxBytes = 5 * 1024 * 1024;

  /// Ruta estricta: `marcas/{appId}/logo.png`.
  static String brandLogoPath(String appId) => 'marcas/$appId/logo.png';

  /// Ruta estricta: `marcas/{appId}/splash.png`.
  static String brandSplashPath(String appId) => 'marcas/$appId/splash.png';

  /// Ruta estricta: `marcas/{appId}/banner_home.png`.
  static String brandBannerHomePath(String appId) => 'marcas/$appId/banner_home.png';

  /// Ruta estricta: `emisoras/{appId}/{emisoraId}/logo.png`.
  static String emisoraLogoPath(String appId, String emisoraId) =>
      'emisoras/$appId/$emisoraId/logo.png';

  /// Ruta estricta: `streamings/{appId}/{streamingId}/logo.png`.
  static String streamingLogoPath(String appId, String streamingId) =>
      'streamings/$appId/$streamingId/logo.png';

  /// Ruta estricta: `streamings/{appId}/{streamingId}/logo_carrusel.png`.
  static String streamingLogoCarruselPath(String appId, String streamingId) =>
      'streamings/$appId/$streamingId/logo_carrusel.png';

  Future<String> uploadBrandLogo({
    required String appId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _uploadImage(
      storagePath: brandLogoPath(appId),
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> uploadBrandSplash({
    required String appId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _uploadImage(
      storagePath: brandSplashPath(appId),
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> uploadBrandBannerHome({
    required String appId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _uploadImage(
      storagePath: brandBannerHomePath(appId),
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> uploadEmisoraLogo({
    required String appId,
    required String emisoraId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _uploadImage(
      storagePath: emisoraLogoPath(appId, emisoraId),
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> uploadStreamingLogo({
    required String appId,
    required String streamingId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _uploadImage(
      storagePath: streamingLogoPath(appId, streamingId),
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> uploadStreamingLogoCarrusel({
    required String appId,
    required String streamingId,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _uploadImage(
      storagePath: streamingLogoCarruselPath(appId, streamingId),
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> _uploadImage({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!_allowedMimeTypes.contains(contentType)) {
      throw ArgumentError('Solo se permiten imágenes PNG o JPG.');
    }
    if (bytes.length > _maxBytes) {
      throw ArgumentError('La imagen no puede superar 5 MB.');
    }

    final ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  /// Resuelve el MIME a partir de la extensión del archivo seleccionado.
  static String? mimeTypeForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return null;
    }
  }
}
