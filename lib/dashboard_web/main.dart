// =============================================================================
// Dashboard administrativo — Radio SaaS (Flutter Web)
// =============================================================================
//
// Despliegue oficial (Firebase Hosting):
//   https://radio-saas-platform.web.app
//
// Este archivo arranca la app y conecta Firebase usando [DefaultFirebaseOptions]
// definido en `lib/firebase_options.dart` (generado o editado con FlutterFire).
//
// Flujo:
//   1. [main] inicializa Firebase y lanza [RadioAdminApp].
//   2. [_AuthGate] escucha [FirebaseAuth.instance.authStateChanges].
//   3. Sin sesión → [LoginScreen] (correo / contraseña).
//   4. Con sesión → [DashboardScreen]: resuelve la marca en `marcas` por `ownerEmail`
//      del usuario y carga emisoras/streamings filtrados por `appId`.
//   5. [EmisoraWorkspace]: edición de nombre, url_audio, url_video, color_hex y redes;
//      Guardar hace merge en el documento (ver `lib/firestore/emisora_fields.dart`).
//
// Material Design 3: tema global en [buildAppTheme] (`lib/theme/app_theme.dart`).
//
// Compilar y desplegar (desde la carpeta `radio_dashboard`):
//   flutter build web --release
// Luego, desde la raíz del repo (donde está `firebase.json`):
//   firebase deploy
// El hosting debe apuntar a `radio_dashboard/build/web` (no a `build/web` suelto
// en la raíz) para evitar la página naranja por defecto de Firebase.
//
// =============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/firebase_options.dart';
import 'package:radio_whitelabel/dashboard_web/screens/dashboard_screen.dart';
import 'package:radio_whitelabel/dashboard_web/screens/login_screen.dart';
import 'package:radio_whitelabel/dashboard_web/services/client_data_store.dart';
import 'package:radio_whitelabel/dashboard_web/services/emisora_repository.dart';
import 'package:radio_whitelabel/dashboard_web/theme/app_theme.dart';
import 'package:radio_whitelabel/dashboard_web/theme/theme_controller.dart';

/// Repositorio y caché global para toda la sesión.
final EmisoraRepository emisoraRepository = EmisoraRepository();
final ClientDataStore clientDataStore = ClientDataStore(emisoraRepository);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Evita "duplicate-app" en hot restart / reinicios donde [main] vuelve a ejecutarse.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await loadThemePreference();
  runApp(const RadioAdminApp());
}

/// Raíz del dashboard: Material 3, tema claro, sin banner de debug en release.
class RadioAdminApp extends StatelessWidget {
  const RadioAdminApp({super.key});
  static const Color _dashboardSeed = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Dashboard Administrativo',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(_dashboardSeed),
          darkTheme: buildDarkTheme(_dashboardSeed),
          themeMode: mode,
          home: const _AuthGate(),
        );
      },
    );
  }
}

/// Conmuta entre login y panel según el estado de autenticación.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _BootstrapScaffold();
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return DashboardScreen(
          repository: emisoraRepository,
          dataStore: clientDataStore,
        );
      },
    );
  }
}

/// Pantalla mínima mientras se resuelve la primera lectura de sesión.
class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.podcasts, size: 48, color: scheme.primary),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Iniciando panel…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
