import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/station_provider.dart';
import '../providers/audio_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _setSleepTimer(int minutes) {
    final messenger = ScaffoldMessenger.of(context);
    context.read<AudioProvider>().setSleepTimer(
      minutes,
      onFired: () => messenger.showSnackBar(
        const SnackBar(
          content: Text('🌙 Temporizador de apagado activado: Reproductor pausado.'),
        ),
      ),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(minutes > 0
            ? '⏱️ Temporizador configurado a $minutes minutos.'
            : '⏱️ Temporizador desactivado.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareApp() async {
    final stationProvider = context.read<StationProvider>();
    final shareText = stationProvider.shareText;
    final playStoreUrl = stationProvider.playStoreUrl;
    final appStoreUrl = stationProvider.appStoreUrl;

    String url = '';
    if (Platform.isAndroid && playStoreUrl.isNotEmpty) {
      url = playStoreUrl;
    } else if (Platform.isIOS && appStoreUrl.isNotEmpty) {
      url = appStoreUrl;
    }

    final message = url.isNotEmpty ? '$shareText\n$url' : shareText;
    
    await SharePlus.instance.share(ShareParams(text: message));
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;
    final sleepMinutes = context.watch<AudioProvider>().sleepMinutes;
    final cardBorder = stationProvider.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: activeTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Configuración',
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
            // General Settings Card
            Container(
              decoration: BoxDecoration(
                color: activeTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: activeTheme.primaryColor,
                    secondary: Icon(Icons.notifications_active, color: activeTheme.primaryColor),
                    title: const Text('Notificaciones en Vivo', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Recibe alertas cuando tus programas favoritos estén al aire'),
                    value: stationProvider.notificationsEnabled,
                    onChanged: (val) {
                      stationProvider.toggleNotifications(val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.timer, color: activeTheme.primaryColor),
                    title: const Text('Temporizador de Apagado', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      sleepMinutes == 0
                          ? 'Desactivado'
                          : 'Se apagará en $sleepMinutes minutos',
                      style: TextStyle(
                        color: sleepMinutes > 0 ? Colors.amber : Colors.grey,
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: sleepMinutes,
                      dropdownColor: activeTheme.cardColor,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Off')),
                        DropdownMenuItem(value: 15, child: Text('15 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                        DropdownMenuItem(value: 45, child: Text('45 min')),
                        DropdownMenuItem(value: 60, child: Text('60 min')),
                      ],
                      onChanged: (val) {
                        if (val != null) _setSleepTimer(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Share & Info Card
            Container(
              decoration: BoxDecoration(
                color: activeTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.share, color: activeTheme.secondaryColor),
                    title: const Text('Compartir Aplicación', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Recomienda esta app a tus amigos y familiares'),
                    onTap: _shareApp,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.info_outline, color: activeTheme.secondaryColor),
                    title: Text(stationProvider.brandName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) =>
                          Text(snap.hasData ? 'Versión ${snap.data!.version}' : ''),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'OFICIAL',
                        style: TextStyle(color: activeTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
