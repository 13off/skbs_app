part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetPeriodPicker on _PeriodTimesheetScreenState {
  Future<void> pickMonth() async {
    var tempYear = selectedMonth.year;
    final pickedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _periodSheetHandle(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Выберите месяц',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildYearSelector(
                      context: context,
                      year: tempYear,
                      onPrevious: () => setModalState(() => tempYear--),
                      onNext: () => setModalState(() => tempYear++),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.4,
                          ),
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isSelected =
                            selectedMonth.year == tempYear &&
                            selectedMonth.month == month;
                        return _buildMonthTile(
                          context: context,
                          month: month,
                          isSelected: isSelected,
                          onTap: () => Navigator.pop(
                            sheetContext,
                            DateTime(tempYear, month, 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final now = DateTime.now();
                          Navigator.pop(
                            sheetContext,
                            DateTime(now.year, now.month, 1),
                          );
                        },
                        icon: const Icon(Icons.today),
                        label: const Text('Текущий месяц'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedMonth == null) return;
    final cleanPickedMonth = cleanMonth(pickedMonth);
    if (isSameMonth(cleanPickedMonth, selectedMonth)) return;

    setState(() {
      selectedMonth = cleanPickedMonth;
      rows = <MonthlyTimesheetRow>[];
    });
    await loadReport();
  }

  Future<List<DateTime>?> pickMonthsForDownload({
    required String title,
    String? subtitle,
  }) async {
    var tempYear = selectedMonth.year;
    final selectedMonths = <DateTime>{cleanMonth(selectedMonth)};

    return showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final picked = sortMonths(selectedMonths);
            return SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _periodSheetHandle()),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildYearSelector(
                        context: context,
                        year: tempYear,
                        onPrevious: () => setModalState(() => tempYear--),
                        onNext: () => setModalState(() => tempYear++),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 12,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.4,
                            ),
                        itemBuilder: (context, index) {
                          final month = index + 1;
                          final monthDate = DateTime(tempYear, month, 1);
                          final isSelected = selectedMonths.any(
                            (item) => isSameMonth(item, monthDate),
                          );
                          return _buildMonthTile(
                            context: context,
                            month: month,
                            isSelected: isSelected,
                            showCheck: true,
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedMonths.removeWhere(
                                    (item) => isSameMonth(item, monthDate),
                                  );
                                } else {
                                  selectedMonths.add(monthDate);
                                }
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        picked.isEmpty
                            ? 'Месяцы не выбраны'
                            : 'Выбрано: ${picked.map((item) => '${monthName(item.month)} ${item.year}').join(', ')}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: picked.isEmpty
                              ? null
                              : () => Navigator.pop(sheetContext, picked),
                          icon: const Icon(Icons.download),
                          label: const Text('Скачать Excel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _periodSheetHandle() {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget _buildYearSelector({
    required BuildContext context,
    required int year,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                year.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTile({
    required BuildContext context,
    required int month,
    required bool isSelected,
    required VoidCallback onTap,
    bool showCheck = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showCheck && isSelected) ...[
              Icon(
                Icons.check_circle,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                monthName(month),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
