import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../services/telemetry_service.dart';

class AudioProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentStreamUrl = '';
  String _currentStationName = '';

  AudioPlayer get audioPlayer => _audioPlayer;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String get currentStationName => _currentStationName;

  AudioProvider() {
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _audioPlayer.stop();
    }
  }

  Future<void> updateStationMetadata({
    required String streamUrl,
    required String stationName,
    required String stationId,
    String? logoUrl,
    String? programTitle,
    String? hostName,
  }) async {
    _currentStreamUrl = streamUrl;
    _currentStationName = stationName;
    notifyListeners();

    final displayTitle = programTitle != null && programTitle.isNotEmpty ? programTitle : stationName;
    final displaySub = hostName != null && hostName.isNotEmpty
        ? hostName
        : 'En Vivo';

    Uri? artUri;
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      try {
        artUri = Uri.parse(logoUrl.trim());
      } catch (_) {}
    }

    try {
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: MediaItem(
            id: '${stationId}_${DateTime.now().millisecondsSinceEpoch}',
            album: stationName,
            title: displayTitle,
            artist: displaySub,
            artUri: artUri,
          ),
        ),
        preload: false,
      );
    } catch (_) {}
  }

  Future<void> playStream({
    required String streamUrl,
    required String stationName,
    required String stationId,
    String? logoUrl,
    String? programTitle,
    String? hostName,
  }) async {
    try {
      final isSameStream = _currentStreamUrl == streamUrl && _currentStationName == stationName;
      if (isSameStream && _isPlaying) {
        return;
      }
      _isLoading = true;
      _currentStreamUrl = streamUrl;
      _currentStationName = stationName;
      notifyListeners();

      final displayTitle = programTitle != null && programTitle.isNotEmpty ? programTitle : stationName;
      final displaySub = hostName != null && hostName.isNotEmpty
          ? hostName
          : 'En Vivo';

      Uri? artUri;
      if (logoUrl != null && logoUrl.trim().isNotEmpty) {
        try {
          artUri = Uri.parse(logoUrl.trim());
        } catch (_) {}
      }

      await _audioPlayer.stop(); // Stop before changing source to force notification refresh
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: MediaItem(
            id: '${stationId}_${DateTime.now().millisecondsSinceEpoch}',
            album: stationName,
            title: displayTitle,
            artist: displaySub,
            artUri: artUri,
          ),
        ),
      );
      await _audioPlayer.play();

      TelemetryService().logEvent(
        eventType: 'audio_play',
        stationId: stationId,
        metadata: {'streamUrl': streamUrl, 'stationName': stationName},
      );
    } catch (e) {
      _isLoading = false;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> togglePlayPause({
    required String streamUrl,
    required String stationName,
    required String stationId,
    String? logoUrl,
    String? programTitle,
    String? hostName,
  }) async {
    if (_isPlaying) {
      await pause();
    } else {
      await playStream(
        streamUrl: streamUrl,
        stationName: stationName,
        stationId: stationId,
        logoUrl: logoUrl,
        programTitle: programTitle,
        hostName: hostName,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }
}
