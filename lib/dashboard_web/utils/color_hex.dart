import 'package:flutter/material.dart';

/// Convierte y valida colores en formato hex (#RRGGBB) para Firestore.
abstract final class ColorHex {
  static const String defaultHex = '#1E3A5F';

  /// Acepta #RGB, #RRGGBB, RRGGBB, etc. Devuelve null si no es válido.
  static Color? tryParse(String? input) {
    if (input == null) return null;
    String s = input.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6 && s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    if (s.length == 6) {
      return Color(0xFF000000 | value);
    }
    return Color(value);
  }

  /// Siempre devuelve #RRGGBB en mayúsculas (sin canal alpha en Firestore).
  static String toRgbHex(Color color) {
    final v = color.toARGB32() & 0x00FFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Normaliza entrada de usuario; si falla, [defaultHex].
  static String normalize(String input) {
    final c = tryParse(input);
    if (c == null) return defaultHex;
    return toRgbHex(c);
  }
}
