import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/task_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';

const Color _bg = Color(0xFFF7F8FA);
const Color _card = Color(0xFFFFFFFF);
const Color _softCard = Color(0xFFF2F3F5);
const Color _line = Color(0xFFE6E8EB);
const Color _text = Color(0xFF1F2328);
const Color _muted = Color(0xFF6B7075);
const Color _accent = Color(0xFF8F9499);
const Color _success = Color(0xFF22C55E);
const Color _warning = Color(0xFF8F9499);

class HomeScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_HomeDashboardData>? dashboardFuture;
  Future<List<String>>? objectNamesFuture;

  @override
  void initState() {
    super.initState();
    dashboardFuture = loadDashboardData();
    objectNamesFuture = EmployeeRepository.fetchObjectNames();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      dashboardFuture = loadDashboardData();
    }
  }

  Future<_HomeDashboardData> loadDashboardData() async {
    final today = AppState.today;

    final results = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(objectName: widget.selectedObjectName),
      AttendanceRepository.fetchWorkedEmployeeIds(
        today,
        objectName: widget.selectedObjectName,
      ),
      TaskRepository.fetchTasksForDate(
        today,
        objectName: widget.selectedObjectName,
      ),
    ]);

    return _HomeDashboardData(
      employees: results[0] as List<Employee>,
      workedEmployeeIds: results[1] as Set<String>,
      tasks: results[2] as List<TaskItemData>,
    );
  }

  String dateText(DateTime date) {
    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  String get objectTitle {
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
      return 'Все объекты';
    }

    return objectName;
  }

  Future<void> showObjectPicker(
    BuildContext context,
    List<String> objects,
  ) async {
    if (!widget.profile.isAdmin) return;

    final selectedValue = widget.selectedObjectName ?? '__all__';

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
            icon: Icons.apartment_outlined,
          ),
          ...objects.map(
            (objectName) => _ObjectPickerItem(
              value: objectName,
              title: objectName,
              subtitle: 'Данные только по этому объекту',
              icon: Icons.business_outlined,
            ),
          ),
        ];

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4CCC2),
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
                          color: _text,
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
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(context, item.value);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? _softCard : _card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _accent : _line,
                          ),
                        ),
                        child: Row(
                          children: [
                            _IconBox(
                              icon: item.icon,
                              color: isSelected ? _accent : _text,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: _accent),
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
      widget.onObjectChanged(null);
      return;
    }

    widget.onObjectChanged(pickedValue);
  }

  Widget buildObjectSelector(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return _ObjectSelectorShell(
        icon: Icons.lock_outline,
        title: objectTitle,
        onTap: null,
      );
    }

    return FutureBuilder<List<String>>(
      future: objectNamesFuture,
      builder: (context, snapshot) {
        final objects = snapshot.data ?? EmployeeRepository.baseObjects;

        return _ObjectSelectorShell(
          icon: Icons.apartment_outlined,
          title: objectTitle,
          onTap: () {
            showObjectPicker(context, objects);
          },
        );
      },
    );
  }

  Widget buildHeader(BuildContext context, DateTime today) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'AppСтрой',
                style: TextStyle(
                  color: _text,
                  fontFamily: 'Georgia',
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_none_outlined,
                      color: _text,
                      size: 25,
                    ),
                  ),
                  Positioned(
                    right: 13,
                    top: 12,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: _muted, size: 22),
            const SizedBox(width: 12),
            Text(
              'Сегодня, ${dateText(today)}',
              style: const TextStyle(
                color: _muted,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        buildObjectSelector(context),
      ],
    );
  }

  Widget buildDashboard({
    required BuildContext context,
    required DateTime today,
    required List<Employee> employees,
    required Set<String> workedEmployeeIds,
    required List<TaskItemData> tasks,
    required bool isLoading,
    required bool hasError,
  }) {
    final totalEmployees = employees.length;
    final workedEmployees = workedEmployeeIds.length;

    final totalTasks = tasks.length;
    final doneTasks = tasks.where((task) => task.status == 'Выполнено').length;

    final employeesProgress = totalEmployees == 0
        ? 0.0
        : workedEmployees / totalEmployees;

    final tasksProgress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

    final employeesValue = isLoading ? '...' : workedEmployees.toString();
    final employeesPlan = isLoading ? '...' : totalEmployees.toString();

    final tasksValue = isLoading ? '...' : totalTasks.toString();
    final tasksDone = isLoading ? '...' : doneTasks.toString();

    return Container(
      color: _bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeader(context, today),
                    if (hasError) ...[
                      const SizedBox(height: 14),
                      const _SystemMessage(
                        icon: Icons.error_outline,
                        title: 'Есть ошибка загрузки',
                        text:
                            'Часть данных не подтянулась. Обнови страницу или проверь интернет.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    _DashboardMetricCard(
                      icon: Icons.person_outline,
                      title: 'Сотрудники на объекте',
                      value: employeesValue,
                      secondaryValue: 'из $employeesPlan',
                      progress: employeesProgress,
                      bottomDotColor: _success,
                      bottomLabel: 'На объекте',
                      bottomValue: employeesValue,
                    ),
                    const SizedBox(height: 14),
                    _DashboardMetricCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Задачи на сегодня',
                      value: tasksValue,
                      secondaryValue: 'всего',
                      progress: tasksProgress,
                      showRing: true,
                      ringLabel: '${(tasksProgress * 100).round()}%',
                      bottomDotColor: _accent,
                      bottomLabel: 'Выполнено',
                      bottomValue: tasksDone,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = AppState.today;

    return FutureBuilder<_HomeDashboardData>(
      future: dashboardFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _HomeDashboardData.empty;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return buildDashboard(
          context: context,
          today: today,
          employees: data.employees,
          workedEmployeeIds: data.workedEmployeeIds,
          tasks: data.tasks,
          isLoading: isLoading,
          hasError: snapshot.hasError,
        );
      },
    );
  }
}

