import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/station.dart';
import '../models/program.dart';
import '../models/tv_channel.dart';
import '../services/firestore_service.dart';

class StationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // Active Tenant / Flavor ID ('erancon' or 'sira')
  String _activeAppId = 'erancon';
  String get activeAppId => _activeAppId;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // General App Brand Settings (Mapped to Firestore `marcas` doc)
  String _brandName = 'ERANCÓN';
  String _brandEmail = '';
  String _brandLogoUrl = 'https://i.postimg.cc/QMK6Fvfb/EMPORIO.png';
  String _radioLabel = 'En Vivo';
  String _tvLabel = 'Video Live';
  String _brandBannerHomeUrl = '';
  String _splashUrl = '';
  bool _splashEnabled = true;
  int _splashDurationSec = 5;
  String? _flashInformativoMessage;

  String get brandName => _brandName;
  String get brandEmail => _brandEmail;
  String get brandLogoUrl => _brandLogoUrl;
  String get radioLabel => _radioLabel;
  String get tvLabel => _tvLabel;
  String get brandBannerHomeUrl => _brandBannerHomeUrl;
  String get splashUrl => _splashUrl;
  bool get splashEnabled => _splashEnabled;
  int get splashDurationSec => _splashDurationSec;
  String? get flashInformativoMessage => _flashInformativoMessage;

  // Alert ID tracking — prevents re-showing the same alert
  String? _currentAlertId;

  int _selectedStationIndex = 0;

  // Dynamic Lists Driven 100% by Firestore
  List<Station> _stations = [];
  List<TvChannel> _tvChannels = [];

  List<Program> _programs = [];

  StreamSubscription<Map<String, dynamic>?>? _marcaSub;
  StreamSubscription<List<Station>>? _emisorasSub;
  StreamSubscription<List<TvChannel>>? _tvSub;
  StreamSubscription<List<Program>>? _programacionSub;

  StationProvider() {
    _initFirestoreListeners();
  }

  Future<void> resolveSessionForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    _brandEmail = normalized;

    final resolvedAppId = await _firestoreService.resolveAppIdForOwner(normalized);
    if (resolvedAppId != null && resolvedAppId.isNotEmpty) {
      setFlavorAppId(resolvedAppId);
    }
  }

  void _initFirestoreListeners() {
    _marcaSub?.cancel();
    _emisorasSub?.cancel();
    _tvSub?.cancel();
    _programacionSub?.cancel();

    try {
      _firestoreService.ensureInitialDataSeeded(_activeAppId);

      // Stream `marcas/{_activeAppId}`
      _marcaSub = _firestoreService.streamMarca(_activeAppId).listen((data) async {
        if (data != null) {
          _brandName = data['nombre_grupo'] ?? _brandName;
          _brandLogoUrl = data['logo_url'] ?? _brandLogoUrl;
          _radioLabel = data['radio_label'] ?? _radioLabel;
          _tvLabel = data['tv_label'] ?? _tvLabel;
          _brandBannerHomeUrl = data['banner_home_url'] ?? _brandBannerHomeUrl;
          if (data['ownerEmail'] != null) _brandEmail = data['ownerEmail'];
          _splashUrl = data['splash_url'] ?? _splashUrl;
          _splashEnabled = data['splash_enabled'] ?? _splashEnabled;
          _splashDurationSec = (data['splash_duration_sec'] ?? _splashDurationSec) is int
              ? data['splash_duration_sec'] ?? _splashDurationSec
              : _splashDurationSec;

          if (data['alerta_global'] != null && data['alerta_global'] is Map) {
            final alert = data['alerta_global'] as Map;
            final alertId = alert['id_alerta']?.toString();
            final alertTimestamp = alert['timestamp'];

            bool isRecent = false;
            if (alertTimestamp != null) {
              // alertTimestamp is typically a Cloud Firestore Timestamp (has seconds)
              final seconds = alertTimestamp is int 
                  ? alertTimestamp 
                  : (alertTimestamp.seconds ?? 0);
              final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
              final difference = DateTime.now().difference(date);
              isRecent = difference.inHours < 12;
            }
            
            // Fetch prefs to guarantee we have the latest seen_alert for this flavor
            final prefs = await SharedPreferences.getInstance();
            final lastSeen = prefs.getString('seen_alert_$_activeAppId');

            // Only surface the alert if it's a NEW one, AND it was sent recently
            if (isRecent && alertId != null && alertId.isNotEmpty && alertId != lastSeen) {
              _currentAlertId = alertId;
              _flashInformativoMessage = alert['mensaje']?.toString();
            } else {
              _currentAlertId = null;
              _flashInformativoMessage = null;
            }
          }
          notifyListeners();
        }
      });

      // Stream `emisoras` for `_activeAppId`
      _emisorasSub = _firestoreService.streamEmisoras(_activeAppId).listen((list) {
        _stations = list;
        if (_selectedStationIndex >= _stations.length) {
          _selectedStationIndex = 0;
        }
        _isLoading = false;
        _updateProgramacionSubscription();
        notifyListeners();
      });

      // Stream `streamings` for `_activeAppId`
      _tvSub = _firestoreService.streamTvChannels(_activeAppId).listen((list) {
        _tvChannels = list;
        notifyListeners();
      });
    } catch (_) {}
  }

  void setFlavorAppId(String appId) {
    _activeAppId = appId;
    _selectedStationIndex = 0;
    _stations = [];
    _tvChannels = [];
    _currentAlertId = null;
    _flashInformativoMessage = null;

    if (appId == 'sira') {
      _brandName = 'Grupo Sira Radio';
      _brandEmail = 'isaacsarsanedas@gmail.com';
      _brandLogoUrl = 'https://i.postimg.cc/gc4QKX0F/logo.png';
    } else {
      _brandName = 'ERANCÓN';
      _brandEmail = 'ramses.11rsg@gmail.com';
      _brandLogoUrl = 'https://i.postimg.cc/QMK6Fvfb/EMPORIO.png';
    }

    _initFirestoreListeners();
    notifyListeners();
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  List<Station> get stations => _stations;
  List<TvChannel> get tvChannels => _tvChannels;

  Station get currentStation {
    if (_stations.isNotEmpty) {
      if (_selectedStationIndex < _stations.length) {
        return _stations[_selectedStationIndex];
      }
      return _stations.first;
    }
    // Safe Fallback if Firestore is still loading.
    // The UI should typically show a loading spinner based on `isLoading`.
    return Station(
      id: 'loading',
      name: 'Cargando...',
      slogan: '',
      logoUrl: '',
      streamUrl: '',
      videoStreamUrl: '',
      isLive: false,
      showSchedule: false,
      whatsappNumber: '',
      phoneNumber: '',
      socialLinks: SocialLinks(),
      lightTheme: ThemeConfig(
        primaryColorHex: '#333333',
        secondaryColorHex: '#666666',
        backgroundColorHex: '#F8FAFC',
        cardColorHex: '#FFFFFF',
      ),
      darkTheme: ThemeConfig(
        primaryColorHex: '#333333',
        secondaryColorHex: '#666666',
        backgroundColorHex: '#0D1117',
        cardColorHex: '#161B22',
      ),
    );
  }

  int get selectedStationIndex => _selectedStationIndex;

  List<Program> get currentStationPrograms =>
      _programs.where((p) => p.stationId == currentStation.id).toList();

  Program? get currentLiveProgram => _programs.firstWhere(
        (p) => p.stationId == currentStation.id && p.isLiveNow,
        orElse: () => _programs.isNotEmpty ? _programs.first : Program(
          id: 'def',
          stationId: currentStation.id,
          title: currentStation.slogan,
          hostName: currentStation.name,
          hostAvatarUrl: '',
          category: 'Música',
          startTime: '00:00',
          endTime: '24:00',
          isLiveNow: true,
        ),
      );

  ThemeConfig get activeThemeConfig =>
      _themeMode == ThemeMode.dark ? currentStation.darkTheme : currentStation.lightTheme;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void selectStation(int index) {
    if (index >= 0 && index < _stations.length) {
      _selectedStationIndex = index;
      _updateProgramacionSubscription();
      notifyListeners();
    }
  }

  void _updateProgramacionSubscription() {
    _programacionSub?.cancel();
    if (_stations.isNotEmpty && _selectedStationIndex < _stations.length) {
      final currentId = _stations[_selectedStationIndex].id;
      _programacionSub = _firestoreService.streamProgramacion(currentId).listen((list) {
        _programs = list;
        notifyListeners();
      });
    }
  }

  Future<void> updateStationDetails({
    required String stationId,
    required String name,
    required String logoUrl,
    required String primaryColorHex,
    required bool showSchedule,
    required String streamUrl,
    required String phoneNumber,
    required String whatsappNumber,
    required String facebook,
    required String instagram,
    required String tiktok,
    required String twitter,
  }) async {
    final index = _stations.indexWhere((s) => s.id == stationId);
    if (index != -1) {
      final old = _stations[index];
      _stations[index] = old.copyWith(
        name: name,
        logoUrl: logoUrl,
        showSchedule: showSchedule,
        streamUrl: streamUrl,
        phoneNumber: phoneNumber,
        whatsappNumber: whatsappNumber,
        socialLinks: SocialLinks(
          facebook: facebook,
          instagram: instagram,
          tiktok: tiktok,
          twitter: twitter,
        ),
        darkTheme: ThemeConfig(
          primaryColorHex: primaryColorHex,
          secondaryColorHex: old.darkTheme.secondaryColorHex,
          backgroundColorHex: old.darkTheme.backgroundColorHex,
          cardColorHex: old.darkTheme.cardColorHex,
        ),
      );
      notifyListeners();
    }

    await _firestoreService.updateEmisora(
      stationId: stationId,
      appId: _activeAppId,
      nombre: name,
      logoUrl: logoUrl,
      colorHex: primaryColorHex,
      mostrarProgramacion: showSchedule,
      urlAudio: streamUrl,
      telefonoCabina: phoneNumber,
      whatsapp: whatsappNumber,
      facebook: facebook,
      instagram: instagram,
      twitter: twitter,
    );
  }

  Future<void> updateTvChannelDetails({
    required String channelId,
    required String name,
    required String streamUrl,
    required String imageUrl,
    required bool showOnHome,
    required bool showSchedule,
  }) async {
    final index = _tvChannels.indexWhere((t) => t.id == channelId);
    if (index != -1) {
      final old = _tvChannels[index];
      _tvChannels[index] = old.copyWith(
        name: name,
        streamUrl: streamUrl,
        imageUrl: imageUrl,
        showOnHome: showOnHome,
        showSchedule: showSchedule,
      );
      notifyListeners();
    }

    await _firestoreService.updateStreamingTv(
      channelId: channelId,
      appId: _activeAppId,
      nombre: name,
      urlVideo: streamUrl,
      logoUrl: imageUrl,
      showOnHome: showOnHome,
      mostrarProgramacion: showSchedule,
    );
  }

  Future<void> updateGeneralBrandSettings({
    required String brandName,
    required String brandLogoUrl,
    required String primaryColorHex,
    String radioLabel = 'En Vivo',
    String tvLabel = 'Video Live',
  }) async {
    _brandName = brandName;
    _brandLogoUrl = brandLogoUrl;
    _radioLabel = radioLabel;
    _tvLabel = tvLabel;
    notifyListeners();

    await _firestoreService.updateMarca(
      appId: _activeAppId,
      nombreGrupo: brandName,
      logoUrl: brandLogoUrl,
      colorHex: primaryColorHex,
      splashUrl: '',
      bannerHomeUrl: '',
      splashEnabled: true,
      splashDurationSec: 5,
      radioLabel: radioLabel,
      tvLabel: tvLabel,
    );
  }

  Future<void> createEmisora(String nombre) async {
    await _firestoreService.createEmisora(
      appId: _activeAppId,
      nombre: nombre,
      ownerEmail: _brandEmail,
    );
  }

  Future<void> deleteEmisora(String stationId) async {
    _stations.removeWhere((s) => s.id == stationId);
    if (_selectedStationIndex >= _stations.length) {
      _selectedStationIndex = 0;
    }
    notifyListeners();
    await _firestoreService.deleteEmisora(stationId);
  }

  Future<void> createStreamingTv(String nombre) async {
    await _firestoreService.createStreamingTv(
      appId: _activeAppId,
      nombre: nombre,
      ownerEmail: _brandEmail,
    );
  }

  Future<void> deleteStreamingTv(String channelId) async {
    _tvChannels.removeWhere((t) => t.id == channelId);
    notifyListeners();
    await _firestoreService.deleteStreamingTv(channelId);
  }

  Future<void> triggerFlashInformativo(String message) async {
    _flashInformativoMessage = message;
    notifyListeners();
    await _firestoreService.triggerAlertaGlobal(appId: _activeAppId, mensaje: message);
  }

  void clearFlashInformativo() {
    // Mark this alert as seen so it never shows again (in-session + persisted)
    if (_currentAlertId != null) {
      _persistSeenAlertId(_currentAlertId!);
    }
    _currentAlertId = null;
    _flashInformativoMessage = null;
    notifyListeners();
  }

  void _persistSeenAlertId(String alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('seen_alert_$_activeAppId', alertId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _marcaSub?.cancel();
    _emisorasSub?.cancel();
    _tvSub?.cancel();
    super.dispose();
  }
}
