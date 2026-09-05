import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/utils/firestore_typed_value.dart';

/// Documento en `streamings/{id}`.
class Streaming {
  const Streaming({
    required this.id,
    required this.nombre,
    required this.urlVideo,
    required this.logoUrl,
    required this.colorHex,
    this.colorSecundarioHex = '#35ACE5',
    required this.playCount,
    this.statsUpdatedAt,
    this.mostrarEnCarrusel = false,
  });

  final String id;
  final String nombre;
  final String urlVideo;
  final String logoUrl;
  final String colorHex;
  final String colorSecundarioHex;
  final int playCount;
  final DateTime? statsUpdatedAt;
  final bool mostrarEnCarrusel;

  factory Streaming.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final stats = d[EmisoraFields.stats] as Map<String, dynamic>? ?? {};
    final ts = stats['updatedAt'] as Timestamp?;
    final nombre = d[EmisoraFields.nombre] as String? ?? d['name'] as String? ?? 'Sin nombre';

    return Streaming(
      id: doc.id,
      nombre: nombre,
      urlVideo: FirestoreTypedValue.toFirestoreString(d[EmisoraFields.urlVideo]),
      logoUrl: FirestoreTypedValue.toFirestoreString(d[EmisoraFields.logoUrl]),
      colorHex: FirestoreTypedValue.toFirestoreString(d[EmisoraFields.colorHex]),
      colorSecundarioHex: d[EmisoraFields.colorSecundarioHex] as String? ?? FirestoreTypedValue.toFirestoreString(d[EmisoraFields.colorHex]),
      playCount: (stats[EmisoraFields.statsPlayCount] as num?)?.toInt() ?? 0,
      statsUpdatedAt: ts?.toDate(),
      mostrarEnCarrusel: d[EmisoraFields.mostrarEnCarrusel] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'urlVideo': urlVideo,
        'logoUrl': logoUrl,
        'colorHex': colorHex,
        'colorSecundarioHex': colorSecundarioHex,
        'playCount': playCount,
        'statsUpdatedAt': statsUpdatedAt?.toIso8601String(),
        'mostrarEnCarrusel': mostrarEnCarrusel,
      };

  factory Streaming.fromJson(Map<String, dynamic> json) {
    return Streaming(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      urlVideo: json['urlVideo'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '',
      colorSecundarioHex: json['colorSecundarioHex'] as String? ?? json['colorHex'] as String? ?? '#35ACE5',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      statsUpdatedAt: json['statsUpdatedAt'] != null ? DateTime.tryParse(json['statsUpdatedAt'] as String) : null,
    );
  }

  Streaming copyWith({
    String? id,
    String? nombre,
    String? urlVideo,
    String? logoUrl,
    String? colorHex,
    String? colorSecundarioHex,
    int? playCount,
    DateTime? statsUpdatedAt,
    bool? mostrarEnCarrusel,
  }) {
    return Streaming(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      urlVideo: urlVideo ?? this.urlVideo,
      logoUrl: logoUrl ?? this.logoUrl,
      colorHex: colorHex ?? this.colorHex,
      colorSecundarioHex: colorSecundarioHex ?? this.colorSecundarioHex,
      playCount: playCount ?? this.playCount,
      statsUpdatedAt: statsUpdatedAt ?? this.statsUpdatedAt,
      mostrarEnCarrusel: mostrarEnCarrusel ?? this.mostrarEnCarrusel,
    );
  }
}
