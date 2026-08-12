import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tv_player_provider.dart';
import '../providers/station_provider.dart';
import '../screens/tv_detail_screen.dart';
import 'video_player_widget.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import '../main.dart' as import_main;

class FloatingPipOverlay extends StatefulWidget {
  final Widget child;

  const FloatingPipOverlay({super.key, required this.child});

  @override
  State<FloatingPipOverlay> createState() => _FloatingPipOverlayState();
}

class _FloatingPipOverlayState extends State<FloatingPipOverlay> {
  Offset _pipPosition = const Offset(16, 100);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return widget.child;
    }
    final tvPlayer = context.watch<TvPlayerProvider>();
    final stationProvider = context.watch<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;
    final activeChannel = tvPlayer.activeChannel;
    final isPip = tvPlayer.isPipActive && activeChannel != null;

    final mediaQuery = MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size ?? const Size(800, 600);

    return Stack(
      children: [
        widget.child,

        if (isPip)
          Positioned(
            left: _pipPosition.dx,
            top: _pipPosition.dy,
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    double newX = _pipPosition.dx + details.delta.dx;
                    double newY = _pipPosition.dy + details.delta.dy;
                    newX = newX.clamp(10.0, (screenSize.width - 210.0).clamp(10.0, screenSize.width));
                    newY = newY.clamp(50.0, (screenSize.height - 180.0).clamp(50.0, screenSize.height));
                    _pipPosition = Offset(newX, newY);
                  });
                },
                onTap: () {
                  tvPlayer.setPipActive(false);
                  
                  // Use the app navigator key instead of the overlay's context
                  import_main.appNavigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => TvDetailScreen(channel: activeChannel),
                    ),
                  );
                },
              child: Container(
                width: 200,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: activeTheme.primaryColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Video Stream Player
                      Positioned.fill(
                        child: VideoPlayerWidget(
                          streamUrl: activeChannel.streamUrl,
                          fallbackImageUrl: activeChannel.imageUrl,
                          autoPlay: true,
                        ),
                      ),

                      // Live indicator dot
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(radius: 2.5, backgroundColor: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Close PiP Button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => tvPlayer.stop(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
