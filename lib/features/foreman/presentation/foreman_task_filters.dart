import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';

class ForemanTaskToolbar extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onPickDate;
  final VoidCallback? onToday;
  final VoidCallback? onAddTask;

  const ForemanTaskToolbar({
    super.key,
    required this.selectedDate,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onPickDate,
    required this.onToday,
    required this.onAddTask,
  });

  String longDate(DateTime date) {
    const months = <String>[
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    const weekdays = <String>[
      'понедельник', 'вторник', 'среда', 'четверг',
      'пятница', 'суббота', 'воскресенье',
    ];
    return '${date.day} ${months[date.month - 1]} · ${weekdays[date.weekday - 1]}';
  }

  Widget squareButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: specialistSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: specialistLine),
          ),
          child: Icon(icon, color: specialistText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: specialistLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            squareButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Предыдущий день',
              onTap: onPreviousDay,
            ),
            const SizedBox(width: 10),
            PremiumPressable(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: specialistSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: specialistLine),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: specialistMuted),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('dd.MM.yyyy').format(selectedDate),
                          style: const TextStyle(
                            color: specialistText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          longDate(selectedDate),
                          style: const TextStyle(
                            color: specialistMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            squareButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Следующий день',
              onTap: onNextDay,
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onToday,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Сегодня'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить задачу'),
            ),
          ],
        ),
      ),
    );
  }
}

class ForemanTaskFilters extends StatelessWidget {
  final TextEditingController searchController;
  final String objectName;
  final String status;
  final String? assignee;
  final List<String> statuses;
  final List<String> assignees;
  final VoidCallback onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final VoidCallback onClear;

  const ForemanTaskFilters({
    super.key,
    required this.searchController,
    required this.objectName,
    required this.status,
    required this.assignee,
    required this.statuses,
    required this.assignees,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onAssigneeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: specialistLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              decoration: InputDecoration(
                hintText: 'Поиск по работе, осям, исполнителю или комментарию...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: specialistSoft,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Объект',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                      filled: true,
                      fillColor: specialistSoft,
                    ),
                    child: Text(
                      objectName.isEmpty ? 'Объект не назначен' : objectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: status == 'Все статусы' ? null : status,
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      filled: true,
                      fillColor: specialistSoft,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Все статусы'),
                      ),
                      ...statuses.map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: assignee,
                    decoration: const InputDecoration(
                      labelText: 'Исполнитель',
                      filled: true,
                      fillColor: specialistSoft,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Все исполнители'),
                      ),
                      ...assignees.map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: onAssigneeChanged,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Сбросить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
