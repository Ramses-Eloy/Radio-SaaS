import 'package:flutter/foundation.dart';
import '../models/telemetry_event.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  final List<TelemetryEvent> _events = [];

  List<TelemetryEvent> get events => List.unmodifiable(_events);

  void logEvent({
    required String eventType,
    required String stationId,
    String targetUrl = '',
    Map<String, dynamic> metadata = const {},
  }) {
    final event = TelemetryEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: eventType,
      stationId: stationId,
      targetUrl: targetUrl,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _events.add(event);

    if (kDebugMode) {
      print('📊 [TELEMETRÍA] Evento registrado: $eventType | Estación: $stationId | Metadata: $metadata');
    }
  }

  int getEventCount(String eventType, {String? stationId}) {
    return _events.where((e) {
      final matchesType = e.eventType == eventType;
      final matchesStation = stationId == null || e.stationId == stationId;
      return matchesType && matchesStation;
    }).length;
  }
}
