import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/program.dart';
import '../providers/station_provider.dart';
import '../providers/audio_provider.dart';
import 'app_cached_image.dart';

class StationSwitcher extends StatelessWidget {
  const StationSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final stations = stationProvider.stations;
    final activeTheme = stationProvider.activeThemeConfig;

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          final isSelected = index == stationProvider.selectedStationIndex;

          return GestureDetector(
            onTap: () async {
              final audioProvider = context.read<AudioProvider>();
              final stationProvider = context.read<StationProvider>();
              
              await stationProvider.selectStation(index);
              
              final liveProgram = stationProvider.currentStationPrograms.firstWhere(
                (p) => p.isLiveNow,
                orElse: () => Program(
                  id: 'def',
                  stationId: station.id,
                  title: station.slogan,
                  hostName: station.name,
                  hostAvatarUrl: '',
                  category: 'Música',
                  startTime: '00:00',
                  endTime: '24:00',
                  isLiveNow: true,
                ),
              );

              audioProvider.playStream(
                streamUrl: station.streamUrl,
                stationName: station.name,
                stationId: station.id,
                logoUrl: station.logoUrl,
                programTitle: liveProgram.title,
                hostName: liveProgram.hostName,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeTheme.primaryColor.withValues(alpha: 0.25)
                    : activeTheme.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? activeTheme.primaryColor
                      : (stationProvider.themeMode == ThemeMode.light
                          ? Colors.black.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.08)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppCachedImage(
                        imageUrl: station.logoUrl,
                        fit: BoxFit.contain,
                        fallbackIconColor: activeTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        station.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected
                              ? activeTheme.primaryColor
                              : (stationProvider.themeMode == ThemeMode.light
                                  ? Colors.black87
                                  : Colors.white),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: station.isLive ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            station.isLive ? 'EN VIVO' : 'OFICIAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: station.isLive ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
