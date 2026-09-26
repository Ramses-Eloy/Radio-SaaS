import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/logo_style.dart';
import '../models/station.dart';
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
    final logoStyle = LogoStyle.normalize(currentStation.logoStyle);
    final liveProgram = stationProvider.currentLiveProgram;
    final programTitle = liveProgram?.title.trim() ?? '';
    final slogan = currentStation.slogan.trim();
    final infoTitle = programTitle.isNotEmpty ? programTitle : slogan;
    final host = liveProgram?.hostName.trim() ?? '';
    final infoSubtitle = host.isNotEmpty ? host : (programTitle.isNotEmpty ? slogan : '');

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
              stationProvider.isDark
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
                          padding: EdgeInsets.all(LogoStyle.padding(logoStyle, 240)),
                          child: AppCachedImage(
                            imageUrl: currentStation.logoUrl,
                            fit: LogoStyle.fit(logoStyle),
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
                            color: LogoStyle.background(logoStyle, activeTheme.primaryColor),
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

                // Programa al aire; si no hay, el eslogan. Campos vacíos no se pintan.
                if (infoTitle.isNotEmpty)
                  Text(
                    infoTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (infoSubtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    infoSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: activeTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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

                _buildCabinaButtons(context, activeTheme, currentStation),
                const SizedBox(height: 25),

                // Nuestras Redes Header & Icons
                if (currentStation.socialLinks.hasAny) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: stationProvider.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
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
                          if (currentStation.socialLinks.facebook.isNotEmpty)
                          _buildSocialItem(
                            context,
                            icon: Icons.facebook,
                            label: 'Facebook',
                            color: const Color(0xFF1877F2),
                            url: currentStation.socialLinks.facebook,
                          ),
                          if (currentStation.socialLinks.instagram.isNotEmpty)
                          _buildSocialItem(
                            context,
                            icon: Icons.camera_alt,
                            label: 'Instagram',
                            color: const Color(0xFFE4405F),
                            url: currentStation.socialLinks.instagram,
                          ),
                          if (currentStation.socialLinks.tiktok.isNotEmpty)
                          _buildSocialItem(
                            context,
                            icon: Icons.music_note,
                            label: 'TikTok',
                            color: const Color(0xFF00F2FE),
                            url: currentStation.socialLinks.tiktok,
                          ),
                          if (currentStation.socialLinks.twitter.isNotEmpty)
                          _buildSocialItem(
                            context,
                            icon: Icons.alternate_email,
                            label: 'Twitter / X',
                            color: const Color(0xFF1DA1F2),
                            url: currentStation.socialLinks.twitter,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botones de cabina. Con 'AM/FM' y números distintos por banda, el botón
  /// abre un selector AM/FM; si uno está vacío o se repite, usa el otro directo.
  Widget _buildCabinaButtons(BuildContext context, ThemeConfig activeTheme, Station station) {
    Map<String, String> porBanda(String am, String fm) {
      if (station.band == 'AM/FM' && am.isNotEmpty && fm.isNotEmpty && am != fm) {
        return {'AM': am, 'FM': fm};
      }
      return {'': fm.isEmpty ? am : fm};
    }

    final suffix = station.band.isEmpty || station.band == 'AM/FM' ? '' : ' ${station.band}';
    // Sin número configurado el botón no se muestra (antes abría WhatsApp/llamada vacíos).
    final hasWhatsapp = station.whatsappNumber.isNotEmpty || station.whatsappNumberAm.isNotEmpty;
    final hasPhone = station.phoneNumber.isNotEmpty || station.phoneNumberAm.isNotEmpty;

    return Row(
      children: [
        if (hasWhatsapp)
          Expanded(
            child: _cabinaButton(
              const Color(0xFF25D366),
              Icons.chat_bubble_outline,
              'WhatsApp Cabina$suffix',
              () => _elegirBanda(context, porBanda(station.whatsappNumberAm, station.whatsappNumber),
                  (n) => _launchWhatsApp(context, n)),
            ),
          ),
        if (hasWhatsapp && hasPhone) const SizedBox(width: 8),
        if (hasPhone)
          Expanded(
            child: _cabinaButton(
              activeTheme.primaryColor,
              Icons.phone_in_talk,
              'Llamar a Cabina$suffix',
              () => _elegirBanda(context, porBanda(station.phoneNumberAm, station.phoneNumber),
                  (n) => _launchPhoneCall(context, n)),
            ),
          ),
      ],
    );
  }

  /// Con una sola opción la abre directo; con AM y FM pregunta cuál.
  Future<void> _elegirBanda(BuildContext context, Map<String, String> opciones, void Function(String) abrir) async {
    if (opciones.length == 1) {
      abrir(opciones.values.first);
      return;
    }
    final numero = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in opciones.entries)
              ListTile(
                leading: const Icon(Icons.settings_input_antenna),
                title: Text('Cabina ${e.key}'),
                onTap: () => Navigator.pop(ctx, e.value),
              ),
          ],
        ),
      ),
    );
    if (numero != null && context.mounted) abrir(numero);
  }

  Widget _cabinaButton(Color color, IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
