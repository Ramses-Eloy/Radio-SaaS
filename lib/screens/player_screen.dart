import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/station_provider.dart';
import '../providers/audio_provider.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/station_switcher.dart';
import '../widgets/app_cached_image.dart';
import '../services/telemetry_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _alertDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // Pulsing neon glow animation for the circular logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen for new Avance Informativo in real-time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StationProvider>().addListener(_handleAlertUpdate);
      _handleAlertUpdate(); // Check immediately on mount
    });
  }

  @override
  void dispose() {
    context.read<StationProvider>().removeListener(_handleAlertUpdate);
    _pulseController.dispose();
    super.dispose();
  }

  void _handleAlertUpdate() {
    if (!mounted || _alertDialogShowing) return;
    final stationProvider = context.read<StationProvider>();
    if (stationProvider.isSplashShowing) return;
    
    final msg = stationProvider.flashInformativoMessage;
    if (msg != null && msg.isNotEmpty) {
      _showAvanceInformativo(msg);
    }
  }

  void _showAvanceInformativo(String msg) {
    if (!mounted || _alertDialogShowing) return;
    _alertDialogShowing = true;
    final stationProvider = context.read<StationProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AvanceInformativoDialog(
        message: msg,
        onDismiss: () {
          // Log as ad_click (avance informativo acknowledgement)
          TelemetryService().logEvent(
            eventType: 'ad_click',
            stationId: stationProvider.currentStation.id,
            metadata: {
              'adType': 'avance_informativo',
              'action': 'entendido',
            },
          );
          stationProvider.clearFlashInformativo();
          Navigator.of(ctx).pop();
        },
      ),
    ).whenComplete(() {
      _alertDialogShowing = false;
    });
  }


  Future<void> _launchUrlHelper(BuildContext context, String urlString, String eventType) async {
    final stationProvider = context.read<StationProvider>();
    TelemetryService().logEvent(
      eventType: eventType,
      stationId: stationProvider.currentStation.id,
      targetUrl: urlString,
    );

    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir: $urlString')),
      );
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phoneOrUrl) async {
    final stationProvider = context.read<StationProvider>();
    final cleanPhone = phoneOrUrl.replaceAll(RegExp(r'[^\d+]'), '');
    final text = Uri.encodeComponent('Hola Radio! Escuchando en vivo...');

    final whatsappAppUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$text');
    final whatsappWebUri = Uri.parse('https://wa.me/$cleanPhone?text=$text');

    TelemetryService().logEvent(
      eventType: 'whatsapp_click',
      stationId: stationProvider.currentStation.id,
      targetUrl: 'whatsapp://send?phone=$cleanPhone',
    );

    if (await canLaunchUrl(whatsappAppUri)) {
      await launchUrl(whatsappAppUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(whatsappWebUri)) {
      await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir WhatsApp para: $phoneOrUrl')),
      );
    }
  }

  Future<void> _launchPhoneCall(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'tel:$cleanPhone';
    await _launchUrlHelper(context, url, 'call_click');
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final audioProvider = context.watch<AudioProvider>();
    final currentStation = stationProvider.currentStation;
    final activeTheme = stationProvider.activeThemeConfig;
    final liveProgram = stationProvider.currentLiveProgram;

    if (stationProvider.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117), // Default dark background
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                'Cargando emisoras...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: activeTheme.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppCachedImage(
                  imageUrl: currentStation.logoUrl,
                  fit: BoxFit.contain,
                  fallbackIconColor: activeTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                currentStation.name,
                style: TextStyle(
                  color: activeTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              stationProvider.themeMode == ThemeMode.dark
                  ? Icons.wb_sunny_rounded
                  : Icons.dark_mode_rounded,
              color: activeTheme.primaryColor,
            ),
            onPressed: () => stationProvider.toggleTheme(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Multi-station selector
                const StationSwitcher(),
                const SizedBox(height: 15),

                // Circular Station Logo with pulsing neon glow + EN VIVO badge
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: AppCachedImage(
                            imageUrl: currentStation.logoUrl,
                            fit: BoxFit.contain,
                            fallbackIconSize: 80,
                            fallbackIconColor: activeTheme.primaryColor,
                          ),
                        ),
                      ),
                      builder: (context, child) {
                        return Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: activeTheme.primaryColor
                                    .withValues(alpha: 0.65 * _pulseAnimation.value),
                                blurRadius: 28,
                                spreadRadius: 6 * _pulseAnimation.value,
                              ),
                              BoxShadow(
                                color: activeTheme.primaryColor
                                    .withValues(alpha: 0.3 * _pulseAnimation.value),
                                blurRadius: 56,
                                spreadRadius: 14 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                    ),
                    if (currentStation.isLive)
                      const SizedBox(height: 20),
                    if (currentStation.isLive)
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sensors, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'EN VIVO / AL AIRE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),

                const SizedBox(height: 20),

                // Program / Show info
                Text(
                  liveProgram?.title ?? currentStation.slogan,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  liveProgram != null && liveProgram.hostName.isNotEmpty ? liveProgram.hostName : currentStation.slogan,
                  style: TextStyle(
                    fontSize: 14,
                    color: activeTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // Audio Wave Visualizer
                AudioVisualizer(
                  isPlaying: audioProvider.isPlaying,
                  primaryColor: activeTheme.primaryColor,
                  secondaryColor: activeTheme.secondaryColor,
                ),
                const SizedBox(height: 25),

                // Play / Pause Stream Controls
                GestureDetector(
                  onTap: () {
                    audioProvider.togglePlayPause(
                      streamUrl: currentStation.streamUrl,
                      stationName: currentStation.name,
                      stationId: currentStation.id,
                      logoUrl: currentStation.logoUrl,
                      programTitle: liveProgram?.title,
                      hostName: liveProgram?.hostName,
                    );
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [activeTheme.primaryColor, activeTheme.secondaryColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeTheme.primaryColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: audioProvider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              audioProvider.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Direct Contact Actions (WhatsApp Cabina & Llamar a Cabina)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _launchWhatsApp(context, currentStation.whatsappNumber),
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'WhatsApp Cabina', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _launchPhoneCall(context, currentStation.phoneNumber),
                        icon: const Icon(Icons.phone_in_talk, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Llamar a Cabina', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // Nuestras Redes Header & Icons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Nuestras Redes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: activeTheme.secondaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSocialItem(
                            context,
                            icon: Icons.facebook,
                            label: 'Facebook',
                            color: const Color(0xFF1877F2),
                            url: currentStation.socialLinks.facebook.isNotEmpty
                                ? currentStation.socialLinks.facebook
                                : 'https://facebook.com',
                          ),
                          _buildSocialItem(
                            context,
                            icon: Icons.camera_alt,
                            label: 'Instagram',
                            color: const Color(0xFFE4405F),
                            url: currentStation.socialLinks.instagram.isNotEmpty
                                ? currentStation.socialLinks.instagram
                                : 'https://instagram.com',
                          ),
                          _buildSocialItem(
                            context,
                            icon: Icons.music_note,
                            label: 'TikTok',
                            color: const Color(0xFF00F2FE),
                            url: currentStation.socialLinks.tiktok.isNotEmpty
                                ? currentStation.socialLinks.tiktok
                                : 'https://tiktok.com',
                          ),
                          _buildSocialItem(
                            context,
                            icon: Icons.alternate_email,
                            label: 'Twitter / X',
                            color: const Color(0xFF1DA1F2),
                            url: currentStation.socialLinks.twitter.isNotEmpty
                                ? currentStation.socialLinks.twitter
                                : 'https://x.com',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return InkWell(
      onTap: () => _launchUrlHelper(context, url, 'social_click'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Avance Informativo Dialog with 5s countdown
// and animated progress bar
// ─────────────────────────────────────────────
class _AvanceInformativoDialog extends StatefulWidget {
  const _AvanceInformativoDialog({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_AvanceInformativoDialog> createState() => _AvanceInformativoDialogState();
}

class _AvanceInformativoDialogState extends State<_AvanceInformativoDialog>
    with SingleTickerProviderStateMixin {
  static const _durationSeconds = 5;
  late AnimationController _progressController;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _durationSeconds),
    )..forward();

    _autoDismissTimer = Timer(const Duration(seconds: _durationSeconds), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.campaign, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text(
            'AVANCE INFORMATIVO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.message,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Countdown progress bar
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              final remaining = (_durationSeconds * (1 - _progressController.value)).ceil();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 1.0 - _progressController.value,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Se cierra en ${remaining}s',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          onPressed: widget.onDismiss,
          child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
