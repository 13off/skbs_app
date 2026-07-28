part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetSections on _PeriodTimesheetScreenState {
  Widget buildFiredToggleCard() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: includeFiredEmployees
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: includeFiredEmployees
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;

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
                    maxLines: 2,
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
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      'Уволен',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
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
        DataCell(
          SizedBox(
            width: 170,
            child: Text(
              row.employee.position,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              row.employee.objectName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(formatMoney(row.employee.dailyRate))),
        ...days.map((day) {
          final shift = row.shiftForDay(day);
          return DataCell(
            Text(
              formatShift(shift),
              style: TextStyle(
                fontWeight: shift > 0 ? FontWeight.w800 : FontWeight.w400,
                color: shift > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
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
              color: row.balance > 0 ? scheme.error : scheme.primary,
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
        child: Text(
          errorText!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
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
            columnSpacing: 24,
            columns: buildColumns(),
            rows: visibleRows.map(buildDataRow).toList(),
          ),
        ),
      ),
    );
  }
}
