class TelemetryEvent {
  final String id;
  final String eventType; // e.g. 'audio_play', 'ad_click', 'whatsapp_click', 'call_click', 'social_click'
  final String stationId;
  final String targetUrl;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  TelemetryEvent({
    required this.id,
    required this.eventType,
    required this.stationId,
    this.targetUrl = '',
    required this.timestamp,
    this.metadata = const {},
  });

  factory TelemetryEvent.fromJson(Map<String, dynamic> json) {
    return TelemetryEvent(
      id: json['id'] ?? '',
      eventType: json['eventType'] ?? 'unknown',
      stationId: json['stationId'] ?? '',
      targetUrl: json['targetUrl'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventType': eventType,
        'stationId': stationId,
        'targetUrl': targetUrl,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };
}
