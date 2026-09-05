import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';
import 'package:radio_whitelabel/dashboard_web/models/app_info.dart';
import 'package:radio_whitelabel/dashboard_web/models/client_dashboard_data.dart';
import 'package:radio_whitelabel/dashboard_web/models/emisora.dart';
import 'package:radio_whitelabel/dashboard_web/models/marca_summary.dart';
import 'package:radio_whitelabel/dashboard_web/models/streaming.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/utils/tenant_scope.dart';
import 'package:radio_whitelabel/models/app_features.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado global en memoria + caché local. El [currentAppId] se resuelve tras el login.
class ClientDataStore extends ChangeNotifier {
  ClientDataStore(this._repository);

  final EmisoraRepository _repository;

  ClientDashboardData? _data;
  String? _ownerEmail;
  String? _currentAppId;
  String? _writeOwnerEmail;
  List<MarcaSummary> _marcas = const [];
  bool _refreshingMetrics = false;
  bool _initializing = false;
  String? _error;
  DateTime? _metricsSyncedAt;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _emisorasSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _streamingsSub;

  ClientDashboardData? get data => _data;
  String? get currentAppId => _currentAppId;
  String? get ownerEmail => _ownerEmail;
  String? get writeOwnerEmail => _writeOwnerEmail;
  List<MarcaSummary> get marcas => _marcas;
  bool get refreshingMetrics => _refreshingMetrics;
  bool get initializing => _initializing;
  String? get error => _error;
  DateTime? get lastSyncedAt => _data?.syncedAt;
  DateTime? get metricsSyncedAt => _metricsSyncedAt;

  /// Correo usado en filtros y altas (prioriza el de `marcas/{appId}`).
  String get effectiveOwnerEmail {
    final fromMarca = _writeOwnerEmail?.trim().toLowerCase() ?? '';
    if (fromMarca.isNotEmpty) return fromMarca;
    return _ownerEmail?.trim().toLowerCase() ?? '';
  }

  String? get nombreGrupoDisplay {
    final fromInfo = _data?.info?.nombreGrupo.trim();
    if (fromInfo != null && fromInfo.isNotEmpty) return fromInfo;
    for (final m in _marcas) {
      if (m.id == _currentAppId && m.nombreGrupo.trim().isNotEmpty) {
        return m.nombreGrupo.trim();
      }
    }
    return null;
  }

  TenantScope requireTenant() => TenantScope.require(
        appId: _currentAppId,
        ownerEmail: effectiveOwnerEmail,
      );

  String _cacheKey(String ownerEmail, String appId) =>
      'client_data.v3.${ownerEmail.trim().toLowerCase()}.$appId';

