import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';

typedef ProgramacionImportRow = ({String h, String p, String t});

class ProgramacionImportResult {
  ProgramacionImportResult(this.byDay, this.ignored);

  /// Filas por día (`lunes`, `martes`, …) en el orden en que venían.
  final Map<String, List<ProgramacionImportRow>> byDay;

  /// Líneas que no se pudieron interpretar.
  final List<String> ignored;

  int get total => byDay.values.fold(0, (sum, rows) => sum + rows.length);
}

/// Convierte texto pegado desde Excel/Sheets (tabulado), CSV o texto libre en filas de programación.
///
/// Formatos aceptados por línea:
/// - `Lunes | 6:00 | 9:00 | Programa | DJ` (columnas separadas por tab, `;` o `,`)
/// - `Lunes a Viernes | 6:00 AM - 9:00 AM | Programa | DJ`
/// - `6:00 | 9:00 | Programa` (sin día: usa el último encabezado de día o [defaultDay])
/// - Texto libre: `Lunes a Viernes` en una línea y debajo `6:00 - 9:00 Programa - DJ`
abstract final class ProgramacionImport {
  static const List<String> dayKeys = [
    EmisoraFields.lunes,
    EmisoraFields.martes,
    EmisoraFields.miercoles,
    EmisoraFields.jueves,
    EmisoraFields.viernes,
    EmisoraFields.sabado,
    EmisoraFields.domingo,
  ];

  static ProgramacionImportResult parse(String text, {required String defaultDay}) {
    final byDay = <String, List<ProgramacionImportRow>>{};
    final ignored = <String>[];
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    final delimiter = _detectDelimiter(lines);
    var currentDays = <String>[defaultDay];

    for (final line in lines) {
      final cells = (delimiter == null ? [line] : _splitCells(line, delimiter)).map((c) => c.trim()).toList();
      while (cells.isNotEmpty && cells.last.isEmpty) {
        cells.removeLast();
      }
      if (cells.isEmpty) continue;

      final days = parseDays(cells.first);
      if (days.isNotEmpty && cells.length == 1) {
        currentDays = days; // Encabezado de bloque: "LUNES A VIERNES".
        continue;
      }

      final row = cells.length == 1
          ? _parseFreeText(cells.first)
          : _parseCells(days.isNotEmpty ? cells.sublist(1) : cells);
      final rowDays = cells.length == 1 ? (row?.days ?? const <String>[]) : days;
      if (row == null) {
        ignored.add(line.trim());
        continue;
      }
      for (final day in rowDays.isNotEmpty ? rowDays : currentDays) {
        byDay.putIfAbsent(day, () => []).add(row.row);
      }
    }
    return ProgramacionImportResult(byDay, ignored);
  }

  static String? _detectDelimiter(List<String> lines) {
    if (lines.any((l) => l.contains('\t'))) return '\t';
    for (final d in [';', ',']) {
      final withDelimiter = lines.where((l) => d.allMatches(l).isNotEmpty).length;
      if (withDelimiter * 2 >= lines.length) return d;
    }
    return null;
  }

  static List<String> _splitCells(String line, String delimiter) {
    final cells = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == delimiter && !inQuotes) {
        cells.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    cells.add(current.toString());
    return cells;
  }

  static ({List<String> days, ProgramacionImportRow row})? _parseCells(List<String> cells) {
    if (cells.isEmpty) return null;
    var rest = cells;
    String h;
    final range = _parseRange(rest.first);
    if (range != null) {
      h = range;
      rest = rest.sublist(1);
    } else {
      final start = parseTime(rest.first);
      if (start == null) return null;
      final end = rest.length > 1 ? parseTime(rest[1]) : null;
      h = end != null ? '$start - $end' : start;
      rest = rest.sublist(end != null ? 2 : 1);
    }
    final p = rest.isNotEmpty ? rest[0] : '';
    final t = rest.length > 1 ? rest.sublist(1).where((c) => c.isNotEmpty).join(' / ') : '';
    return (days: const <String>[], row: (h: h, p: p, t: t));
  }

  static final RegExp _timeToken = RegExp(
    r'\d{1,2}(?:[:.]\d{2}){0,2}(?:\s*[ap]\.?\s?m\.?(?![a-z]))?(?:\s*h(?:rs?|s)?\.?(?![a-z]))?',
    caseSensitive: false,
  );

