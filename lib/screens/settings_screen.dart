import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/station_provider.dart';
import '../providers/audio_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _selectedTimerMinutes = 0; // 0 = Off
  Timer? _sleepTimer;

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _selectedTimerMinutes = minutes;
    });

    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (mounted) {
          context.read<AudioProvider>().pause();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🌙 Temporizador de apagado activado: Reproductor pausado.'),
            ),
          );
          setState(() {
            _selectedTimerMinutes = 0;
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ Temporizador configurado a $minutes minutos.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Temporizador desactivado.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareApp() async {
    final url = Uri.parse('https://wa.me/?text= Escucha%20las%20mejores%20estaciones%20y%20TV%20en%20vivo%20en%20nuestra%20App!');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeThumbColor: activeTheme.primaryColor,
                    secondary: Icon(Icons.notifications_active, color: activeTheme.primaryColor),
                    title: const Text('Notificaciones en Vivo', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Recibe alertas cuando tus programas favoritos estén al aire'),
                    value: _notificationsEnabled,
                    onChanged: (val) {
                      setState(() {
                        _notificationsEnabled = val;
                      });
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.timer, color: activeTheme.primaryColor),
                    title: const Text('Temporizador de Apagado (Sleep Timer)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _selectedTimerMinutes == 0
                          ? 'Desactivado'
                          : 'Se apagará en $_selectedTimerMinutes minutos',
                      style: TextStyle(
                        color: _selectedTimerMinutes > 0 ? Colors.amber : Colors.grey,
                      ),
                    ),
                    trailing: DropdownButton<int>(
                      value: _selectedTimerMinutes,
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    subtitle: const Text('Versión 1.0.0'),
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
