import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/utils/firestore_typed_value.dart';

class AppInfo {
  const AppInfo({
    required this.id,
    required this.nombreGrupo,
    required this.radioLabel,
    required this.tvLabel,
    required this.scheduleLabel,
    required this.logoUrl,
    required this.colorHex,
    required this.splashUrl,
    required this.bannerHomeUrl,
    required this.splashEnabled,
    required this.splashDurationSec,
    required this.shareText,
    this.bannerHomeLink = '',
    required this.playStoreUrl,
    required this.appStoreUrl,
  });

  final String id;
  final String nombreGrupo;
  final String radioLabel;
  final String tvLabel;
  final String scheduleLabel;
  final String logoUrl;
  final String colorHex;
  final String splashUrl;
  final String bannerHomeUrl;
  final bool splashEnabled;
  final int splashDurationSec;
  final String shareText;
  final String bannerHomeLink;
  final String playStoreUrl;
  final String appStoreUrl;

  factory AppInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppInfo(
      id: doc.id,
      nombreGrupo: d[EmisoraFields.nombreGrupo] as String? ?? '',
      radioLabel: d[EmisoraFields.radioLabel] as String? ?? '',
      tvLabel: d[EmisoraFields.tvLabel] as String? ?? '',
      scheduleLabel: d[EmisoraFields.scheduleLabel] as String? ?? 'Programación',
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
      shareText: d[EmisoraFields.shareText] as String? ?? 'Descarga nuestra app y escucha en vivo',
      bannerHomeLink: d[EmisoraFields.bannerHomeLink] as String? ?? '',
      playStoreUrl: d[EmisoraFields.playStoreUrl] as String? ?? '',
      appStoreUrl: d[EmisoraFields.appStoreUrl] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombreGrupo': nombreGrupo,
        'radioLabel': radioLabel,
        'tvLabel': tvLabel,
        'scheduleLabel': scheduleLabel,
        'logoUrl': logoUrl,
        'colorHex': colorHex,
        'splashUrl': splashUrl,
        'bannerHomeUrl': bannerHomeUrl,
        'splashEnabled': splashEnabled,
        'splashDurationSec': splashDurationSec,
        'shareText': shareText,
        'bannerHomeLink': bannerHomeLink,
        'playStoreUrl': playStoreUrl,
        'appStoreUrl': appStoreUrl,
      };

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      id: json['id'] as String? ?? '',
      nombreGrupo: json['nombreGrupo'] as String? ?? '',
      radioLabel: json['radioLabel'] as String? ?? '',
      tvLabel: json['tvLabel'] as String? ?? '',
      scheduleLabel: json['scheduleLabel'] as String? ?? 'Programación',
      logoUrl: json['logoUrl'] as String? ?? '',
      colorHex: json['colorHex'] as String? ?? '',
      splashUrl: json['splashUrl'] as String? ?? '',
      bannerHomeUrl: json['bannerHomeUrl'] as String? ?? '',
      splashEnabled: json['splashEnabled'] as bool? ?? false,
      splashDurationSec: (json['splashDurationSec'] as num?)?.toInt() ?? 3,
      shareText: json['shareText'] as String? ?? 'Descarga nuestra app y escucha en vivo',
      bannerHomeLink: json['bannerHomeLink'] as String? ?? '',
      playStoreUrl: json['playStoreUrl'] as String? ?? '',
      appStoreUrl: json['appStoreUrl'] as String? ?? '',
    );
  }

  AppInfo copyWith({
    String? id,
    String? nombreGrupo,
    String? radioLabel,
    String? tvLabel,
    String? scheduleLabel,
    String? logoUrl,
    String? colorHex,
    String? splashUrl,
    String? bannerHomeUrl,
    bool? splashEnabled,
    int? splashDurationSec,
    String? shareText,
    String? bannerHomeLink,
    String? playStoreUrl,
    String? appStoreUrl,
  }) {
    return AppInfo(
      id: id ?? this.id,
      nombreGrupo: nombreGrupo ?? this.nombreGrupo,
      radioLabel: radioLabel ?? this.radioLabel,
      tvLabel: tvLabel ?? this.tvLabel,
      scheduleLabel: scheduleLabel ?? this.scheduleLabel,
      logoUrl: logoUrl ?? this.logoUrl,
      colorHex: colorHex ?? this.colorHex,
      splashUrl: splashUrl ?? this.splashUrl,
      bannerHomeUrl: bannerHomeUrl ?? this.bannerHomeUrl,
      splashEnabled: splashEnabled ?? this.splashEnabled,
      splashDurationSec: splashDurationSec ?? this.splashDurationSec,
      shareText: shareText ?? this.shareText,
      bannerHomeLink: bannerHomeLink ?? this.bannerHomeLink,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      appStoreUrl: appStoreUrl ?? this.appStoreUrl,
    );
  }
}

