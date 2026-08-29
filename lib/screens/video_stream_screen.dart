import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/station.dart';
import '../providers/station_provider.dart';
import '../providers/tv_player_provider.dart';
import '../providers/audio_provider.dart';
import '../screens/tv_detail_screen.dart';
import '../widgets/app_cached_image.dart';

class VideoStreamScreen extends StatelessWidget {
  const VideoStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final tvPlayer = context.watch<TvPlayerProvider>();
    final activeTheme = stationProvider.activeThemeConfig;
    final tvChannels = stationProvider.tvChannels;

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: activeTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Streaming & TV en Vivo',
          style: TextStyle(
            color: activeTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description
            Row(
              children: [
                Icon(Icons.ondemand_video_rounded, color: activeTheme.secondaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Canales de Video HD',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona un canal para abrir el reproductor independiente o activar el modo PiP flotante.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),

            const SizedBox(height: 20),

            if (tvChannels.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: activeTheme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.tv_off_rounded, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    Text(
                      'No hay canales de TV configurados para este tenant.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tvChannels.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final tv = tvChannels[index];
                  final isCurrentPlaying = tvPlayer.activeChannel?.id == tv.id && tvPlayer.isPlaying;
                  final channelPrimary = ThemeConfig.parseColor(tv.colorHex, activeTheme.primaryColor);
                  final channelSecondary = ThemeConfig.parseColor(tv.colorSecundarioHex, activeTheme.secondaryColor);

                  return Container(
                    decoration: BoxDecoration(
                      color: activeTheme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrentPlaying
                            ? channelPrimary
                            : channelPrimary.withValues(alpha: 0.5),
                        width: isCurrentPlaying ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        // Primary Glow (Top-Left)
                        BoxShadow(
                          color: isCurrentPlaying
                              ? channelPrimary.withValues(alpha: 0.35)
                              : channelPrimary.withValues(alpha: 0.1),
                          blurRadius: isCurrentPlaying ? 16 : 8,
                          offset: const Offset(-2, -2),
                        ),
                        // Secondary Glow (Bottom-Right)
                        BoxShadow(
                          color: isCurrentPlaying
                              ? channelSecondary.withValues(alpha: 0.35)
                              : channelSecondary.withValues(alpha: 0.1),
                          blurRadius: isCurrentPlaying ? 16 : 8,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Thumbnail Stack
                        Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                child: AppCachedImage(
                                  imageUrl: tv.imageUrl,
                                  fit: BoxFit.contain,
                                  fallbackIconSize: 48,
                                  fallbackIconColor: channelPrimary,
                                ),
                              ),
                            ),

                            // LIVE BADGE
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
                                    SizedBox(width: 5),
                                    Text(
                                      'TRANSMISIÓN EN VIVO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Quick Play Overlay Button
                            Positioned.fill(
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TvDetailScreen(channel: tv),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: activeTheme.primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: activeTheme.primaryColor.withValues(alpha: 0.6),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isCurrentPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 38,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Channel info bar
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tv.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCurrentPlaying ? '▶ Reproduciendo ahora en HD' : 'Señal en directo HD',
                                      style: TextStyle(
                                        color: isCurrentPlaying ? activeTheme.primaryColor : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: isCurrentPlaying ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Enter detail screen button
                              IconButton(
                                icon: const Icon(Icons.open_in_full_rounded, color: Colors.white),
                                tooltip: 'Abrir pantalla de video',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TvDetailScreen(channel: tv),
                                    ),
                                  );
                                },
                              ),

                              // Quick PiP trigger
                              IconButton(
                                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.amber),
                                tooltip: 'Reproducir en PiP flotante',
                                onPressed: () {
                                  context.read<AudioProvider>().pause();
                                  tvPlayer.playChannel(tv, autoOpenPip: true);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