  static final RegExp _freeText = RegExp(
    '^(.*?)(${_timeToken.pattern})\\s*(?:-|–|—|\\sa\\s|\\sal\\s|\\shasta\\s)\\s*(${_timeToken.pattern})(.*)\$',
    caseSensitive: false,
  );

  /// `Lunes 6:00 - 9:00 Programa - DJ`, `6 am a 9 am: Programa | DJ`.
  static ({List<String> days, ProgramacionImportRow row})? _parseFreeText(String line) {
    final m = _freeText.firstMatch(line);
    if (m == null) return null;
    final prefix = m.group(1)!.trim().replaceFirst(RegExp(r'\s*(?:\bde|\bdesde|[:,-])$', caseSensitive: false), '');
    final days = prefix.isEmpty ? const <String>[] : parseDays(prefix);
    if (prefix.isNotEmpty && days.isEmpty) return null;
    final start = parseTime(m.group(2)!);
    final end = parseTime(m.group(3)!);
    if (start == null || end == null) return null;
    final text = m.group(4)!.trim().replaceFirst(RegExp(r'^[-–—:|]\s*'), '');
    final parts = text.split(RegExp(r'\s+[-–—|]\s+|\s*\|\s*'));
    return (
      days: days,
      row: (
        h: '$start - $end',
        p: parts.first.trim(),
        t: parts.skip(1).map((s) => s.trim()).where((s) => s.isNotEmpty).join(' / '),
      ),
    );
  }

  /// `6:00 - 9:00`, `6:00 AM A 9:00 AM`, `06:00 a 09:00` → `06:00 - 09:00`.
  static String? _parseRange(String raw) {
    final parts = raw.trim().split(RegExp(r'\s*[-–—]\s*|\s+(?:a|al|hasta)\s+', caseSensitive: false));
    if (parts.length != 2) return null;
    final start = parseTime(parts[0]);
    final end = parseTime(parts[1]);
    if (start == null || end == null) return null;
    return '$start - $end';
  }

  /// `6:00`, `06:00`, `6:00 AM`, `6 pm`, `6:00 p. m.`, `18h`, `18:00:00` → `HH:mm`.
  static String? parseTime(String raw) {
    final s = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
    final m =
        RegExp(r'^(\d{1,2})(?:[:h](\d{2}))?(?::\d{2})?(am|pm)?(?:h|hs|hrs?)?$').firstMatch(s) ??
        RegExp(r'^(\d{1,2})(\d{2})(am|pm)?$').firstMatch(s); // "6.30" queda como "630"
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2) ?? '0');
    final suffix = m.group(3);
    if (minute > 59) return null;
    if (suffix != null) {
      if (hour < 1 || hour > 12) return null;
      if (hour == 12) hour = 0;
      if (suffix == 'pm') hour += 12;
    }
    if (hour == 24 && minute == 0) hour = 0;
    if (hour > 23) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// `Lunes`, `Lun`, `Lunes a Viernes`, `Lun-Vie`, `Sábado y Domingo`, `Fin de semana`, `Diario`.
  static List<String> parseDays(String raw) {
    final s = _normalize(raw).replaceAll(RegExp(r'[:.]+$'), '').trim();
    if (s.isEmpty) return const [];
    if (RegExp(r'^(todos( los dias)?|diario|toda la semana)$').hasMatch(s)) return dayKeys;
    if (s == 'fin de semana' || s == 'fines de semana') return dayKeys.sublist(5);
    if (s == 'entre semana') return dayKeys.sublist(0, 5);

    final out = <String>[];
    for (final part in s.split(RegExp(r'\s*(?:,|/|&|\sy\s)\s*'))) {
      final ends = part.split(RegExp(r'\s*-\s*|\s+(?:a|al)\s+'));
      if (ends.length > 2) return const [];
      final from = _dayIndex(ends.first);
      final to = _dayIndex(ends.last);
      if (from == null || to == null) return const [];
      for (var i = from; ; i = (i + 1) % 7) {
        if (!out.contains(dayKeys[i])) out.add(dayKeys[i]);
        if (i == to) break;
      }
    }
    return out;
  }

  static int? _dayIndex(String word) {
    final w = word.trim();
    if (w.length < 2) return null;
    final i = dayKeys.indexWhere((d) => d.startsWith(w));
    return i < 0 ? null : i;
  }

  static String _normalize(String s) {
    const from = 'áéíóúü';
    const to = 'aeiouu';
    final lower = s.toLowerCase().trim();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i < 0 ? ch : to[i]);
    }
    return buf.toString();
  }
}
