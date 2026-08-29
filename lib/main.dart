import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

// Mobile-only providers & screens
import 'providers/station_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/ad_provider.dart';
import 'providers/tv_player_provider.dart';
import 'screens/login_screen.dart';
import 'screens/player_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/video_stream_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/splash_ad_dialog.dart';
import 'widgets/persistent_bottom_banner.dart';
import 'widgets/floating_pip_overlay.dart';
import 'services/telemetry_service.dart';

// Web dashboard
import 'admin/admin_dashboard_screen.dart';
import 'dashboard_web/theme/app_theme.dart';
import 'dashboard_web/theme/theme_controller.dart';

// ─────────────────────────────────────────────
// WEB entry point: a lean MaterialApp that ONLY
// shows the admin dashboard. No mobile providers.
// ─────────────────────────────────────────────
class _WebApp extends StatelessWidget {
  const _WebApp();

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

// ─────────────────────────────────────────────
// MOBILE entry point
// ─────────────────────────────────────────────
Future<String> _determineAppId() async {
  const envAppId = String.fromEnvironment('APP_ID', defaultValue: '');
  if (envAppId.isNotEmpty) return envAppId.toLowerCase();
  try {
    final info = await PackageInfo.fromPlatform();
    final pkg = info.packageName.toLowerCase();
    if (pkg.contains('sira') || pkg.contains('radioapp2')) return 'sira';
    if (pkg.contains('erancon')) return 'erancon';
  } catch (e) {
    if (kDebugMode) print('ℹ️ PackageInfo detection fallback: $e');
  }
  return 'erancon';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.radiowhitelabel.channel.audio',
      androidNotificationChannelName: 'Radio Playback',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationOngoing: true,
    );
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (kIsWeb) {
    // Catch ALL errors on web and show them on screen instead of blank page
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kDebugMode) print('FlutterError: ${details.exception}\n${details.stack}');
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) print('PlatformDispatcher.onError: $error\n$stack');
      return true;
    };

    await loadThemePreference();

    runZonedGuarded(
      () => runApp(const _WebApp()),
      (Object error, StackTrace stack) {
        if (kDebugMode) print('runZonedGuarded error: $error\n$stack');
        runApp(_ErrorApp(error: error, stack: stack));
      },
    );
    return;
  }

  // Mobile path
  final initialAppId = await _determineAppId();
  runApp(RadioWhiteLabelApp(initialAppId: initialAppId));
}

/// Fallback app that displays the error on screen so we can debug it.
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
                style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold),
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

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class RadioWhiteLabelApp extends StatelessWidget {
  final String initialAppId;
  const RadioWhiteLabelApp({super.key, this.initialAppId = 'erancon'});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final provider = StationProvider();
          provider.setFlavorAppId(initialAppId);
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => AdProvider()),
        ChangeNotifierProvider(create: (_) => TvPlayerProvider()),
      ],
      child: Consumer<StationProvider>(
        builder: (context, stationProvider, child) {
          final themeConfig = stationProvider.activeThemeConfig;

          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: stationProvider.brandName,
            debugShowCheckedModeBanner: false,
            themeMode: stationProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              primaryColor: themeConfig.primaryColor,
              scaffoldBackgroundColor: themeConfig.backgroundColor,
              cardColor: themeConfig.cardColor,
              colorScheme: ColorScheme.light(
                primary: themeConfig.primaryColor,
                secondary: themeConfig.secondaryColor,
                surface: themeConfig.cardColor,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              primaryColor: themeConfig.primaryColor,
              scaffoldBackgroundColor: themeConfig.backgroundColor,
              cardColor: themeConfig.cardColor,
              colorScheme: ColorScheme.dark(
                primary: themeConfig.primaryColor,
                secondary: themeConfig.secondaryColor,
                surface: themeConfig.cardColor,
              ),
            ),
            builder: (context, child) {
              return FloatingPipOverlay(child: child ?? const SizedBox.shrink());
            },
            routes: {
              '/': (context) => const MainNavigationFrame(),
              '/login': (context) => const LoginScreen(),
              '/admin': (context) => const AdminDashboardScreen(),
              '/app': (context) => const MainNavigationFrame(),
            },
          );
        },
      ),
    );
  }
}

class MainNavigationFrame extends StatefulWidget {
  const MainNavigationFrame({super.key});

  @override
  State<MainNavigationFrame> createState() => _MainNavigationFrameState();
}

class _MainNavigationFrameState extends State<MainNavigationFrame> {
  int _currentIndex = 0;
  bool _splashShown = false;

  final List<Widget> _screens = const [
    PlayerScreen(),
    ScheduleScreen(),
    VideoStreamScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stationProvider = context.read<StationProvider>();
      stationProvider.addListener(_syncAdConfig);
      _syncAdConfig(); // Sync immediately if data is already loaded

      // Initialize telemetry batching with current appId
      TelemetryService().initialize(appId: stationProvider.activeAppId);
    });
  }

  @override
  void dispose() {
    context.read<StationProvider>().removeListener(_syncAdConfig);
    // Flush any pending telemetry data before the app closes
    TelemetryService().flushAndDispose();
    super.dispose();
  }

  void _syncAdConfig() {
    if (!mounted) return;
    final sp = context.read<StationProvider>();
    final adProvider = context.read<AdProvider>();

    adProvider.syncMarcaAdConfig(
      splashUrl: sp.splashUrl,
      bannerHomeUrl: sp.brandBannerHomeUrl,
    );

    // Show splash only once, and only if splash is enabled and has a URL
    if (!_splashShown && sp.splashEnabled && sp.splashUrl.isNotEmpty) {
      _splashShown = true;
      sp.setSplashShowing(true);
      showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (_) => SplashAdDialog(),
      ).then((_) {
        // Safe to check mounted, but sp is a reference we already have.
        if (mounted) {
          context.read<StationProvider>().setSplashShowing(false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationProvider = context.watch<StationProvider>();
    final activeTheme = stationProvider.activeThemeConfig;

    if (stationProvider.isLoading) {
      return Scaffold(
        backgroundColor: activeTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: activeTheme.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PersistentBottomBanner(),
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: activeTheme.cardColor,
            selectedItemColor: Colors.amber,
            unselectedItemColor: Colors.grey,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.radio_outlined),
                activeIcon: const Icon(Icons.radio),
                label: stationProvider.radioLabel.split(' ').first,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month_outlined),
                activeIcon: const Icon(Icons.calendar_month),
                label: stationProvider.scheduleLabel,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.ondemand_video_outlined),
                activeIcon: const Icon(Icons.ondemand_video),
                label: stationProvider.tvLabel.split(' ').first,
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Ajustes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
