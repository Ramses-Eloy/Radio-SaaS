import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/utils/color_hex.dart';

/// Documento en `emisoras/{id}`.
class Emisora {
  const Emisora({
    required this.id,
    required this.ownerId,
    required this.nombre,
    required this.urlAudio,
    required this.urlVideo,
    required this.colorHex,
    this.colorSecundarioHex = '#35ACE5',
    required this.logoUrl,
    required this.isVideo,
    required this.mostrarProgramacion,
    required this.socialFacebook,
    required this.socialWhatsapp,
    required this.socialInstagram,
    required this.socialX,
    required this.telefonoCabina,
    required this.currentListeners,
    required this.adClicks,
    required this.playCount,
    this.statsUpdatedAt,
  });

  final String id;
  final String ownerId;
  final String nombre;
  final String urlAudio;
  final String urlVideo;
  final String colorHex;
  final String colorSecundarioHex;
  final String logoUrl;
  final bool isVideo;
  final bool mostrarProgramacion;
  final String socialFacebook;
  final String socialWhatsapp;
  final String socialInstagram;
  final String socialX;
  final String telefonoCabina;
  final int currentListeners;
  final int adClicks;
  final int playCount;
  final DateTime? statsUpdatedAt;

  factory Emisora.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final stats = d[EmisoraFields.stats] as Map<String, dynamic>? ?? {};
    final ts = stats['updatedAt'] as Timestamp?;

    final nombre = d[EmisoraFields.nombre] as String? ?? d['name'] as String? ?? 'Sin nombre';
    final ownerId = d[EmisoraFields.ownerId] as String? ?? d['ownerUid'] as String? ?? '';

    return Emisora(
      id: doc.id,
      ownerId: ownerId,
      nombre: nombre,
      urlAudio: d[EmisoraFields.urlAudio] as String? ?? '',
      urlVideo: d[EmisoraFields.urlVideo] as String? ?? '',
      colorHex: d[EmisoraFields.colorHex] as String? ?? ColorHex.defaultHex,
      colorSecundarioHex: d[EmisoraFields.colorSecundarioHex] as String? ?? d[EmisoraFields.colorHex] as String? ?? '#35ACE5',
      logoUrl: d[EmisoraFields.logoUrl] as String? ?? '',
      isVideo: d[EmisoraFields.isVideo] as bool? ?? false,
      mostrarProgramacion: d[EmisoraFields.mostrarProgramacion] as bool? ?? true,
      socialFacebook: d[EmisoraFields.socialFacebook] as String? ?? '',
      socialWhatsapp: d[EmisoraFields.socialWhatsapp] as String? ?? '',
      socialInstagram: d[EmisoraFields.socialInstagram] as String? ?? '',
      socialX: d[EmisoraFields.socialX] as String? ?? d['social_twitter'] as String? ?? '',
      telefonoCabina: d[EmisoraFields.telefonoCabina] as String? ?? '',
      currentListeners: (stats['currentListeners'] as num?)?.toInt() ?? 0,
      adClicks: (stats['adClicks'] as num?)?.toInt() ?? 0,
      playCount: (stats[EmisoraFields.statsPlayCount] as num?)?.toInt() ?? 0,
      statsUpdatedAt: ts?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'nombre': nombre,
        'urlAudio': urlAudio,
        'urlVideo': urlVideo,
        'colorHex': colorHex,
        'colorSecundarioHex': colorSecundarioHex,
        'logoUrl': logoUrl,
        'isVideo': isVideo,
        'mostrarProgramacion': mostrarProgramacion,
        'socialFacebook': socialFacebook,
        'socialWhatsapp': socialWhatsapp,
        'socialInstagram': socialInstagram,
        'socialX': socialX,
        'telefonoCabina': telefonoCabina,
        'currentListeners': currentListeners,
        'adClicks': adClicks,
        'playCount': playCount,
        'statsUpdatedAt': statsUpdatedAt?.toIso8601String(),
      };

  factory Emisora.fromJson(Map<String, dynamic> json) {
    return Emisora(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      urlAudio: json['urlAudio'] as String? ?? '',
      urlVideo: json['urlVideo'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? ColorHex.defaultHex,
      colorSecundarioHex: json['colorSecundarioHex'] as String? ?? json['colorHex'] as String? ?? '#35ACE5',
      logoUrl: json['logoUrl'] as String? ?? '',
      isVideo: json['isVideo'] as bool? ?? false,
      mostrarProgramacion: json['mostrarProgramacion'] as bool? ?? true,
      socialFacebook: json['socialFacebook'] as String? ?? '',
      socialWhatsapp: json['socialWhatsapp'] as String? ?? '',
      socialInstagram: json['socialInstagram'] as String? ?? '',
      socialX: json['socialX'] as String? ?? '',
      telefonoCabina: json['telefonoCabina'] as String? ?? '',
      currentListeners: (json['currentListeners'] as num?)?.toInt() ?? 0,
      adClicks: (json['adClicks'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      statsUpdatedAt: json['statsUpdatedAt'] != null ? DateTime.tryParse(json['statsUpdatedAt'] as String) : null,
    );
  }

  Emisora copyWith({
    String? id,
    String? ownerId,
    String? nombre,
    String? urlAudio,
    String? urlVideo,
    String? colorHex,
    String? colorSecundarioHex,
    String? logoUrl,
    bool? isVideo,
    bool? mostrarProgramacion,
    String? socialFacebook,
    String? socialWhatsapp,
    String? socialInstagram,
    String? socialX,
    String? telefonoCabina,
    int? currentListeners,
    int? adClicks,
    int? playCount,
    DateTime? statsUpdatedAt,
  }) {
    return Emisora(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      nombre: nombre ?? this.nombre,
      urlAudio: urlAudio ?? this.urlAudio,
      urlVideo: urlVideo ?? this.urlVideo,
      colorHex: colorHex ?? this.colorHex,
      colorSecundarioHex: colorSecundarioHex ?? this.colorSecundarioHex,
      logoUrl: logoUrl ?? this.logoUrl,
      isVideo: isVideo ?? this.isVideo,
      mostrarProgramacion: mostrarProgramacion ?? this.mostrarProgramacion,
      socialFacebook: socialFacebook ?? this.socialFacebook,
      socialWhatsapp: socialWhatsapp ?? this.socialWhatsapp,
      socialInstagram: socialInstagram ?? this.socialInstagram,
      socialX: socialX ?? this.socialX,
      telefonoCabina: telefonoCabina ?? this.telefonoCabina,
      currentListeners: currentListeners ?? this.currentListeners,
      adClicks: adClicks ?? this.adClicks,
      playCount: playCount ?? this.playCount,
      statsUpdatedAt: statsUpdatedAt ?? this.statsUpdatedAt,
    );
  }
}
