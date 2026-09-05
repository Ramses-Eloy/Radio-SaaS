import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/station_provider.dart';
import '../providers/ad_provider.dart';

class GatewayScreen extends StatefulWidget {
  final String appId;

  const GatewayScreen({super.key, required this.appId});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  bool _isCheckingCache = true;
  String? _cachedSplashUrl;
  int _cachedSplashDurationSec = 5;

  bool _splashVisible = false;
  bool _timerRunning = false;
  bool _hasPrecached = false;
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final splashUrl = prefs.getString('splash_url_${widget.appId}');
      final splashEnabled = prefs.getBool('splash_enabled_${widget.appId}') ?? true;
      final splashDuration = prefs.getInt('splash_duration_sec_${widget.appId}') ?? 5;

      if (mounted) {
        setState(() {
          if (splashUrl != null && splashUrl.isNotEmpty && splashEnabled) {
            _cachedSplashUrl = splashUrl;
            _cachedSplashDurationSec = splashDuration;
            _splashVisible = true;
            _secondsRemaining = _cachedSplashDurationSec;
          }
          _isCheckingCache = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingCache = false;
        });
      }
    }
  }

  void _startTimer() {
    if (_timerRunning || _finished) return;
    _timerRunning = true;
    _precacheAssets();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _finishSplash();
      }
    });
  }

  void _finishSplash() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _timerRunning = false;
      });
      _navigateHomeWhenReady();
    }
  }

  void _precacheAssets() {
    if (_hasPrecached || !mounted) return;
    _hasPrecached = true;

    try {
      final stationProvider = context.read<StationProvider>();
      final adProvider = context.read<AdProvider>();

      // Precache all station logos
      for (var station in stationProvider.stations) {
        if (station.logoUrl.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(station.logoUrl), context);
        }
      }

      // Precache the banner image if available
      final bannerUrl = stationProvider.brandBannerHomeUrl.isNotEmpty
          ? stationProvider.brandBannerHomeUrl
          : adProvider.activeCampaign.bottomBannerImageUrl;

      if (bannerUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(bannerUrl), context);
      }
    } catch (e) {
      debugPrint('Error precaching assets: $e');
    }
  }


  void _handleSkip() {
    final stationProvider = context.read<StationProvider>();
    final stationId = stationProvider.currentStation.id;
    context.read<AdProvider>().logAdClick(adType: 'splash', stationId: stationId);
    _finishSplash();
  }

  void _navigateHomeWhenReady() {
    final stationProvider = context.read<StationProvider>();
    if (!stationProvider.isLoading) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      stationProvider.addListener(_onStationProviderChanged);
    }
  }

  void _onStationProviderChanged() {
    final stationProvider = context.read<StationProvider>();
    if (!stationProvider.isLoading && mounted) {
      stationProvider.removeListener(_onStationProviderChanged);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;

    if (_isCheckingCache) {
      return Scaffold(
        backgroundColor: activeTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: activeTheme.primaryColor),
        ),
      );
    }

    if (_splashVisible && _cachedSplashUrl != null && _cachedSplashUrl!.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: _cachedSplashUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
              placeholder: (context, url) => Container(
                color: activeTheme.backgroundColor,
              ),
              imageBuilder: (context, imageProvider) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startTimer();
                });
                return Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                );
              },
              errorWidget: (context, url, error) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _finishSplash();
                });
                return Container(color: Colors.black);
              },
            ),
            
            if (_timerRunning)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: _handleSkip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'OMITIR ($_secondsRemaining)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.skip_next, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (!_timerRunning && _finished)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(color: activeTheme.primaryColor),
                ),
              ),
          ],
        ),
      );
    }

    if (stationProvider.isLoading) {
      return Scaffold(
        backgroundColor: activeTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: activeTheme.primaryColor),
        ),
      );
    }

    if (stationProvider.splashEnabled && stationProvider.splashUrl.isNotEmpty && !_finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _cachedSplashUrl = stationProvider.splashUrl;
            _cachedSplashDurationSec = stationProvider.splashDurationSec;
            _secondsRemaining = _cachedSplashDurationSec;
            _splashVisible = true;
          });
        }
      });
      return Scaffold(
        backgroundColor: activeTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: activeTheme.primaryColor),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_finished) {
        _finished = true;
        Navigator.pushReplacementNamed(context, '/home');
      }
    });

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: activeTheme.primaryColor),
      ),
    );
  }
}
