import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/work_orders/work_order_repository.dart';
import 'package:skbs_app/features/work_orders/work_order_exporter.dart';
import 'package:skbs_app/features/work_orders/work_order_fields.dart';
import 'package:skbs_app/features/work_orders/work_order_sheet.dart';
import 'package:skbs_app/data/task_contribution_repository.dart';
import 'package:skbs_app/features/tasks/presentation/task_contribution_dialog.dart';

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
  test('completion percent compares the task fact with its plan', () {
    expect(workCompletionPercent(20, 10), 50);
    expect(workCompletionPercent(10, 20), 200);
    expect(workCompletionPercent(30, 10), 33.3);
    expect(workCompletionPercent(0, 10), isNull);
    expect(workCompletionPercent(null, 10), isNull);
  });
  test('task UI keeps photos above actions and makes order button full width', () {
    final details = File(
      'lib/screens/task_details/task_details_view.dart',
    ).readAsStringSync();
    final mobileTasks = File(
      'lib/screens/mobile_tasks_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/work_orders/work_order_repository.dart',
    ).readAsStringSync();

    expect(
      details.indexOf("photoStage: 'before'"),
      lessThan(details.indexOf('buildActionButtons()')),
    );
    expect(
      details.indexOf("photoStage: 'after'"),
      lessThan(details.indexOf('buildActionButtons()')),
    );
    expect(
      details.indexOf('TaskWorkSection('),
      lessThan(details.indexOf('buildAssigneesBlock()')),
    );
    final orderButton = mobileTasks.indexOf("label: const Text('Скачать наряд')");
    final fullWidth = mobileTasks.lastIndexOf('width: double.infinity', orderButton);
    final matchingHeight = mobileTasks.lastIndexOf('height: 54', orderButton);
    expect(orderButton, greaterThan(0));
    expect(fullWidth, greaterThan(orderButton - 700));
    expect(matchingHeight, greaterThan(orderButton - 700));
    expect(
      repository,
      contains('task_work_plans(planned_quantity, unit, without_volume)'),
    );
  });
  test('foreman desktop exposes act and work-order actions', () {
    final desktop = File(
      'lib/features/foreman/presentation/foreman_desktop_tasks_screen.dart',
    ).readAsStringSync();

    expect(desktop, contains("label: const Text('Сформировать акт')"));
    expect(desktop, contains("label: const Text('Скачать наряд')"));
    expect(desktop, contains('ActPreviewScreen(tasks: tasks'));
    expect(desktop, contains('showWorkOrderSheet('));
    expect(desktop, contains('constraints: const BoxConstraints(maxWidth: 760)'));
  });
  test('Excel keeps chronological records, plan, fact and numeric shares', () {
    Map<String, dynamic> day(String date) => {
      'task_id': 'task', 'work_date': date, 'quantity': 100, 'unit': 'м³',
      'work': 'Армирование', 'axes': 'А–Б/1–3',
      'tasks': {'object_name': 'Объект 1', 'work': 'Армирование',
        'axes': 'А–Б/1–3',
        'task_work_plans': {
          'planned_quantity': 200,
          'unit': 'м³',
          'without_volume': false,
        }},
      'participants': [for (var i = 1; i <= 4; i++) {'fio': 'Рабочий $i', 'ktu': 100}],
    };
    final book = Excel.decodeBytes(WorkOrderExporter.build(
        [day('2026-09-11'), day('2026-09-10')], DateTime(2026, 9, 10), DateTime(2026, 9, 11), 'Объект 1'));
    final rows = book['Наряд'].rows;
    final labels = rows.map((r) => r.isEmpty ? '' : r.first?.value.toString() ?? '').toList();
    expect(labels.indexOf('Дата: 10.09.2026'), lessThan(labels.indexOf('Дата: 11.09.2026')));
    final people = rows.where((r) => r.length > 10 &&
        r[1]?.value.toString().startsWith('Рабочий') == true).toList();
    expect(people.length, 8);
    for (final row in people) {
      expect(row[5]!.value, anyOf(IntCellValue(200), DoubleCellValue(200)));
      expect(row[6]!.value, anyOf(IntCellValue(100), DoubleCellValue(100)));
      expect(row[7]!.value, anyOf(IntCellValue(50), DoubleCellValue(50)));
      expect(row[8]!.value, anyOf(IntCellValue(25), DoubleCellValue(25)));
    }
  });
  test('Excel keeps task, worker and KTU but omits volumes when requested', () {
    final book = Excel.decodeBytes(WorkOrderExporter.build([
      {
        'task_id': 'task-no-volume',
        'work_date': '2026-09-12',
        'quantity': null,
        'unit': '',
        'work': 'Уборка участка',
        'axes': 'А–Б/1–3',
        'tasks': {
          'object_name': 'Объект 1',
          'work': 'Уборка участка',
          'axes': 'А–Б/1–3',
          'task_work_plans': {
            'planned_quantity': null,
            'unit': '',
            'without_volume': true,
          },
        },
        'participants': [
          {'fio': 'Иванов Иван Иванович', 'ktu': 120},
        ],
      },
    ], DateTime(2026, 9, 12), DateTime(2026, 9, 12), 'Объект 1'));
    final worker = book['Наряд'].rows.singleWhere(
      (row) => row.length > 10 &&
          row[1]?.value.toString() == 'Иванов Иван Иванович',
    );
    expect(worker[2]!.value.toString(), 'Уборка участка');
    expect(worker[3]!.value.toString(), 'А–Б/1–3');
    for (final column in [4, 5, 6, 7, 8]) {
      expect(worker[column]!.value.toString(), '');
    }
    expect(worker[9]!.value, anyOf(IntCellValue(120), DoubleCellValue(120)));
  });
  testWidgets('export sheet opens with calendar and a single day selected', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkOrderSheet(
        initialDate: DateTime(2026, 9, 11), objectName: 'Объект 1'))));
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Период: 11.09.2026 — 11.09.2026'), findsOneWidget);
    expect(find.text('Скачать Excel'), findsOneWidget);
    tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 9));
    await tester.pump();
    tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 12));
    await tester.pump();
    expect(find.text('Период: 09.09.2026 — 12.09.2026'), findsOneWidget);
  });

  testWidgets('mobile task form visibly exposes the no-volume checkbox', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var withoutVolume = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setState) => WorkOrderPlanFields(
                quantityController: controller,
                unit: 'м³',
                withoutVolume: withoutVolume,
                onUnitChanged: (_) {},
                onWithoutVolumeChanged: (value) {
                  setState(() => withoutVolume = value ?? false);
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Без объёма'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.text('Без объёма'));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('completion uses independent 0..200 KTU sliders', (tester) async {
    TaskCompletionWorkResult? result;
    const entries = [
      TaskContributionEntry(
        employeeId: 'one',
        employeeName: 'Первый',
        position: 'Бетонщик',
        percent: 50,
      ),
      TaskContributionEntry(
        employeeId: 'two',
        employeeName: 'Второй',
        position: 'Арматурщик',
        percent: 50,
      ),
    ];
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          result = await showTaskContributionDialog(
            context: context,
            entries: entries,
            unit: 'м³',
            plannedQuantity: 120,
          );
        },
        child: const Text('Открыть'),
      );
    })));
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders, hasLength(2));
    expect(sliders[0].value, 100);
    expect(sliders[1].value, 100);
    expect(sliders[0].max, 200);

    await tester.drag(find.byType(Slider).first, const Offset(1000, 0));
    await tester.pump();
    final changed = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(changed[0].value, 200);
    expect(changed[1].value, 100);

    await tester.enterText(
      find.widgetWithText(TextField, 'Фактически выполненный объём'),
      '90',
    );
    await tester.tap(find.text('Завершить задачу'));
    await tester.pumpAndSettle();
    expect(result?.actualQuantity, 90);
    expect(result?.entries.map((entry) => entry.percent), [200, 100]);
    expect(
      result?.normalizedContributions.map((entry) => entry.percent),
      [67, 33],
    );
  });

  testWidgets('task without volume completes with KTU and no quantity field', (
    tester,
  ) async {
    TaskCompletionWorkResult? result;
    const entries = [
      TaskContributionEntry(
        employeeId: 'one',
        employeeName: 'Первый',
        position: 'Рабочий',
        percent: 100,
      ),
    ];
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () async {
          result = await showTaskContributionDialog(
            context: context,
            entries: entries,
            unit: '',
            withoutVolume: true,
          );
        },
        child: const Text('Открыть без объёма'),
      );
    })));
    await tester.tap(find.text('Открыть без объёма'));
    await tester.pumpAndSettle();
    expect(find.text('Фактически выполненный объём'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('Завершить задачу'));
    await tester.pumpAndSettle();
    expect(result?.actualQuantity, isNull);
    expect(result?.entries.single.percent, 100);
  });
}
