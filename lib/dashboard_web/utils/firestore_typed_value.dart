import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';

/// Coerción de tipos para campos que la app móvil lee con tipos estrictos (bool/int).
abstract final class FirestoreTypedValue {
  /// Texto sin espacios al inicio/final.
  static String toFirestoreString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  /// Booleano nativo de Dart (nunca String "true"/"false" en Firestore).
  static bool toFirestoreBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final s = value.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'si' || s == 'sí') return true;
      if (s == 'false' || s == '0' || s == 'no' || s.isEmpty) return false;
    }
    if (value is num) return value != 0;
    return fallback;
  }

  /// Entero nativo de Dart (1–5 para duración del splash).
  static int toFirestoreInt(
    dynamic value, {
    required int min,
    required int max,
    int fallback = 3,
  }) {
    int n;
    if (value is int) {
      n = value;
    } else if (value is num) {
      n = value.round();
    } else if (value is String) {
      n = int.tryParse(value.trim()) ?? fallback;
    } else {
      n = fallback;
    }
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  /// Payload de publicidad con tipos garantizados para `marcas/{appId}`.
  /// [bannerHomeUrl] vacío se persiste como `banner_home_url: ""` (no se omite el campo).
  static Map<String, Object?> brandAdvertisingFields({
    required String splashUrl,
    required String bannerHomeUrl,
    required bool splashEnabled,
    required int splashDurationSec,
  }) {
    assert(EmisoraFields.bannerHomeUrl == 'banner_home_url');
    final banner = toFirestoreString(bannerHomeUrl);
    return {
      EmisoraFields.splashUrl: toFirestoreString(splashUrl),
      EmisoraFields.bannerHomeUrl: banner,
      EmisoraFields.splashEnabled: toFirestoreBool(splashEnabled),
      EmisoraFields.splashDurationSec: toFirestoreInt(
        splashDurationSec,
        min: 1,
        max: 5,
      ),
    };
  }
}
