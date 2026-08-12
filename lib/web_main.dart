import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'admin/admin_dashboard_screen.dart';
import 'dashboard_web/theme/app_theme.dart';
import 'dashboard_web/theme/theme_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point EXCLUSIVO para Flutter Web (Dashboard Administrativo).
// NO importa ningún paquete de la app móvil (audio, video, PiP, etc.)
// para evitar fallos de registro de plugins en el motor web.
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  // Captura errores visibles antes de que Flutter pueda renderizar
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) print('PlatformDispatcher.onError: $error\n$stack');
    return true;
  };

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await loadThemePreference();

      runApp(const WebDashboardApp());
    },
    (Object error, StackTrace stack) {
      runApp(_ErrorApp(error: error, stack: stack));
    },
  );
}

class WebDashboardApp extends StatelessWidget {
  const WebDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Dashboard Administrativo',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildAppTheme(const Color(0xFF0284C7)),
          darkTheme: buildDarkTheme(const Color(0xFF0284C7)),
          home: const AdminDashboardScreen(),
        );
      },
    );
  }
}

/// Muestra el error en pantalla en lugar de página en blanco.
class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error, required this.stack});
  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Error de inicialización',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                stack.toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
