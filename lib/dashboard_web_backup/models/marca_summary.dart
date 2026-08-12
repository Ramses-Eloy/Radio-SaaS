/// Metadatos mínimos de `marcas/{appId}` para selector y escritura multi-tenant.
class MarcaSummary {
  const MarcaSummary({
    required this.id,
    required this.ownerEmail,
    this.nombreGrupo = '',
  });

  final String id;
  final String ownerEmail;
  final String nombreGrupo;

  String get displayLabel =>
      nombreGrupo.isNotEmpty ? '$nombreGrupo ($id)' : id;
}
