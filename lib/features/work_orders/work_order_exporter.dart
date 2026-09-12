import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../../data/timesheet_excel_exporter.dart';
import 'work_order_repository.dart';

class WorkOrderExporter {
  static List<int> build(List<Map<String, dynamic>> days,
      DateTime start, DateTime end, String? objectName) {
    final book = Excel.createExcel();
    book.rename('Sheet1', 'Наряд');
    final sheet = book['Наряд'];
    final date = DateFormat('dd.MM.yyyy');
    void row(List<Object> values) => sheet.appendRow(
        values.map<CellValue>((v) => v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v.toString())).toList());
    void title(String value) {
      final index = sheet.maxRows;
      row([value]);
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: index),
          CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: index));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: index))
          .cellStyle = CellStyle(bold: true, textWrapping: TextWrapping.WrapText);
    }
    title('УТВЕРЖДАЮ: Директор ______________________________');
    title('ФИРМА: __________________________________________');
    title('НАРЯД за ${date.format(start)} — ${date.format(end)}');
    title('Наименование объекта: ${objectName ?? 'Все доступные объекты'}');
    title('Объём работника — доля общего факта по КТУ. КТУ 100% — обычное участие.');
    title('Выполнение плана = фактический объём задачи / плановый объём × 100%. '
        'Показатель не изменяет КТУ автоматически.');
    final sorted = List<Map<String, dynamic>>.from(days)
      ..sort((a, b) {
        final byDate = '${a['work_date']}'.compareTo('${b['work_date']}');
        return byDate != 0 ? byDate : '${a['task_id']}'.compareTo('${b['task_id']}');
      });
    String? lastDate;
    var number = 0;
    for (final day in sorted) {
      final key = day['work_date'].toString();
      if (key != lastDate) {
        row([]);
        title('Дата: ${date.format(DateTime.parse(key))}');
        row(['№', 'Ф.И.О.', 'Виды работ', 'Оси', 'Ед. изм.',
          'Плановый объём', 'Фактический объём задачи',
          'Выполнение плана, %', 'Объём работника', 'КТУ, %', 'Объект']);
        lastDate = key;
      }
      final task = Map<String, dynamic>.from(day['tasks'] as Map);
      final rawPlan = task['task_work_plans'];
      final plan = rawPlan is Map
          ? Map<String, dynamic>.from(rawPlan)
          : rawPlan is List && rawPlan.isNotEmpty && rawPlan.first is Map
              ? Map<String, dynamic>.from(rawPlan.first as Map)
              : null;
      final people = (day['participants'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map)).toList();
      final quantity = (day['quantity'] as num).toDouble();
      final planned = (plan?['planned_quantity'] as num?)?.toDouble();
      final completion = workCompletionPercent(planned, quantity);
      final allocated = allocateWorkQuantity(quantity,
          people.map((p) => (p['ktu'] as num).toDouble()).toList());
      for (var i = 0; i < people.length; i++) {
        row([++number, '${people[i]['fio']}',
          '${day['work'] ?? task['work']}', '${day['axes'] ?? task['axes']}',
          '${day['unit']}', planned ?? '', quantity, completion ?? '',
          allocated[i], people[i]['ktu'] as num, '${task['object_name']}']);
      }
      title('Общий объём задачи «${day['work'] ?? task['work']}»: '
          '${quantity.toStringAsFixed(3).replaceAll('.', ',')} ${day['unit']}');
    }
    row([]);
    title('Подписи:');
    title('Инженер СДО __________________________');
    title('Начальник участка __________________________');
    title('Рабочие __________________________');
    const widths = [6.0, 34.0, 42.0, 18.0, 12.0, 18.0, 22.0,
      21.0, 20.0, 12.0, 25.0];
    for (var col = 0; col < widths.length; col++) {
      sheet.setColumnWidth(col, widths[col]);
    }
    for (final cells in sheet.rows) {
      for (final cell in cells) {
        if (cell != null) {
          cell.cellStyle = CellStyle(textWrapping: TextWrapping.WrapText,
              verticalAlign: VerticalAlign.Top, bold: cell.cellStyle?.isBold ?? false);
        }
      }
    }
    return book.encode()!;
  }

  static Future<void> save(List<Map<String, dynamic>> days,
      DateTime start, DateTime end, String? objectName) =>
      TimesheetExcelExporter.saveWorkbookBytes(bytes: build(days, start, end, objectName),
          fileName: 'Наряд_${WorkOrderRepository.dateKey(start)}_${WorkOrderRepository.dateKey(end)}.xlsx');
}

double? workCompletionPercent(double? planned, double actual) {
  if (planned == null || !planned.isFinite || planned <= 0 ||
      !actual.isFinite || actual < 0) {
    return null;
  }
  return (actual / planned * 1000).round() / 10;
}
