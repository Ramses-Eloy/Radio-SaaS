import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:radio_whitelabel/dashboard_web/utils/programacion_import.dart';

/// Pega texto copiado de Excel/Sheets o sube un CSV; devuelve las filas y si reemplazan o se añaden.
/// No escribe en Firestore: el resultado se vuelca en el editor y se guarda con "Guardar Cambios".
class ProgramacionImportDialog extends StatefulWidget {
  const ProgramacionImportDialog({super.key, required this.defaultDay, required this.dayLabels});

  final String defaultDay;
  final Map<String, String> dayLabels;

  static Future<({ProgramacionImportResult result, bool replace})?> show(
    BuildContext context, {
    required String defaultDay,
    required Map<String, String> dayLabels,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ProgramacionImportDialog(defaultDay: defaultDay, dayLabels: dayLabels),
    );
  }

  @override
  State<ProgramacionImportDialog> createState() => _ProgramacionImportDialogState();
}

class _ProgramacionImportDialogState extends State<ProgramacionImportDialog> {
  final _textCtrl = TextEditingController();
  bool _replace = true;
  late ProgramacionImportResult _result = _parse();

  ProgramacionImportResult _parse() => ProgramacionImport.parse(_textCtrl.text, defaultDay: widget.defaultDay);

  Future<void> _pickCsv() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'tsv', 'txt'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    setState(() {
      _textCtrl.text = utf8.decode(bytes, allowMalformed: true);
      _result = _parse();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final defaultLabel = widget.dayLabels[widget.defaultDay] ?? widget.defaultDay;

    return AlertDialog(
      title: const Text('Importar programación'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Copia las celdas en Excel o Google Sheets y pégalas aquí, o sube un CSV. '
                'Columnas: Día, Hora inicio, Hora fin, Programa, Categoría / DJ. '
                'El día acepta rangos ("Lunes a Viernes", "Sábado y Domingo"). '
                'También sirve texto como "LUNES A VIERNES" en una línea y debajo "6:00 - 9:00 Programa - DJ". '
                'Las filas sin día van a $defaultLabel.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textCtrl,
                minLines: 6,
                maxLines: 12,
                style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Lunes a Viernes\t6:00 AM\t9:00 AM\tDespierta con Boom\tDJ Ana',
                ),
                onChanged: (_) => setState(() => _result = _parse()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickCsv,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Subir CSV'),
                ),
              ),
              if (_result.total > 0 || _result.ignored.isNotEmpty) ...[const Divider(), _buildPreview(context)],
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Reemplazar esos días')),
                  ButtonSegment(value: false, label: Text('Añadir al final')),
                ],
                selected: {_replace},
                onSelectionChanged: (s) => setState(() => _replace = s.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _result.total == 0 ? null : () => Navigator.of(context).pop((result: _result, replace: _replace)),
          child: Text(_result.total == 0 ? 'Importar' : 'Importar ${_result.total} bloques'),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rows = <TableRow>[];
    for (final day in ProgramacionImport.dayKeys) {
      for (final row in _result.byDay[day] ?? const <ProgramacionImportRow>[]) {
        rows.add(TableRow(children: [_cell(widget.dayLabels[day] ?? day), _cell(row.h), _cell(row.p), _cell(row.t)]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vista previa', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        if (rows.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(3),
                  3: FlexColumnWidth(2),
                },
                border: TableBorder.symmetric(inside: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
                children: rows,
              ),
            ),
          ),
        if (_result.ignored.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_result.ignored.length} línea(s) ignorada(s): ${_result.ignored.take(3).join(' · ')}'
            '${_result.ignored.length > 3 ? ' …' : ''}',
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _cell(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
