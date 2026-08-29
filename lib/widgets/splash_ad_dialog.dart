import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ad_provider.dart';
import 'app_cached_image.dart';

class SplashAdDialog extends StatefulWidget {
  const SplashAdDialog({super.key});

  @override
  State<SplashAdDialog> createState() => _SplashAdDialogState();
}

class _SplashAdDialogState extends State<SplashAdDialog> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final duration = context.read<AdProvider>().activeCampaign.splashDurationSeconds;
    _secondsRemaining = duration.clamp(1, 5);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _timer?.cancel();
    if (mounted) {
      context.read<AdProvider>().dismissSplashAd();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adProvider = context.watch<AdProvider>();
    final campaign = adProvider.activeCampaign;

    if (!campaign.isActive) return const SizedBox.shrink();

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full Screen Image
          AppCachedImage(
            imageUrl: campaign.splashImageUrl,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fallbackIconSize: 80,
            fallbackIconColor: Colors.amber,
            placeholder: const SizedBox.shrink(),
          ),

          // Top Skip Button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Material(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _dismiss,
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
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.close, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
