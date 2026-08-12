import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Control global de tema (claro/oscuro) para Flutter Web.
///
/// Es intencionalmente simple: un dashboard administrativo no requiere persistencia
/// local compleja; se guarda solo la preferencia de modo oscuro.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

const _prefKeyThemeMode = 'radio_dashboard.themeMode';
const _prefKeyThemeModeDark = 'radio_dashboard.themeModeDark';

Future<void> loadThemePreference() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final asBool = prefs.getBool(_prefKeyThemeModeDark);
    if (asBool != null) {
      themeModeNotifier.value = asBool ? ThemeMode.dark : ThemeMode.light;
      return;
    }
    final raw = prefs.getString(_prefKeyThemeMode);
    if (raw == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else if (raw == 'light') {
      themeModeNotifier.value = ThemeMode.light;
    }
  } catch (_) {
    // Si falla el storage local (modo incógnito / restricciones), se mantiene el modo por defecto.
  }
}

Future<void> persistThemePreference(ThemeMode mode) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyThemeModeDark, mode == ThemeMode.dark);
    await prefs.setString(_prefKeyThemeMode, mode == ThemeMode.dark ? 'dark' : 'light');
  } catch (_) {
    // Ignorar: preferencia no crítica.
  }
}