  /// Resuelve marca por correo, carga caché o Firestore.
  Future<void> ensureLoaded(String ownerEmail) async {
    final normalized = ownerEmail.trim().toLowerCase();
    if (_ownerEmail == normalized &&
        _currentAppId != null &&
        _data != null &&
        _data!.prefix == _currentAppId) {
      return;
    }

    _ownerEmail = normalized;
    _initializing = true;
    _error = null;
    _currentAppId = null;
    _writeOwnerEmail = null;
    notifyListeners();

    try {
      final marcaDoc = await _resolveSession(normalized);
      if (_currentAppId == null || _currentAppId!.isEmpty) {
        _data = ClientDashboardData(
          prefix: null,
          info: null,
          radios: const [],
          streamings: const [],
          unknownIds: const [],
          syncedAt: DateTime.now(),
        );
        await _persistToDisk();
        return;
      }

      await _purgeLegacyDiskCache(normalized);

      AppInfo? infoFromCache;
      AppFeatures? featuresFromCache;
      final cached = await _loadFromDisk(normalized, _currentAppId!);
      if (cached != null && !_isStaleCache(cached)) {
        infoFromCache = cached.info;
        featuresFromCache = cached.features;
      }
      await _initializeSessionData(marcaDoc, infoFromCache, featuresFromCache);
    } catch (e) {
      _error = e.toString();
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshMetricsFromFirestore(String ownerEmail) async {
    final normalized = ownerEmail.trim().toLowerCase();
    if (_data == null || _currentAppId == null) {
      await ensureLoaded(normalized);
      return;
    }

    _refreshingMetrics = true;
    _error = null;
    notifyListeners();

    try {
      final emisoraDocs = await _repository.fetchEmisorasDocsForClient(
        ownerEmail: effectiveOwnerEmail,
        appId: _currentAppId!,
      );
      final streamingDocs = await _repository.fetchStreamingsDocsForClient(
        ownerEmail: effectiveOwnerEmail,
        appId: _currentAppId!,
      );

      final freshRadios = {for (final raw in emisoraDocs) raw.id: Emisora.fromDoc(raw)};
      final freshStreamings = {for (final raw in streamingDocs) raw.id: Streaming.fromDoc(raw)};

      final mergedRadios = _data!.radios.map((r) {
        final fresh = freshRadios[r.id];
        if (fresh == null) return r;
        return r.copyWith(
          currentListeners: fresh.currentListeners,
          adClicks: fresh.adClicks,
          playCount: fresh.playCount,
          statsUpdatedAt: fresh.statsUpdatedAt,
        );
      }).toList();

      final mergedStreamings = _data!.streamings.map((s) {
        final fresh = freshStreamings[s.id];
        if (fresh == null) return s;
        return s.copyWith(
          playCount: fresh.playCount,
          statsUpdatedAt: fresh.statsUpdatedAt,
        );
      }).toList()
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

      _data = _data!.copyWith(radios: mergedRadios, streamings: mergedStreamings);
      _metricsSyncedAt = DateTime.now();
      await _persistToDisk();
    } catch (e) {
      _error = e.toString();
    } finally {
      _refreshingMetrics = false;
      notifyListeners();
    }
  }

  void patchAppInfo(AppInfo info) {
    if (_data == null) return;
    _data = _data!.copyWith(info: info, prefix: info.id);
    _marcas = _marcas
        .map(
          (m) => m.id == info.id
              ? MarcaSummary(id: m.id, ownerEmail: m.ownerEmail, nombreGrupo: info.nombreGrupo)
              : m,
        )
        .toList();
    _persistToDisk();
    notifyListeners();
  }

  void patchEmisora(Emisora emisora) {
    if (_data == null) return;
    final radios = _data!.radios.map((r) => r.id == emisora.id ? emisora : r).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    _data = _data!.copyWith(radios: radios);
    _persistToDisk();
    notifyListeners();
  }

  void patchStreaming(Streaming streaming) {
    if (_data == null) return;
    final streamings = _data!.streamings.map((s) => s.id == streaming.id ? streaming : s).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    _data = _data!.copyWith(streamings: streamings);
    _persistToDisk();
    notifyListeners();
  }

  void addEmisora(Emisora emisora) {
    if (_data == null) return;
    if (_data!.radios.any((r) => r.id == emisora.id)) {
      patchEmisora(emisora);
      return;
    }
    final radios = [..._data!.radios, emisora]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    _data = _data!.copyWith(radios: radios);
    _persistToDisk();
    notifyListeners();
  }

  void addStreaming(Streaming streaming) {
    if (_data == null) return;
    if (_data!.streamings.any((s) => s.id == streaming.id)) {
      patchStreaming(streaming);
      return;
    }
    final streamings = [..._data!.streamings, streaming]
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    _data = _data!.copyWith(streamings: streamings);
    _persistToDisk();
    notifyListeners();
  }

  void clear() {
    _stopContentStreams();
    _data = null;
    _ownerEmail = null;
    _currentAppId = null;
    _writeOwnerEmail = null;
    _marcas = const [];
    _error = null;
    _metricsSyncedAt = null;
    notifyListeners();
  }

  /// Resuelve marca por correo. Devuelve el DocumentSnapshot ya leído para reutilizarlo.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveSession(
      String normalized) async {
    final appId = await _repository.resolveAppIdForOwner(ownerEmail: normalized);
    if (appId == null) {
      _marcas = const [];
      return null;
    }

    _currentAppId = appId;
    final marcaDoc = await _repository.fetchMarcaDoc(ownerEmail: normalized, appId: appId);
    final ownerOnDoc = marcaDoc?.data()?[EmisoraFields.ownerEmail] as String?;
    _writeOwnerEmail = (ownerOnDoc ?? normalized).trim().toLowerCase();

    if (marcaDoc != null) {
      final d = marcaDoc.data() ?? {};
      _marcas = [
        MarcaSummary(
          id: appId,
          ownerEmail: _writeOwnerEmail!,
          nombreGrupo: d[EmisoraFields.nombreGrupo] as String? ?? '',
        ),
      ];
    } else {
      _marcas = [MarcaSummary(id: appId, ownerEmail: _writeOwnerEmail!)];
    }
    return marcaDoc;
  }

  /// Inicializa los datos de sesión reutilizando el snapshot ya leído en _resolveSession.
  Future<void> _initializeSessionData(
    DocumentSnapshot<Map<String, dynamic>>? marcaDoc,
    AppInfo? infoFromCache,
    AppFeatures? featuresFromCache,
  ) async {
    final appId = _currentAppId;
    final loginEmail = _ownerEmail;
    if (appId == null || appId.isEmpty || loginEmail == null) return;

    if (marcaDoc != null) {
      final onDoc = marcaDoc.data()?[EmisoraFields.ownerEmail] as String?;
      final resolved = (onDoc ?? loginEmail).trim().toLowerCase();
      if (resolved.isNotEmpty) _writeOwnerEmail = resolved;
    }

    final info = marcaDoc != null ? AppInfo.fromDoc(marcaDoc) : infoFromCache;
    final features = marcaDoc != null ? AppFeatures.fromMap(marcaDoc.data()) : featuresFromCache;

    _data = ClientDashboardData(
      prefix: appId,
      info: info,
      radios: const [],
      streamings: const [],
      unknownIds: const [],
      features: features ?? const AppFeatures(),
      syncedAt: DateTime.now(),
    );

    _startContentStreams(appId, effectiveOwnerEmail);
    await _persistToDisk();
  }

  void _startContentStreams(String appId, String ownerEmail) {
    _stopContentStreams();

    _emisorasSub = _repository
        .watchEmisorasDocsForClient(ownerEmail: ownerEmail, appId: appId)
        .listen(
      (snap) {
        if (_data == null || _currentAppId != appId) return;
        final radios = snap.docs.map(Emisora.fromDoc).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        _data = _data!.copyWith(radios: radios, syncedAt: DateTime.now());
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      },
    );

    _streamingsSub = _repository
        .watchStreamingsDocsForClient(ownerEmail: ownerEmail, appId: appId)
        .listen(
      (snap) {
        if (_data == null || _currentAppId != appId) return;
        final streamings = snap.docs.map(Streaming.fromDoc).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        _data = _data!.copyWith(streamings: streamings, syncedAt: DateTime.now());
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void _stopContentStreams() {
    _emisorasSub?.cancel();
    _streamingsSub?.cancel();
    _emisorasSub = null;
    _streamingsSub = null;
  }

  Future<ClientDashboardData?> _loadFromDisk(String ownerEmail, String appId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(ownerEmail, appId));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ClientDashboardData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistToDisk() async {
    final email = _ownerEmail;
    final appId = _currentAppId;
    final snapshot = _data;
    if (email == null || appId == null || snapshot == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Las listas de radios/streamings se sincronizan en vivo; no persistirlas en caché local.
      final cachePayload = snapshot.copyWith(radios: const [], streamings: const []);
      await prefs.setString(_cacheKey(email, appId), jsonEncode(cachePayload.toJson()));
    } catch (_) {}
  }

  bool _isStaleCache(ClientDashboardData cached) {
    final infoId = cached.info?.id;
    if (infoId != null && infoId.endsWith('_info')) return true;
    if (cached.unknownIds.isNotEmpty) return true;
    if (cached.prefix != _currentAppId) return true;
    if (cached.info != null && cached.info!.id != _currentAppId) return true;
    return false;
  }

  Future<void> _purgeLegacyDiskCache(String ownerEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyKey = 'client_data.v2.${ownerEmail.trim().toLowerCase()}';
      await prefs.remove(legacyKey);
    } catch (_) {}
  }
}