class _HomeDashboardData {
  final List<Employee> employees;
  final Set<String> workedEmployeeIds;
  final List<TaskItemData> tasks;

  const _HomeDashboardData({
    required this.employees,
    required this.workedEmployeeIds,
    required this.tasks,
  });

  static const empty = _HomeDashboardData(
    employees: <Employee>[],
    workedEmployeeIds: <String>{},
    tasks: <TaskItemData>[],
  );
}

class _ObjectSelectorShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ObjectSelectorShell({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            _IconBox(icon: icon, color: _text),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.keyboard_arrow_down, color: _text),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String secondaryValue;
  final double progress;
  final bool showRing;
  final String? ringLabel;
  final Color bottomDotColor;
  final String bottomLabel;
  final String bottomValue;

  const _DashboardMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.secondaryValue,
    required this.progress,
    this.showRing = false,
    this.ringLabel,
    required this.bottomDotColor,
    required this.bottomLabel,
    required this.bottomValue,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.040),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: icon, color: _accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                if (showRing)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _ValueBlock(
                          value: value,
                          secondaryValue: secondaryValue,
                        ),
                      ),
                      _RingProgress(
                        progress: safeProgress,
                        label: ringLabel ?? '${(safeProgress * 100).round()}%',
                        size: 74,
                        stroke: 6,
                      ),
                    ],
                  )
                else
                  _ValueBlock(value: value, secondaryValue: secondaryValue),
                const SizedBox(height: 16),
                if (!showRing)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: safeProgress,
                      backgroundColor: const Color(0xFFE8E2DB),
                      valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _softCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: bottomDotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          bottomLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        bottomValue,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: _muted, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  final String value;
  final String secondaryValue;

  const _ValueBlock({required this.value, required this.secondaryValue});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 46,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            secondaryValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RingProgress extends StatelessWidget {
  final double progress;
  final String label;
  final double size;
  final double stroke;

  const _RingProgress({
    required this.progress,
    required this.label,
    required this.size,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: safeProgress,
              strokeWidth: stroke,
              backgroundColor: const Color(0xFFE8E2DB),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 27),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _SystemMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
