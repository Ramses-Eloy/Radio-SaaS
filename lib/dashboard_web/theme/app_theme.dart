import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Azul de Kosmos: color por defecto del panel (login, superadmin, marcas sin color).
const Color kosmosBlue = Color(0xFF1E6BFF);

/// Tema claro. [seed] es el color de la marca; así cada dueño ve su panel con su color.
ThemeData buildAppTheme([Color seed = kosmosBlue]) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    surface: const Color(0xFFF4F6FB), // Fondo
    surfaceContainerLowest: Colors.white, // Tarjetas
    surfaceContainerLow: Colors.white, // Sidebar
    surfaceContainerHighest: const Color(0xFFEDF0F7), // Inputs / zonas
    outlineVariant: const Color(0xFFE1E6F0),
  );
  return _base(scheme);
}

/// Tema oscuro con el mismo criterio: superficies azul noche con contraste real entre niveles.
ThemeData buildDarkTheme([Color seed = kosmosBlue]) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    // M3 aclara el primario en modo oscuro (tono pastel apagado); usamos el color real de la marca.
    primary: seed,
    onPrimary: _onColor(seed),
    surface: const Color(0xFF090D16), // Fondo
    surfaceContainerLowest: const Color(0xFF111827), // Tarjetas
    surfaceContainerLow: const Color(0xFF0D1320), // Sidebar
    surfaceContainerHighest: const Color(0xFF1A2335), // Inputs / zonas
    outlineVariant: const Color(0xFF232D42),
  );
  return _base(scheme);
}

Color _onColor(Color c) => c.computeLuminance() > 0.45 ? Colors.black : Colors.white;

ThemeData _base(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: scheme.brightness);
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
    headlineSmall: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.headlineSmall, fontWeight: FontWeight.w800),
    titleLarge: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.titleLarge, fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.titleMedium, fontWeight: FontWeight.w700),
  );
  final radius = BorderRadius.circular(12);

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.7 : 1),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      helperStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 12),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.primary : null),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      selectedColor: scheme.primary,
      iconColor: scheme.onSurfaceVariant,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
