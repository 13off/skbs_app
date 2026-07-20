part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetSections on _PeriodTimesheetScreenState {
  Widget buildFiredToggleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: includeFiredEmployees
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: includeFiredEmployees
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: includeFiredEmployees,
            onChanged: isLoading || isExporting
                ? null
                : (value) => toggleIncludeFired(value ?? false),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Учитывать уволенных',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryCard(List<MonthlyTimesheetRow> visibleRows) {
    final summary = PeriodTimesheetReport.summarize(visibleRows);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Итог по месяцу',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text('Месяц: $monthTitle'),
          Text('Объект: $objectTitle'),
          Text('Сотрудников: ${summary.employeeCount}'),
          Text('Активных: ${summary.activeEmployeeCount}'),
          if (includeFiredEmployees)
            Text('Уволенных: ${summary.firedEmployeeCount}'),
          Text('Начислено: ${formatMoney(summary.accrued)}'),
          Text('Выплачено: ${formatMoney(summary.paid)}'),
          Text('Остаток: ${formatMoney(summary.balance)}'),
        ],
      ),
    );
  }

  List<DataColumn> buildColumns() {
    return <DataColumn>[
      const DataColumn(label: Text('ФИО')),
      const DataColumn(label: Text('Должность')),
      const DataColumn(label: Text('Объект')),
      const DataColumn(label: Text('Ставка'), numeric: true),
      ...days.map(
        (day) => DataColumn(label: Text(day.toString()), numeric: true),
      ),
      const DataColumn(label: Text('Итого'), numeric: true),
      const DataColumn(label: Text('Начислено'), numeric: true),
      const DataColumn(label: Text('Выплачено'), numeric: true),
      const DataColumn(label: Text('Остаток'), numeric: true),
    ];
  }

  DataRow buildDataRow(MonthlyTimesheetRow row) {
    return DataRow(
      cells: <DataCell>[
        DataCell(
          SizedBox(
            width: 250,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.employee.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                if (!row.employee.isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Уволен',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  onPressed: isLoading || isExporting
                      ? null
                      : () => downloadEmployeeExcel(row),
                  icon: const Icon(Icons.download, size: 20),
                  tooltip: 'Скачать индивидуальный табель',
                ),
              ],
            ),
          ),
        ),
        DataCell(SizedBox(width: 130, child: Text(row.employee.position))),
        DataCell(SizedBox(width: 140, child: Text(row.employee.objectName))),
        DataCell(Text(formatMoney(row.employee.dailyRate))),
        ...days.map((day) {
          final shift = row.shiftForDay(day);
          return DataCell(
            Text(
              formatShift(shift),
              style: TextStyle(
                fontWeight: shift > 0 ? FontWeight.w800 : FontWeight.w400,
                color: shift > 0 ? Colors.black : Colors.grey,
              ),
            ),
          );
        }),
        DataCell(
          Text(
            formatShift(row.totalShifts),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            formatMoney(row.accrued),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            formatMoney(row.paid),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            formatMoney(row.balance),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: row.balance > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTable(List<MonthlyTimesheetRow> visibleRows) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorText != null) {
      return Center(
        child: Text(errorText!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (visibleRows.isEmpty) {
      return const Center(
        child: Text('Нет сотрудников со сменами за этот месяц'),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: buildColumns(),
            rows: visibleRows.map(buildDataRow).toList(),
          ),
        ),
      ),
    );
  }
}
