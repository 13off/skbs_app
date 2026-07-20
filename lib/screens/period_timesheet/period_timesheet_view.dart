part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetView on _PeriodTimesheetScreenState {
  Widget buildPeriodTimesheetView() {
    final visibleRows = buildFilteredRows();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: <Widget>[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Табель',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Месячный табель сотрудников'),
                    Text(
                      'Объект: $objectTitle',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: isLoading || isExporting
                    ? null
                    : openAddPaymentScreen,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Выплата'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isLoading || isExporting
                    ? null
                    : downloadAllEmployeesExcel,
                icon: isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Все'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isLoading || isExporting ? null : pickMonth,
              icon: const Icon(Icons.calendar_month),
              label: Text('Месяц: $monthTitle'),
            ),
          ),
          const SizedBox(height: 10),
          buildFiredToggleCard(),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            enabled: !isExporting,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Поиск сотрудника',
              hintText: 'ФИО, должность или объект',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          buildSummaryCard(visibleRows),
          const SizedBox(height: 14),
          SizedBox(height: 460, child: buildTable(visibleRows)),
        ],
      ),
    );
  }
}
