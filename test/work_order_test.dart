import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/work_orders/work_order_repository.dart';
import 'package:skbs_app/features/work_orders/work_order_exporter.dart';
import 'package:skbs_app/features/work_orders/work_order_sheet.dart';

void main() {
  test('equal KTU means equal shares without multiplying output', () {
    expect(allocateWorkQuantity(100, [100, 100, 100, 100]), [25, 25, 25, 25]);
    expect(allocateWorkQuantity(90, [200, 100, 0]), [60, 30, 0]);
  });
  test('rounded shares reconcile to exactly the recorded thousandths', () {
    final shares = allocateWorkQuantity(1, [100, 100, 100]);
    expect(shares, [.334, .333, .333]);
    expect(shares.fold<int>(0, (sum, share) => sum + (share * 1000).round()), 1000);
    expect(() => allocateWorkQuantity(1, [0, 0]), throwsArgumentError);
    expect(() => allocateWorkQuantity(1, [double.nan]), throwsArgumentError);
    expect(() => allocateWorkQuantity(-1, [100]), throwsArgumentError);
  });
  test('Excel keeps chronological daily records, names and numeric shares', () {
    Map<String, dynamic> day(String date) => {
      'task_id': 'task', 'work_date': date, 'quantity': 100, 'unit': 'м³',
      'work': 'Армирование', 'axes': 'А–Б/1–3',
      'tasks': {'object_name': 'Объект 1', 'work': 'Армирование', 'axes': 'А–Б/1–3'},
      'participants': [for (var i = 1; i <= 4; i++) {'fio': 'Рабочий $i', 'ktu': 100}],
    };
    final book = Excel.decodeBytes(WorkOrderExporter.build(
        [day('2026-09-11'), day('2026-09-10')], DateTime(2026, 9, 10), DateTime(2026, 9, 11), 'Объект 1'));
    final rows = book['Наряд'].rows;
    final labels = rows.map((r) => r.isEmpty ? '' : r.first?.value.toString() ?? '').toList();
    expect(labels.indexOf('Дата: 10.09.2026'), lessThan(labels.indexOf('Дата: 11.09.2026')));
    final people = rows.where((r) => r.length > 5 && r[1]?.value.toString().startsWith('Рабочий') == true).toList();
    expect(people.length, 8);
    for (final row in people) {
      expect(row[5]!.value, DoubleCellValue(25));
    }
  });
  testWidgets('export sheet opens with calendar and a single day selected', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkOrderSheet(
        initialDate: DateTime(2026, 9, 11), objectName: 'Объект 1'))));
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Период: 11.09.2026 — 11.09.2026'), findsOneWidget);
    expect(find.text('Скачать Excel'), findsOneWidget);
  });
}
