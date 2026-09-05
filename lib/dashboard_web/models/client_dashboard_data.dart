import 'package:radio_whitelabel/dashboard_web/models/app_info.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/models/app_features.dart';

class ClientDashboardData {
  const ClientDashboardData({
    required this.prefix,
    required this.info,
    required this.radios,
    required this.streamings,
    required this.unknownIds,
    this.features,
    this.syncedAt,
  });

  final String? prefix;
  final AppInfo? info;
  final List<Emisora> radios;
  final List<Streaming> streamings;
  final List<String> unknownIds;
  final AppFeatures? features;
  final DateTime? syncedAt;

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'info': info?.toJson(),
        'radios': radios.map((e) => e.toJson()).toList(),
        'streamings': streamings.map((e) => e.toJson()).toList(),
        'unknownIds': unknownIds,
        'features': features?.toMap(),
        'syncedAt': syncedAt?.toIso8601String(),
      };

  factory ClientDashboardData.fromJson(Map<String, dynamic> json) {
    return ClientDashboardData(
      prefix: json['prefix'] as String?,
      info: json['info'] is Map<String, dynamic> ? AppInfo.fromJson(json['info'] as Map<String, dynamic>) : null,
      radios: (json['radios'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Emisora.fromJson)
          .toList(),
      streamings: (json['streamings'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Streaming.fromJson)
          .toList(),
      unknownIds: (json['unknownIds'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      features: json['features'] is Map<String, dynamic> ? AppFeatures.fromMap(json['features'] as Map<String, dynamic>) : null,
      syncedAt: json['syncedAt'] != null ? DateTime.tryParse(json['syncedAt'] as String) : null,
    );
  }

  ClientDashboardData copyWith({
    String? prefix,
    AppInfo? info,
    List<Emisora>? radios,
    List<Streaming>? streamings,
    List<String>? unknownIds,
    AppFeatures? features,
    DateTime? syncedAt,
  }) {
    return ClientDashboardData(
      prefix: prefix ?? this.prefix,
      info: info ?? this.info,
      radios: radios ?? this.radios,
      streamings: streamings ?? this.streamings,
      unknownIds: unknownIds ?? this.unknownIds,
      features: features ?? this.features,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
