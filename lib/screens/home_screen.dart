import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/task_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';
import '../widgets/home_card.dart';

class HomeScreen extends StatelessWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  String _todayText(DateTime date) {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июля',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return 'Сегодня, ${date.day} ${months[date.month - 1]}';
  }

  String get objectTitle {
    final objectName = selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
      return 'Все объекты';
    }

    return objectName;
  }

  Future<void> showObjectPicker(
    BuildContext context,
    List<String> objects,
  ) async {
    if (!profile.isAdmin) return;

    final selectedValue = selectedObjectName ?? '__all__';

    final pickedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final items = [
          _ObjectPickerItem(
            value: '__all__',
            title: 'Все объекты',
            subtitle: 'Сводка по всем объектам',
            icon: Icons.all_inbox_outlined,
          ),
          ...objects.map(
            (objectName) => _ObjectPickerItem(
              value: objectName,
              title: objectName,
              subtitle: 'Данные только по объекту',
              icon: Icons.apartment_outlined,
            ),
          ),
        ];

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
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Выберите объект',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                ...items.map((item) {
                  final isSelected = item.value == selectedValue;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(context, item.value);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (pickedValue == null) return;

    if (pickedValue == '__all__') {
      onObjectChanged(null);
      return;
    }

    onObjectChanged(pickedValue);
  }

  Widget buildObjectSelector(BuildContext context) {
    if (!profile.isAdmin) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                objectTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<String>>(
      future: EmployeeRepository.fetchObjectNames(),
      builder: (context, snapshot) {
        final objects = snapshot.data ?? EmployeeRepository.baseObjects;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            showObjectPicker(context, objects);
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    objectTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildHeader(BuildContext context, DateTime today) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'СКБС',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _todayText(today),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        buildObjectSelector(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = AppState.today;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildHeader(context, today),

          const SizedBox(height: 22),

          StreamBuilder<List<Employee>>(
            stream: EmployeeRepository.watchEmployees(
              objectName: selectedObjectName,
            ),
            builder: (context, employeesSnapshot) {
              final employees = employeesSnapshot.data ?? [];

              return FutureBuilder<Set<String>>(
                future: AttendanceRepository.fetchWorkedEmployeeIds(
                  today,
                  objectName: selectedObjectName,
                ),
                builder: (context, attendanceSnapshot) {
                  final workedEmployeeIds = attendanceSnapshot.data ?? {};

                  if (employeesSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      attendanceSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return HomeCard(
                      title: 'Сотрудники',
                      value: '...',
                      text: 'загрузка сотрудников',
                      details: ['объект: $objectTitle'],
                      icon: Icons.groups,
                      onTap: () {},
                    );
                  }

                  if (employeesSnapshot.hasError ||
                      attendanceSnapshot.hasError) {
                    return HomeCard(
                      title: 'Сотрудники',
                      value: '!',
                      text: 'ошибка загрузки',
                      details: ['не удалось получить данные'],
                      icon: Icons.groups,
                      onTap: () {},
                    );
                  }

                  return HomeCard(
                    title: 'Сотрудники',
                    value: employees.length.toString(),
                    text: 'человек на объекте',
                    details: [
                      '${workedEmployeeIds.length} вышли на работу',
                      'объект: $objectTitle',
                    ],
                    icon: Icons.groups,
                    onTap: () {},
                  );
                },
              );
            },
          ),

          const SizedBox(height: 18),

          StreamBuilder<List<TaskItemData>>(
            stream: TaskRepository.watchTasksForDate(
              today,
              objectName: selectedObjectName,
            ),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];

              final totalTasks = tasks.length;
              final doneTasks = tasks
                  .where((task) => task.status == 'Выполнено')
                  .length;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return HomeCard(
                  title: 'Задачи',
                  value: '...',
                  text: 'загрузка задач',
                  details: ['объект: $objectTitle'],
                  icon: Icons.task_alt,
                  onTap: () {},
                );
              }

              if (snapshot.hasError) {
                return HomeCard(
                  title: 'Задачи',
                  value: '!',
                  text: 'ошибка загрузки',
                  details: ['не удалось получить задачи'],
                  icon: Icons.task_alt,
                  onTap: () {},
                );
              }

              return HomeCard(
                title: 'Задачи',
                value: totalTasks.toString(),
                text: 'задач на сегодня',
                details: ['$doneTasks выполнено', 'объект: $objectTitle'],
                icon: Icons.task_alt,
                onTap: () {},
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ObjectPickerItem {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ObjectPickerItem({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
