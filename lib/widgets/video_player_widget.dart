import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String streamUrl;
  final String fallbackImageUrl;
  final bool autoPlay;
  final bool isPlaying;

  const VideoPlayerWidget({
    super.key,
    required this.streamUrl,
    this.fallbackImageUrl = '',
    this.autoPlay = true,
    this.isPlaying = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  YoutubePlayerController? _youtubeController;

  bool _isYoutube = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _disposeControllers();
      _initializePlayer();
    } else if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _videoPlayerController?.play();
        _youtubeController?.play();
      } else {
        _videoPlayerController?.pause();
        _youtubeController?.pause();
      }
    }
  }

  void _disposeControllers() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _youtubeController?.dispose();
    _youtubeController = null;
  }

  Future<void> _initializePlayer() async {
    final url = widget.streamUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'No hay enlace de streaming disponible';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      _isYoutube = true;
      String? videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId == null && url.contains('/live/')) {
        videoId = url.split('/live/')[1].split('?')[0];
      }

      if (videoId != null && videoId.isNotEmpty) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(
            autoPlay: widget.autoPlay,
            isLive: true,
            useHybridComposition: true,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Enlace de YouTube no válido';
        });
      }
    } else {
      _isYoutube = false;
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _videoPlayerController = controller;
        await controller.initialize();
        if (widget.autoPlay) {
          await controller.play();
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'No se pudo conectar con el servidor de video ($url)';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purpleAccent),
              SizedBox(height: 12),
              Text(
                'Conectando transmisión en vivo...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: const Color(0xFF161B22),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 42),
              const SizedBox(height: 10),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isYoutube && _youtubeController != null) {
      return Center(
        child: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.purpleAccent,
          progressColors: const ProgressBarColors(
            playedColor: Colors.purpleAccent,
            handleColor: Colors.purple,
          ),
        ),
      );
    }

    if (!_isYoutube && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      return SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _videoPlayerController!.value.size.width,
                  height: _videoPlayerController!.value.size.height,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: FloatingActionButton.small(
                backgroundColor: Colors.black54,
                child: Icon(
                  _videoPlayerController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    if (_videoPlayerController!.value.isPlaying) {
                      _videoPlayerController!.pause();
                    } else {
                      _videoPlayerController!.play();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.tv, color: Colors.purpleAccent, size: 48),
      ),
    );
  }
}
