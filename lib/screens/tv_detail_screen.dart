import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import '../models/tv_channel.dart';
import '../providers/station_provider.dart';
import '../providers/tv_player_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/video_player_widget.dart';

class TvDetailScreen extends StatefulWidget {
  final TvChannel channel;

  const TvDetailScreen({super.key, required this.channel});

  @override
  State<TvDetailScreen> createState() => _TvDetailScreenState();
}

class _TvDetailScreenState extends State<TvDetailScreen>
    with WidgetsBindingObserver {
  bool _showControls = true;
  Timer? _hideTimer;
  final SimplePip _simplePip = SimplePip();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetHideTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (Platform.isAndroid) {
      _simplePip.setAutoPipMode(
        aspectRatio: const (16, 9),
        autoEnter: true,
        seamlessResize: true,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AudioProvider>().pause();
        context.read<TvPlayerProvider>().playChannel(widget.channel);
      }
    });
  }

  bool _isRotating = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && Platform.isAndroid && !_isRotating) {
      final tvPlayer = context.read<TvPlayerProvider>();
      if (tvPlayer.isPlaying && tvPlayer.activeChannel != null) {
        _simplePip.enterPipMode();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    if (Platform.isAndroid) {
      _simplePip.setAutoPipMode(autoEnter: false);
    }
    // Restore portrait orientation on exit
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() => _showControls = true);
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  Future<void> _toggleLandscape() async {
    setState(() => _isRotating = true);
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _resetHideTimer();
    // Wait for the orientation change to finish and the lifecycle state to settle
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _isRotating = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final tvPlayer = context.watch<TvPlayerProvider>();
    final activeTheme = stationProvider.activeThemeConfig;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _resetHideTimer,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Full Screen Video Player Area
            Positioned.fill(
              child: VideoPlayerWidget(
                streamUrl: widget.channel.streamUrl,
                fallbackImageUrl: widget.channel.imageUrl,
                autoPlay: true,
                isPlaying: tvPlayer.isPlaying,
              ),
            ),

            // Top Gradient Bar & Actions
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: isLandscape ? 8 : MediaQuery.of(context).padding.top + 4,
                      left: 12,
                      right: 12,
                      bottom: 12,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.channel.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Play/Pause button
                        IconButton(
                          icon: Icon(
                            tvPlayer.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                          ),
                          tooltip: tvPlayer.isPlaying ? 'Pausar' : 'Reproducir',
                          onPressed: () => tvPlayer.togglePlayPause(),
                        ),
                        // Landscape toggle button
                        IconButton(
                          icon: Icon(
                            isLandscape
                                ? Icons.screen_lock_portrait_rounded
                                : Icons.screen_rotation_rounded,
                            color: Colors.white,
                          ),
                          tooltip: isLandscape ? 'Modo Vertical' : 'Modo Horizontal',
                          onPressed: _toggleLandscape,
                        ),
                        // PiP button
                        IconButton(
                          icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.amber),
                          tooltip: 'Minimizar a PiP Flotante',
                          onPressed: () {
                            tvPlayer.playChannel(widget.channel, autoOpenPip: true);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Info Overlay — auto-hides after 3s
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: isLandscape ? 12 : 24,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: activeTheme.cardColor,
                          backgroundImage: NetworkImage(widget.channel.imageUrl),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.channel.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Transmisión HD en Directo',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.redAccent),
                              SizedBox(width: 6),
                              Text(
                                'EN VIVO',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
