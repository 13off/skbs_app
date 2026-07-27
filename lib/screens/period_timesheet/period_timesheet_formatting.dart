part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetFormatting on _PeriodTimesheetScreenState {
  int get daysInMonth =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

  List<int> get days => List<int>.generate(daysInMonth, (index) => index + 1);

  bool get isAllObjects {
    final objectName = widget.selectedObjectName?.trim();
    return objectName == null || objectName.isEmpty;
  }

  String monthName(int month) {
    const monthNames = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return monthNames[month - 1];
  }

  String get monthTitle =>
      '${monthName(selectedMonth.month)} ${selectedMonth.year}';

  String get objectTitle {
    final objectName = widget.selectedObjectName?.trim();
    if (objectName == null || objectName.isEmpty) return 'Все объекты';
    return objectName;
  }

  String get fileObjectPart => objectTitle
      .replaceAll(' ', '_')
      .replaceAll('/', '_')
      .replaceAll('\\', '_');

  String formatShift(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String formatMoney(num value) {
    final formatted = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$formatted ₽';
  }

  DateTime cleanMonth(DateTime month) => DateTime(month.year, month.month, 1);

  bool isSameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;

  List<DateTime> sortMonths(Iterable<DateTime> months) {
    final result = months.map(cleanMonth).toList();
    result.sort((first, second) {
      final yearCompare = first.year.compareTo(second.year);
      if (yearCompare != 0) return yearCompare;
      return first.month.compareTo(second.month);
    });
    return result;
  }

  List<MonthlyTimesheetRow> collapseDuplicateRows(
    List<MonthlyTimesheetRow> sourceRows,
  ) {
    return PeriodTimesheetReport.collapseDuplicateRows(
      sourceRows,
      collapseAcrossObjects: isAllObjects,
    );
  }

  List<MonthlyTimesheetRow> buildFilteredRows() {
    return PeriodTimesheetReport.filterRows(
      rows,
      query: searchController.text,
    );
  }
}
