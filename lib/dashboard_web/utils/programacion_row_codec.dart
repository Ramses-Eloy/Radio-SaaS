import 'package:radio_whitelabel/dashboard_web/firestore/emisora_fields.dart';

/// Codifica filas de programación compatibles con la app móvil (`h`, `p`, `t`, `index`).
abstract final class ProgramacionRowCodec {
  /// Una fila con las cuatro llaves obligatorias y tipos Firestore correctos.
  static Map<String, dynamic> encodeRow({
    required String horario,
    required String programa,
    required String tipo,
    required int index,
  }) {
    return {
      'h': horario,
      'p': programa,
      't': tipo,
      EmisoraFields.index: index,
    };
  }

  /// Convierte filas del formulario en lista para un día (`lunes`, `martes`, …).
  static List<Map<String, dynamic>> encodeDayRows({
    required Iterable<({String h, String p, String t})> rows,
  }) {
    final out = <Map<String, dynamic>>[];
    var index = 0;
    for (final row in rows) {
      final h = row.h.trim();
      final p = row.p.trim();
      final t = row.t.trim();
      if (h.isEmpty && p.isEmpty && t.isEmpty) continue;
      out.add(encodeRow(horario: h, programa: p, tipo: t, index: index));
      index++;
    }
    return out;
  }
}
