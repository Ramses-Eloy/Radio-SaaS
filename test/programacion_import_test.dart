import 'package:flutter_test/flutter_test.dart';
import 'package:radio_whitelabel/dashboard_web/utils/programacion_import.dart';

void main() {
  group('parseTime', () {
    test('formatos comunes', () {
      expect(ProgramacionImport.parseTime('6:00'), '06:00');
      expect(ProgramacionImport.parseTime('06:00 AM'), '06:00');
      expect(ProgramacionImport.parseTime('12:00 AM'), '00:00');
      expect(ProgramacionImport.parseTime('12:30 pm'), '12:30');
      expect(ProgramacionImport.parseTime('6 pm'), '18:00');
      expect(ProgramacionImport.parseTime('6:00:00 p. m.'), '18:00');
      expect(ProgramacionImport.parseTime('18h'), '18:00');
      expect(ProgramacionImport.parseTime('6.30'), '06:30');
      expect(ProgramacionImport.parseTime('24:00'), '00:00');
      expect(ProgramacionImport.parseTime('Hora'), isNull);
      expect(ProgramacionImport.parseTime('25:00'), isNull);
    });
  });

  group('parseDays', () {
    test('días y rangos', () {
      expect(ProgramacionImport.parseDays('Miércoles'), ['miercoles']);
      expect(ProgramacionImport.parseDays('LUNES A VIERNES'), ['lunes', 'martes', 'miercoles', 'jueves', 'viernes']);
      expect(ProgramacionImport.parseDays('Lun-Mie'), ['lunes', 'martes', 'miercoles']);
      expect(ProgramacionImport.parseDays('Sábado y Domingo'), ['sabado', 'domingo']);
      expect(ProgramacionImport.parseDays('Fin de semana'), ['sabado', 'domingo']);
      expect(ProgramacionImport.parseDays('Diario').length, 7);
      expect(ProgramacionImport.parseDays('Día'), isEmpty);
      expect(ProgramacionImport.parseDays('Programa'), isEmpty);
    });
  });

  group('parse', () {
    test('pegado desde Excel (tabs) con encabezado', () {
      const text =
          'Día\tHora inicio\tHora fin\tPrograma\tCategoría / DJ\n'
          'Lunes a Viernes\t6:00 AM\t9:00 AM\tDespierta con Boom\tDJ Ana\n'
          'Sábado\t10:00\t12:00\tTop 40\t\n';
      final r = ProgramacionImport.parse(text, defaultDay: 'lunes');
      expect(r.byDay['lunes'], [(h: '06:00 - 09:00', p: 'Despierta con Boom', t: 'DJ Ana')]);
      expect(r.byDay['viernes']!.length, 1);
      expect(r.byDay['sabado'], [(h: '10:00 - 12:00', p: 'Top 40', t: '')]);
      expect(r.ignored.length, 1);
      expect(r.total, 6);
    });

    test('CSV con horario en una sola columna y comillas', () {
      const text =
          'Martes,6:00 - 7:00,"Noticias, edición matinal",Redacción\n'
          'Martes,07:00 AM A 08:00 AM,Música,\n';
      final r = ProgramacionImport.parse(text, defaultDay: 'lunes');
      expect(r.byDay['martes'], [
        (h: '06:00 - 07:00', p: 'Noticias, edición matinal', t: 'Redacción'),
        (h: '07:00 - 08:00', p: 'Música', t: ''),
      ]);
    });

    test('texto libre con encabezados de día', () {
      const text =
          'LUNES A VIERNES\n'
          '6:00 - 9:00 Hoy en la mañana - DJ Beto\n'
          '9:00 a 12:00 Música continua\n'
          'Domingo de 8 am a 10 am: Misa\n'
          'SÁBADO\n'
          '10:00-12:00 Top 40 | Carlos\n';
      final r = ProgramacionImport.parse(text, defaultDay: 'lunes');
      expect(r.byDay['jueves'], [
        (h: '06:00 - 09:00', p: 'Hoy en la mañana', t: 'DJ Beto'),
        (h: '09:00 - 12:00', p: 'Música continua', t: ''),
      ]);
      expect(r.byDay['domingo'], [(h: '08:00 - 10:00', p: 'Misa', t: '')]);
      expect(r.byDay['sabado'], [(h: '10:00 - 12:00', p: 'Top 40', t: 'Carlos')]);
      expect(r.ignored, isEmpty);
    });

    test('sin columna de día usa el día por defecto', () {
      const text = '6:00\t7:00\tNoticias\n7:00\t8:00\tMúsica';
      final r = ProgramacionImport.parse(text, defaultDay: 'miercoles');
      expect(r.byDay.keys, ['miercoles']);
      expect(r.total, 2);
    });
  });
}
