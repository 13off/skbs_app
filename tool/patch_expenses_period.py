from pathlib import Path

path = Path('lib/features/expenses/presentation/expenses_screen.dart')
source = path.read_text(encoding='utf-8')

old = """  Future<void> choosePeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: 'Период расходов',
      saveText: 'Применить',
    );
    if (picked == null || !mounted) return;
    setState(() {
      from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
    await load();
  }
"""

new = """  Future<void> choosePeriod() async {
    var draftStart = DateTime(from.year, from.month, from.day);
    var draftEnd = DateTime(to.year, to.month, to.day);
    var editingStart = true;
    final firstAllowed = DateTime(2024);
    final lastAllowed = DateTime.now().add(const Duration(days: 365));

    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final activeDate = editingStart ? draftStart : draftEnd;

          return AlertDialog(
            title: const Text('Период расходов'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('С ${formatDate(draftStart)}'),
                          selected: editingStart,
                          onSelected: (_) {
                            setDialogState(() => editingStart = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('По ${formatDate(draftEnd)}'),
                          selected: !editingStart,
                          onSelected: (_) {
                            setDialogState(() => editingStart = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CalendarDatePicker(
                    key: ValueKey<String>(
                      '${editingStart ? 'start' : 'end'}-${activeDate.toIso8601String()}',
                    ),
                    initialDate: activeDate,
                    firstDate: firstAllowed,
                    lastDate: lastAllowed,
                    onDateChanged: (value) {
                      final clean = DateTime(value.year, value.month, value.day);
                      setDialogState(() {
                        if (editingStart) {
                          draftStart = clean;
                          if (draftEnd.isBefore(draftStart)) {
                            draftEnd = draftStart;
                          }
                          editingStart = false;
                        } else {
                          draftEnd = clean;
                          if (draftStart.isAfter(draftEnd)) {
                            draftStart = draftEnd;
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    DateTimeRange(start: draftStart, end: draftEnd),
                  );
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Применить'),
              ),
            ],
          );
        },
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
    await load();
  }
"""

if old not in source:
    raise SystemExit('choosePeriod snippet not found')

patched = source.replace(old, new, 1)
assert 'showDateRangePicker(' not in patched
assert 'CalendarDatePicker(' in patched
assert "label: const Text('Применить')" in patched
path.write_text(patched, encoding='utf-8')
