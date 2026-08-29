import 'package:cloud_firestore/cloud_firestore.dart';


/// Aggregated daily stats document from `stats_daily/{appId}_{date}`.
class DailyStats {
  final String docId;
  final String appId;
  final String date;
  final int totalPlays;
  final int totalAdClicks;
  final int totalAlertAcks;
  final int totalSocialClicks;
  final Map<String, int> geo;           // {'PA': 120, 'US': 30, ...}
  final Map<String, int> hourlyPlays;   // {'0': 5, '1': 3, ...}
  final Map<String, int> hourlyAdClicks;
  final Map<String, Map<String, int>> stations; // {stationId: {plays: X, adClicks: Y}}

  const DailyStats({
    required this.docId,
    required this.appId,
    required this.date,
    required this.totalPlays,
    required this.totalAdClicks,
    required this.totalAlertAcks,
    required this.totalSocialClicks,
    required this.geo,
    required this.hourlyPlays,
    required this.hourlyAdClicks,
    required this.stations,
  });

  factory DailyStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final hourly = d['hourly'] as Map<String, dynamic>? ?? {};
    final geoRaw = d['geo'] as Map<String, dynamic>? ?? {};
    final stationsRaw = d['stations'] as Map<String, dynamic>? ?? {};

    // Parse hourly data
    final hourlyPlays = <String, int>{};
    final hourlyAdClicks = <String, int>{};
    for (final entry in hourly.entries) {
      final hourData = entry.value as Map<String, dynamic>? ?? {};
      hourlyPlays[entry.key] = (hourData['plays'] as num?)?.toInt() ?? 0;
      hourlyAdClicks[entry.key] = (hourData['adClicks'] as num?)?.toInt() ?? 0;
    }

    // Parse geo data
    final geo = <String, int>{};
    for (final entry in geoRaw.entries) {
      geo[entry.key] = (entry.value as num?)?.toInt() ?? 0;
    }

    // Parse stations data
    final stations = <String, Map<String, int>>{};
    for (final entry in stationsRaw.entries) {
      final stData = entry.value as Map<String, dynamic>? ?? {};
      stations[entry.key] = {
        'plays': (stData['plays'] as num?)?.toInt() ?? 0,
        'adClicks': (stData['adClicks'] as num?)?.toInt() ?? 0,
      };
    }

    return DailyStats(
      docId: doc.id,
      appId: d['appId'] as String? ?? '',
      date: d['date'] as String? ?? '',
      totalPlays: (d['totalPlays'] as num?)?.toInt() ?? 0,
      totalAdClicks: (d['totalAdClicks'] as num?)?.toInt() ?? 0,
      totalAlertAcks: (d['totalAlertAcks'] as num?)?.toInt() ?? 0,
      totalSocialClicks: (d['totalSocialClicks'] as num?)?.toInt() ?? 0,
      geo: geo,
      hourlyPlays: hourlyPlays,
      hourlyAdClicks: hourlyAdClicks,
      stations: stations,
    );
  }

  /// Zero-filled placeholder for days with no data.
  factory DailyStats.empty(String date) => DailyStats(
        docId: '',
        appId: '',
        date: date,
        totalPlays: 0,
        totalAdClicks: 0,
        totalAlertAcks: 0,
        totalSocialClicks: 0,
        geo: const {},
        hourlyPlays: const {},
        hourlyAdClicks: const {},
        stations: const {},
      );
}

/// Aggregated summary across multiple days.
class StatsSummary {
  final int totalPlays;
  final int totalAdClicks;
  final int totalAlertAcks;
  final int totalSocialClicks;
  final Map<String, int> geo;
  final List<DailyStats> dailyBreakdown;
  final Map<String, Map<String, int>> stationTotals;

  const StatsSummary({
    required this.totalPlays,
    required this.totalAdClicks,
    required this.totalAlertAcks,
    required this.totalSocialClicks,
    required this.geo,
    required this.dailyBreakdown,
    required this.stationTotals,
  });

  factory StatsSummary.empty() => const StatsSummary(
        totalPlays: 0,
        totalAdClicks: 0,
        totalAlertAcks: 0,
        totalSocialClicks: 0,
        geo: {},
        dailyBreakdown: [],
        stationTotals: {},
      );
}

/// Service that reads pre-aggregated daily stats from Firestore.
/// Each time filter (24H, 7D, 30D) reads only 1, 7, or 30 documents respectively.
class StatsAggregationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches daily stats for a given [appId] over the last [days] days.
  /// Returns at most [days] documents (one per day).
  Future<StatsSummary> fetchStats({
    required String appId,
    required int days,
  }) async {
    final now = DateTime.now();
    final List<DailyStats> dailyList = [];

    // Build the list of date keys to query
    final dateKeys = <String>[];
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      dateKeys.add(
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }

    // Fetch all daily docs in a single batch read (parallel futures)
    final futures = dateKeys.map((dateKey) {
      final docId = '${appId}_$dateKey';
      return _db.collection('stats_daily').doc(docId).get();
    });

    final snapshots = await Future.wait(futures);

    for (int i = 0; i < snapshots.length; i++) {
      final snap = snapshots[i];
      if (snap.exists) {
        dailyList.add(DailyStats.fromDoc(snap));
      } else {
        dailyList.add(DailyStats.empty(dateKeys[i]));
      }
    }

    // Aggregate totals across all days
    int totalPlays = 0;
    int totalAdClicks = 0;
    int totalAlertAcks = 0;
    int totalSocialClicks = 0;
    final geo = <String, int>{};
    final stationTotals = <String, Map<String, int>>{};

    for (final day in dailyList) {
      totalPlays += day.totalPlays;
      totalAdClicks += day.totalAdClicks;
      totalAlertAcks += day.totalAlertAcks;
      totalSocialClicks += day.totalSocialClicks;

      for (final entry in day.geo.entries) {
        geo[entry.key] = (geo[entry.key] ?? 0) + entry.value;
      }

      for (final entry in day.stations.entries) {
        final existing = stationTotals[entry.key] ?? {'plays': 0, 'adClicks': 0};
        stationTotals[entry.key] = {
          'plays': existing['plays']! + (entry.value['plays'] ?? 0),
          'adClicks': existing['adClicks']! + (entry.value['adClicks'] ?? 0),
        };
      }
    }

    return StatsSummary(
      totalPlays: totalPlays,
      totalAdClicks: totalAdClicks,
      totalAlertAcks: totalAlertAcks,
      totalSocialClicks: totalSocialClicks,
      geo: geo,
      dailyBreakdown: dailyList,
      stationTotals: stationTotals,
    );
  }

  /// Convenience: fetch today's stats only (1 read).
  Future<StatsSummary> fetchToday(String appId) => fetchStats(appId: appId, days: 1);

  /// Convenience: fetch last 7 days (7 reads).
  Future<StatsSummary> fetchWeek(String appId) => fetchStats(appId: appId, days: 7);

  /// Convenience: fetch last 30 days (30 reads).
  Future<StatsSummary> fetchMonth(String appId) => fetchStats(appId: appId, days: 30);
}
