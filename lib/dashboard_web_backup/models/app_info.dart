import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/utils/firestore_typed_value.dart';

class AppInfo {
  const AppInfo({
    required this.id,
    required this.nombreGrupo,
    required this.radioLabel,
    required this.tvLabel,
    required this.logoUrl,
    required this.colorHex,
    required this.splashUrl,
    required this.bannerHomeUrl,
    required this.splashEnabled,
    required this.splashDurationSec,
  });

  final String id;
  final String nombreGrupo;
  final String radioLabel;
  final String tvLabel;
  final String logoUrl;
  final String colorHex;
  final String splashUrl;
  final String bannerHomeUrl;
  final bool splashEnabled;
  final int splashDurationSec;

  factory AppInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppInfo(
      id: doc.id,
      nombreGrupo: d[EmisoraFields.nombreGrupo] as String? ?? '',
      radioLabel: d[EmisoraFields.radioLabel] as String? ?? '',
      tvLabel: d[EmisoraFields.tvLabel] as String? ?? '',
      logoUrl: d[EmisoraFields.logoUrl] as String? ?? '',
      colorHex: d[EmisoraFields.colorHex] as String? ?? '',
      splashUrl: FirestoreTypedValue.toFirestoreString(d[EmisoraFields.splashUrl]),
      bannerHomeUrl: FirestoreTypedValue.toFirestoreString(d[EmisoraFields.bannerHomeUrl]),
      splashEnabled: FirestoreTypedValue.toFirestoreBool(d[EmisoraFields.splashEnabled]),
      splashDurationSec: FirestoreTypedValue.toFirestoreInt(
        d[EmisoraFields.splashDurationSec],
        min: 1,
        max: 5,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombreGrupo': nombreGrupo,
        'radioLabel': radioLabel,
        'tvLabel': tvLabel,
        'logoUrl': logoUrl,
        'colorHex': colorHex,
        'splashUrl': splashUrl,
        'bannerHomeUrl': bannerHomeUrl,
        'splashEnabled': splashEnabled,
        'splashDurationSec': splashDurationSec,
      };

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      id: json['id'] as String? ?? '',
      nombreGrupo: json['nombreGrupo'] as String? ?? '',
      radioLabel: json['radioLabel'] as String? ?? '',
      tvLabel: json['tvLabel'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '',
      splashUrl: json['splashUrl'] as String? ?? '',
      bannerHomeUrl: json['bannerHomeUrl'] as String? ?? '',
      splashEnabled: json['splashEnabled'] as bool? ?? false,
      splashDurationSec: (json['splashDurationSec'] as num?)?.toInt() ?? 3,
    );
  }

  AppInfo copyWith({
    String? id,
    String? nombreGrupo,
    String? radioLabel,
    String? tvLabel,
    String? logoUrl,
    String? colorHex,
    String? splashUrl,
    String? bannerHomeUrl,
    bool? splashEnabled,
    int? splashDurationSec,
  }) {
    return AppInfo(
      id: id ?? this.id,
      nombreGrupo: nombreGrupo ?? this.nombreGrupo,
      radioLabel: radioLabel ?? this.radioLabel,
      tvLabel: tvLabel ?? this.tvLabel,
      logoUrl: logoUrl ?? this.logoUrl,
      colorHex: colorHex ?? this.colorHex,
      splashUrl: splashUrl ?? this.splashUrl,
      bannerHomeUrl: bannerHomeUrl ?? this.bannerHomeUrl,
      splashEnabled: splashEnabled ?? this.splashEnabled,
      splashDurationSec: splashDurationSec ?? this.splashDurationSec,
    );
  }
}

