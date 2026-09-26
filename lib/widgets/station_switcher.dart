import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/program.dart';
import '../models/station.dart';
import '../models/tv_channel.dart';
import '../providers/station_provider.dart';
import '../providers/audio_provider.dart';
import 'app_cached_image.dart';

/// A unified horizontal carousel that shows:
///  - All radio stations (always visible)
///  - TV channels whose [TvChannel.showInCarousel] is true (optional shortcut)
///
/// Tapping a radio card switches the active station and plays audio.
/// Tapping a TV card navigates to the TV/Streaming tab (index 2 in MainNavigator).
class StationSwitcher extends StatelessWidget {
  const StationSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final stations = stationProvider.stations;
    final features = stationProvider.features;

    // TV channels pinned to the carousel
    final carouselTvChannels = features.enableTv
        ? stationProvider.tvChannels.where((c) => c.showInCarousel).toList()
        : <TvChannel>[];

    final totalItems = stations.length + carouselTvChannels.length;

    // Only show the switcher if multi-station is enabled OR there are TV shortcuts
    if ((!features.enableMultiStation || stations.length <= 1) &&
        carouselTvChannels.isEmpty) {
      return const SizedBox.shrink();
    }

    // Also hide if there's nothing to show at all
    if (totalItems <= 1 && carouselTvChannels.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pocas tarjetas: se reparten el ancho por igual. Si no caben, carrusel
    // con tarjetas del mismo ancho. Así se ve bien con 2, 3 o N emisoras.
    const minCardWidth = 130.0;
    const gap = 10.0;

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fits =
              totalItems * minCardWidth + (totalItems - 1) * gap <=
              constraints.maxWidth;
          if (fits) {
            return Row(
              children: [
                for (var i = 0; i < totalItems; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: _buildItem(context, i, stations, carouselTvChannels),
                  ),
                ],
              ],
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: totalItems,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (context, i) => SizedBox(
              width: minCardWidth + 20,
              child: _buildItem(context, i, stations, carouselTvChannels),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    List<Station> stations,
    List<TvChannel> carouselTvChannels,
  ) {
    final stationProvider = context.read<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;

    // ── Radio station card ──────────────────────────────────────
    if (index < stations.length) {
      final station = stations[index];
      final isSelected = index == stationProvider.selectedStationIndex;

      return GestureDetector(
        onTap: () async {
          final audioProvider = context.read<AudioProvider>();
          final sp = context.read<StationProvider>();

          await sp.selectStation(index);

          final liveProgram = sp.currentStationPrograms.firstWhere(
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
        child: _StationCard(
          imageUrl: station.logoUrl,
          name: station.name,
          isSelected: isSelected,
          isLive: station.isLive,
          isTv: false,
          activeTheme: activeTheme,
          isDark: stationProvider.isDark,
        ),
      );
    }

    // ── TV channel shortcut card ────────────────────────────────
    final tvIndex = index - stations.length;
    final tv = carouselTvChannels[tvIndex];

    return GestureDetector(
      onTap: () {
        // Find the real index of the TV tab based on which features are active.
        // Feature order in MainNavigationFrame: radio=0, schedule=+1, tv=+1, settings=+1
        final sp = context.read<StationProvider>();
        final features = sp.features;
        int tvTabIndex = 0;
        if (features.enableRadio) tvTabIndex++; // radio tab offset
        if (features.enableSchedule) tvTabIndex++; // schedule tab offset
        // tvTabIndex now points to the TV screen

        final mainNav = context.findAncestorStateOfType<_MainNavigatorState>();
        if (mainNav != null) {
          mainNav.jumpToTab(tvTabIndex);
        } else {
          Navigator.of(context).pushNamed('/tv');
        }
      },
      child: _StationCard(
        imageUrl: tv.logoCarouselUrl.isNotEmpty
            ? tv.logoCarouselUrl
            : tv.imageUrl,
        name: tv.name,
        isSelected: false,
        isLive: true,
        isTv: true,
        activeTheme: activeTheme,
        isDark: stationProvider.isDark,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal card widget
// ---------------------------------------------------------------------------
class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.imageUrl,
    required this.name,
    required this.isSelected,
    required this.isLive,
    required this.isTv,
    required this.activeTheme,
    required this.isDark,
  });

  final String imageUrl;
  final String name;
  final bool isSelected;
  final bool isLive;
  final bool isTv;
  final ThemeConfig activeTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accentColor = isTv ? Colors.redAccent : activeTheme.primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(alpha: 0.25)
            : activeTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? accentColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.1)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
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
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                fallbackIconColor: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected
                        ? accentColor
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLive ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTv ? 'TV EN VIVO' : (isLive ? 'EN VIVO' : 'OFICIAL'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLive ? Colors.redAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mixin / interface for tab navigation from outside MainNavigator
// ---------------------------------------------------------------------------
/// Any State that manages the bottom-nav tabs should extend this.
/// StationSwitcher uses [findAncestorStateOfType] to call [jumpToTab].
mixin MainNavigatorMixin<T extends StatefulWidget> on State<T> {
  void jumpToTab(int index);
}

// Alias so the lookup type is stable
typedef _MainNavigatorState = MainNavigatorMixin;
