import 'package:flutter/material.dart';
import '../models/tv_channel.dart';

class TvPlayerProvider extends ChangeNotifier {
  TvChannel? _activeChannel;
  bool _isPlaying = false;
  bool _isPipActive = false;
  bool _isMuted = false;

  TvChannel? get activeChannel => _activeChannel;
  bool get isPlaying => _isPlaying;
  bool get isPipActive => _isPipActive;
  bool get isMuted => _isMuted;

  void playChannel(TvChannel channel, {bool autoOpenPip = false, VoidCallback? onPlayVideo}) {
    onPlayVideo?.call();
    _activeChannel = channel;
    _isPlaying = true;
    _isPipActive = autoOpenPip;
    notifyListeners();
  }

  void togglePlayPause() {
    if (_activeChannel == null) return;
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void togglePipMode() {
    if (_activeChannel == null) return;
    _isPipActive = !_isPipActive;
    notifyListeners();
  }

  void setPipActive(bool active) {
    if (_activeChannel == null) return;
    _isPipActive = active;
    notifyListeners();
  }

  void stop() {
    _activeChannel = null;
    _isPlaying = false;
    _isPipActive = false;
    notifyListeners();
  }
}
