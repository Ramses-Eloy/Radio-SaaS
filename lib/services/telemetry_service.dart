import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/telemetry_event.dart';

/// Telemetry service that buffers events locally and flushes them to Firestore
/// in batches every [_flushIntervalMinutes] minutes, dramatically reducing
/// Firestore write operations.
///
/// Instead of writing N events per second, the app accumulates counters in
/// memory and writes a single aggregated document per flush cycle.
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;
  TelemetryService._internal();

  // ── Configuration ──────────────────────────────────────────
  static const int _flushIntervalMinutes = 5;

  // ── In-memory event log (kept for backward-compat getEventCount) ──
  final List<TelemetryEvent> _events = [];
  List<TelemetryEvent> get events => List.unmodifiable(_events);

  // ── Aggregation counters (reset after each flush) ──────────
  final Map<String, int> _playCountByStation = {};
  final Map<String, int> _adClicksByStation = {};
  final Map<String, int> _alertAcksByStation = {};
  final Map<String, int> _socialClicksByStation = {};
  int _totalPlays = 0;
  int _totalAdClicks = 0;
  int _totalAlertAcks = 0;
  int _totalSocialClicks = 0;

  // ── Geo detection (resolved once per session) ──────────────
  String? _sessionCountryCode;
  bool _geoResolved = false;

  // ── Flush timer ────────────────────────────────────────────
  Timer? _flushTimer;
  String? _activeAppId;
  bool _initialized = false;

  /// Call once when the app starts (typically after StationProvider resolves appId).
  void initialize({required String appId}) {
    _activeAppId = appId;
    if (_initialized) return;
    _initialized = true;

    // Resolve geo once
    _resolveGeo();

    // Start periodic flush timer
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(minutes: _flushIntervalMinutes),
      (_) => flush(),
    );

    if (kDebugMode) {
      print('📊 [TELEMETRÍA] Inicializado para appId=$appId (flush cada ${_flushIntervalMinutes}min)');
    }
  }

  /// Update appId if tenant changes mid-session (e.g., admin switches marca).
  void updateAppId(String appId) {
    if (_activeAppId != appId) {
      // Flush pending data for old appId before switching
      flush();
      _activeAppId = appId;
    }
  }

  /// Resolves the user's country code once per session using the device locale.
  void _resolveGeo() {
    if (_geoResolved) return;
    _geoResolved = true;
    try {
      // Use the device's locale country code (no network call, free, instant)
      final locale = PlatformDispatcher.instance.locale;
      _sessionCountryCode = locale.countryCode ?? 'XX';
    } catch (_) {
      _sessionCountryCode = 'XX';
    }
    if (kDebugMode) {
      print('📊 [TELEMETRÍA] País de sesión detectado: $_sessionCountryCode');
    }
  }

  // ── Public API: log events ──────────────────────────────────
  void logEvent({
    required String eventType,
    required String stationId,
    String targetUrl = '',
    Map<String, dynamic> metadata = const {},
  }) {
    // Keep in-memory log for backward compat
    final event = TelemetryEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: eventType,
      stationId: stationId,
      targetUrl: targetUrl,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    _events.add(event);

    // Aggregate into counters
    switch (eventType) {
      case 'audio_play':
        _totalPlays++;
        _playCountByStation[stationId] = (_playCountByStation[stationId] ?? 0) + 1;
        break;
      case 'ad_click':
        _totalAdClicks++;
        _adClicksByStation[stationId] = (_adClicksByStation[stationId] ?? 0) + 1;
        // Distinguish avance informativo acks from banner clicks
        if (metadata['adType'] == 'avance_informativo') {
          _totalAlertAcks++;
          _alertAcksByStation[stationId] = (_alertAcksByStation[stationId] ?? 0) + 1;
        }
        break;
      case 'whatsapp_click':
      case 'call_click':
      case 'social_click':
        _totalSocialClicks++;
        _socialClicksByStation[stationId] = (_socialClicksByStation[stationId] ?? 0) + 1;
        break;
    }

    if (kDebugMode) {
      print('📊 [TELEMETRÍA] Evento: $eventType | Estación: $stationId | Metadata: $metadata');
    }
  }

  // ── Flush buffered counters to Firestore ──────────────────
  /// Writes a single aggregated document to `stats_daily/{appId}_{YYYY-MM-DD}`
  /// using `FieldValue.increment()` for atomic, idempotent updates.
  Future<void> flush() async {
    if (_activeAppId == null || _activeAppId!.isEmpty) return;
    if (_totalPlays == 0 && _totalAdClicks == 0 && _totalSocialClicks == 0) return;

    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hourKey = now.hour.toString();
    final docId = '${_activeAppId}_$dateKey';
    final country = _sessionCountryCode ?? 'XX';

    // Capture current counters and reset immediately so new events
    // during the async write go to the next batch.
    final plays = _totalPlays;
    final adClicks = _totalAdClicks;
    final alertAcks = _totalAlertAcks;
    final socialClicks = _totalSocialClicks;
    final playsByStation = Map<String, int>.from(_playCountByStation);
    final adClicksByStation = Map<String, int>.from(_adClicksByStation);

    _resetCounters();

    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('stats_daily').doc(docId);

      // Build the atomic increment map
      final Map<String, dynamic> updateData = {
        'appId': _activeAppId,
        'date': dateKey,
        'updatedAt': FieldValue.serverTimestamp(),
        // Global totals
        'totalPlays': FieldValue.increment(plays),
        'totalAdClicks': FieldValue.increment(adClicks),
        'totalAlertAcks': FieldValue.increment(alertAcks),
        'totalSocialClicks': FieldValue.increment(socialClicks),
        // Hourly breakdown
        'hourly.$hourKey.plays': FieldValue.increment(plays),
        'hourly.$hourKey.adClicks': FieldValue.increment(adClicks),
        // Geo breakdown
        'geo.$country': FieldValue.increment(plays),
      };

      // Per-station breakdown
      for (final entry in playsByStation.entries) {
        updateData['stations.${entry.key}.plays'] = FieldValue.increment(entry.value);
      }
      for (final entry in adClicksByStation.entries) {
        updateData['stations.${entry.key}.adClicks'] = FieldValue.increment(entry.value);
      }

      await docRef.set(updateData, SetOptions(merge: true));

      if (kDebugMode) {
        print('📊 [TELEMETRÍA] Flush OK → stats_daily/$docId (+$plays plays, +$adClicks adClicks, +$alertAcks alertAcks, geo=$country)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📊 [TELEMETRÍA] Error en flush: $e');
      }
      // On failure, add the counters back so they'll be retried next flush
      _totalPlays += plays;
      _totalAdClicks += adClicks;
      _totalAlertAcks += alertAcks;
      _totalSocialClicks += socialClicks;
      playsByStation.forEach((k, v) {
        _playCountByStation[k] = (_playCountByStation[k] ?? 0) + v;
      });
      adClicksByStation.forEach((k, v) {
        _adClicksByStation[k] = (_adClicksByStation[k] ?? 0) + v;
      });
    }
  }

  void _resetCounters() {
    _totalPlays = 0;
    _totalAdClicks = 0;
    _totalAlertAcks = 0;
    _totalSocialClicks = 0;
    _playCountByStation.clear();
    _adClicksByStation.clear();
    _alertAcksByStation.clear();
    _socialClicksByStation.clear();
  }

  // ── Backward-compat helper ─────────────────────────────────
  int getEventCount(String eventType, {String? stationId}) {
    return _events.where((e) {
      final matchesType = e.eventType == eventType;
      final matchesStation = stationId == null || e.stationId == stationId;
      return matchesType && matchesStation;
    }).length;
  }

  /// Call when the app is going to background / being closed.
  /// Forces an immediate flush of any pending data.
  Future<void> flushAndDispose() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
