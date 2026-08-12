/// Valida campos multi-tenant obligatorios antes de escribir en Firestore.
class TenantScope {
  const TenantScope({
    required this.appId,
    required this.ownerEmail,
  });

  final String appId;
  final String ownerEmail;

  static TenantScope require({
    required String? appId,
    required String? ownerEmail,
  }) {
    final normalizedAppId = appId?.trim() ?? '';
    final normalizedOwner = ownerEmail?.trim().toLowerCase() ?? '';
    if (normalizedAppId.isEmpty) {
      throw StateError('No hay appId de marca activo. Vuelva a iniciar sesión.');
    }
    if (normalizedOwner.isEmpty) {
      throw StateError('No se pudo identificar su marca. Vuelva a iniciar sesión o contacte con soporte.');
    }
    return TenantScope(appId: normalizedAppId, ownerEmail: normalizedOwner);
  }
}
