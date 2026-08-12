import 'package:flutter/material.dart';

/// Formatea y parsea el campo `h` de programación sin alterar su estructura en Firestore.
abstract final class ProgramacionHorarioFormat {
  /// Formato estricto de 24 horas: `14:00`.
  static String format(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Concatena inicio y fin en el formato persistido: `"14:00 - 15:30"`.
  static String build({TimeOfDay? start, TimeOfDay? end}) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '${format(start)} - ${format(end)}';
    }
    if (start != null) return format(start);
    return format(end!);
  }

  /// Interpreta valores existentes (`14:00 - 15:30`, `01:00 PM - 02:00 PM`, `5:00 AM A 5:30 AM`, etc.).
  static ({TimeOfDay? start, TimeOfDay? end}) parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return (start: null, end: null);

    if (trimmed.contains(' - ')) {
      final parts = trimmed.split(' - ');
      if (parts.length >= 2) {
        return (
          start: _parseSingleTime(parts[0]),
          end: _parseSingleTime(parts[1]),
        );
      }
    }

    final legacyParts = trimmed.split(RegExp(r'\s+A\s+', caseSensitive: false));
    if (legacyParts.length >= 2) {
      return (
        start: _parseSingleTime(legacyParts[0]),
        end: _parseSingleTime(legacyParts[1]),
      );
    }

    final single = _parseSingleTime(trimmed);
    return (start: single, end: null);
  }

  static TimeOfDay? _parseSingleTime(String raw) {
    final trimmed = raw.trim();

    final match12 = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(trimmed);
    if (match12 != null) {
      var hour = int.parse(match12.group(1)!);
      final minute = int.parse(match12.group(2)!);
      final isPm = match12.group(3)!.toUpperCase() == 'PM';

      if (hour == 12) {
        hour = isPm ? 12 : 0;
      } else if (isPm) {
        hour += 12;
      }

      return TimeOfDay(hour: hour, minute: minute);
    }

    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (match24 != null) {
      final hour = int.parse(match24.group(1)!);
      final minute = int.parse(match24.group(2)!);
      if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }
}
