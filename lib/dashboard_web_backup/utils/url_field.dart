/// Normaliza URLs de imagen para Firestore (string vacío o http/https).
abstract final class UrlField {
  static String normalize(String raw) => raw.trim();

  static bool isValidOptionalImageUrl(String value) {
    if (value.isEmpty) return true;
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
