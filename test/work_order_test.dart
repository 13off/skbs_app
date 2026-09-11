import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/work_orders/work_order_exporter.dart';
import 'package:skbs_app/features/work_orders/work_order_repository.dart';
import 'package:skbs_app/features/work_orders/work_order_sheet.dart';

void main() {
  test('work plan uses the field unit set requested by construction', () {
    expect(
      WorkOrderRepository.supportedUnits,
      const <String>['м³', 'м²', 'т', 'шт.', 'м.п.'],
    );
  });

  test('new task places plan before assignees and queues it offline', () {
    final view = File(
      'lib/screens/task_create/task_create_view.dart',
    ).readAsStringSync();
    final service = File(
      'lib/data/offline_task_create_service.dart',
    ).readAsStringSync();
    final planIndex = view.indexOf('buildWorkPlanSection()');
    final assigneeIndex = view.indexOf('buildAssigneesBlock()');

    expect(planIndex, greaterThanOrEqualTo(0));
    expect(assigneeIndex, greaterThan(planIndex));
    expect(service, contains("'initial_planned_quantity': plannedQuantity"));
    expect(service, contains("'initial_work_unit': workUnit.trim()"));
  });

  test('database completion contract caps KTU at 200', () {
    final migration = File(
      'supabase/migrations/20260911143000_task_completion_volume_ktu.sql',
    ).readAsStringSync();

    expect(migration, contains('between 0 and 200'));
    expect(migration, contains('sync_initial_task_work_plan'));
  });

  test('equal KTU means equal shares without multiplying output', () {
    expect(
      allocateWorkQuantity(100, [100, 100, 100, 100]),
      [25, 25, 25, 25],
    );
    expect(allocateWorkQuantity(90, [200, 100, 0]), [60, 30, 0]);
  });

  test('rounded shares reconcile to exactly the recorded thousandths', () {
    final shares = allocateWorkQuantity(1, [100, 100, 100]);
    expect(shares, [.334, .333, .333]);
    expect(
      shares.fold<int>(0, (sum, share) => sum + (share * 1000).round()),
      1000,
    );
    expect(() => allocateWorkQuantity(1, [0, 0]), throwsArgumentError);
    expect(() => allocateWorkQuantity(1, [double.nan]), throwsArgumentError);
    expect(() => allocateWorkQuantity(-1, [100]), throwsArgumentError);
  });

  test('Excel keeps chronological daily records, names and numeric shares', () {
    Map<String, dynamic> day(String date) => {
      'task_id': 'task',
      'work_date': date,
      'quantity': 100,
      'unit': 'м³',
      'work': 'Армирование',
      'axes': 'А–Б/1–3',
      'tasks': {
        'object_name': 'Объект 1',
        'work': 'Армирование',
        'axes': 'А–Б/1–3',
      },
      'participants': [
        for (var i = 1; i <= 4; i++) {'fio': 'Рабочий $i', 'ktu': 100},
      ],
    };
    final book = Excel.decodeBytes(
      WorkOrderExporter.build(
        [day('2026-09-11'), day('2026-09-10')],
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 11),
        'Объект 1',
      ),
    );
    final rows = book['Наряд'].rows;
    final labels = rows
        .map((r) => r.isEmpty ? '' : r.first?.value.toString() ?? '')
        .toList();
    expect(
      labels.indexOf('Дата: 10.09.2026'),
      lessThan(labels.indexOf('Дата: 11.09.2026')),
    );
    final people = rows
        .where(
          (r) =>
              r.length > 5 &&
              r[1]?.value.toString().startsWith('Рабочий') == true,
        )
        .toList();
    expect(people.length, 8);
    for (final row in people) {
      expect(row[5]!.value, anyOf(IntCellValue(25), DoubleCellValue(25)));
    }
  });

  testWidgets('export sheet opens with calendar and a single day selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkOrderSheet(
            initialDate: DateTime(2026, 9, 11),
            objectName: 'Объект 1',
          ),
        ),
      ),
    );
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Период: 11.09.2026 — 11.09.2026'), findsOneWidget);
    expect(find.text('Скачать Excel'), findsOneWidget);
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 9));
    await tester.pump();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 12));
    await tester.pump();
    expect(find.text('Период: 09.09.2026 — 12.09.2026'), findsOneWidget);
  });
}
