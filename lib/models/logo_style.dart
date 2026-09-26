import 'package:flutter/material.dart';

/// Cómo se pinta el logo dentro del círculo del reproductor (`emisoras.logo_estilo`).
/// Lo usan la app y el preview del dashboard para que se vean igual.
abstract final class LogoStyle {
  static const Map<String, String> opciones = {
    '': 'Ajustar, fondo blanco',
    'negro': 'Ajustar, fondo negro',
    'marca': 'Ajustar, fondo color de marca',
    'transparente': 'Ajustar, sin fondo',
    'llenar': 'Llenar el círculo',
  };

  static String normalize(String? estilo) => opciones.containsKey(estilo) ? estilo! : '';

  static BoxFit fit(String estilo) => estilo == 'llenar' ? BoxFit.cover : BoxFit.contain;

  /// Relleno interno proporcional al diámetro del círculo.
  static double padding(String estilo, double diameter) => estilo == 'llenar' ? 0 : diameter * 0.05;

  static Color background(String estilo, Color brand) => switch (estilo) {
    'negro' => Colors.black,
    'marca' => brand,
    'transparente' => Colors.transparent,
    _ => Colors.white,
  };
}
