import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/finance_summary_repository.dart';
import '../data/object_repository.dart';
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
  FinancePeriod financePeriod = FinancePeriod.current(AppState.today);

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
    final period = financePeriod;

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
      FinanceSummaryRepository.fetchSummary(
        period: period,
        objectName: widget.selectedObjectName,
      ),
    ]);

    return _HomeDashboardData(
      employees: results[0] as List<Employee>,
      workedEmployeeIds: results[1] as Set<String>,
      tasks: results[2] as List<TaskItemData>,
      finance: results[3] as FinanceSummaryData,
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

  bool isSameFinancePeriod(FinancePeriod a, FinancePeriod b) {
    return a.year == b.year && a.month == b.month;
  }

  Future<String?> showAddObjectSheet(BuildContext context) async {
    if (!widget.profile.isAdmin) return null;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final commentController = TextEditingController();

    var isSaving = false;
    String? errorText;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveObject() async {
              final isValid = formKey.currentState?.validate() ?? false;

              if (!isValid || isSaving) return;

              setModalState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                final createdName = await ObjectRepository.addObject(
                  name: nameController.text,
                  address: addressController.text,
                  comment: commentController.text,
                );

                if (!context.mounted) return;

                Navigator.pop(context, createdName);
              } catch (error) {
                if (!context.mounted) return;

                setModalState(() {
                  isSaving = false;
                  errorText = error.toString();
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
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
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4CCC2),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Новый объект',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                      },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: nameController,
                            enabled: !isSaving,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Название объекта',
                              hintText: 'Например: Талнах',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';

                              if (text.isEmpty) {
                                return 'Введите название объекта';
                              }

                              if (text.length < 2) {
                                return 'Название слишком короткое';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: addressController,
                            enabled: !isSaving,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Город / адрес',
                              hintText: 'Необязательно',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: commentController,
                            enabled: !isSaving,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Комментарий',
                              hintText: 'Необязательно',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              errorText!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: isSaving ? null : saveObject,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_business_outlined),
                              label: Text(
                                isSaving ? 'Сохраняем...' : 'Сохранить объект',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    addressController.dispose();
    commentController.dispose();

    return result;
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
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
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.pop(context, '__add_object__');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _softCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accent),
                    ),
                    child: const Row(
                      children: [
                        _IconBox(
                          icon: Icons.add_business_outlined,
                          color: _accent,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+ Добавить объект',
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Создать новый объект в базе',
                                style: TextStyle(
                                  color: _muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: _text),
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                  const Icon(
                                    Icons.check_circle,
                                    color: _accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedValue == null) return;

    if (pickedValue == '__add_object__') {
      final createdObjectName = await showAddObjectSheet(context);

      if (createdObjectName == null || createdObjectName.trim().isEmpty) {
        return;
      }

      setState(() {
        objectNamesFuture = EmployeeRepository.fetchObjectNames(
          forceRefresh: true,
        );
      });

      widget.onObjectChanged(createdObjectName);
      return;
    }

    if (pickedValue == '__all__') {
      widget.onObjectChanged(null);
      return;
    }

    widget.onObjectChanged(pickedValue);
  }

  Future<void> showFinancePeriodPicker(BuildContext context) async {
    if (!widget.profile.isAdmin) return;

    final periods = <FinancePeriod>[
      const FinancePeriod.allTime(),
      ...FinancePeriod.recentMonths(AppState.today, count: 18),
    ];

    final pickedPeriod = await showModalBottomSheet<FinancePeriod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
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
                        'Период выплат',
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
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: periods.length,
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final isSelected = isSameFinancePeriod(
                        period,
                        financePeriod,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.pop(context, period);
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
                                  icon: period.isAllTime
                                      ? Icons.all_inclusive
                                      : Icons.calendar_month_outlined,
                                  color: isSelected ? _accent : _text,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        period.pickerTitle(),
                                        style: const TextStyle(
                                          color: _text,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        period.isAllTime
                                            ? 'Вся история табеля и выплат'
                                            : 'Начисления и выплаты за месяц',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: _accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedPeriod == null) return;
    if (isSameFinancePeriod(pickedPeriod, financePeriod)) return;

    setState(() {
      financePeriod = pickedPeriod;
      dashboardFuture = loadDashboardData();
    });
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
    required FinanceSummaryData finance,
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
                    if (widget.profile.isAdmin) ...[
                      const SizedBox(height: 14),
                      _FinanceSummaryCard(
                        title: 'Выплаты ${financePeriod.title()}',
                        objectTitle: objectTitle,
                        finance: isLoading ? FinanceSummaryData.empty : finance,
                        isLoading: isLoading,
                        onPeriodTap: () {
                          showFinancePeriodPicker(context);
                        },
                      ),
                    ],
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
          finance: data.finance,
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
  final FinanceSummaryData finance;

  const _HomeDashboardData({
    required this.employees,
    required this.workedEmployeeIds,
    required this.tasks,
    required this.finance,
  });

  static const empty = _HomeDashboardData(
    employees: <Employee>[],
    workedEmployeeIds: <String>{},
    tasks: <TaskItemData>[],
    finance: FinanceSummaryData.empty,
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
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        bottomValue,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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

class _FinanceSummaryCard extends StatelessWidget {
  final String title;
  final String objectTitle;
  final FinanceSummaryData finance;
  final bool isLoading;
  final VoidCallback onPeriodTap;

  const _FinanceSummaryCard({
    required this.title,
    required this.objectTitle,
    required this.finance,
    required this.isLoading,
    required this.onPeriodTap,
  });

  String formatMoney(double value) {
    final sign = value < 0 ? '-' : '';
    final rounded = value.abs().round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < rounded.length; i++) {
      final indexFromEnd = rounded.length - i;

      buffer.write(rounded[i]);

      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(' ');
      }
    }

    return '$sign${buffer.toString()} ₽';
  }

  @override
  Widget build(BuildContext context) {
    final balance = finance.balance;
    final isOverpaid = balance < 0;
    final balanceTitle = isOverpaid ? 'Переплата' : 'Осталось';
    final balanceValue = isOverpaid ? balance.abs() : balance;
    final progressPercent = (finance.paidProgress * 100).round();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBox(icon: Icons.payments_outlined, color: _accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 18,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      objectTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: isLoading ? null : onPeriodTap,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Период'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FinanceLine(
            label: 'Надо выплатить',
            value: isLoading ? '...' : formatMoney(finance.accrued),
            isMain: true,
          ),
          const SizedBox(height: 10),
          _FinanceLine(
            label: 'Выплачено',
            value: isLoading ? '...' : formatMoney(finance.paid),
          ),
          const SizedBox(height: 10),
          _FinanceLine(
            label: balanceTitle,
            value: isLoading ? '...' : formatMoney(balanceValue),
            isMain: true,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: isLoading ? 0 : finance.paidProgress,
              backgroundColor: const Color(0xFFE8E2DB),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _softCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Закрыто выплатами',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  isLoading ? '...' : '$progressPercent%',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
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

class _FinanceLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isMain;

  const _FinanceLine({
    required this.label,
    required this.value,
    this.isMain = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isMain ? _text : _muted,
              fontSize: isMain ? 16 : 15,
              fontWeight: isMain ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: _text,
            fontSize: isMain ? 20 : 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 42,
            height: 0.95,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            secondaryValue,
            style: const TextStyle(
              color: _muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
              value: progress.clamp(0.0, 1.0).toDouble(),
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
              fontWeight: FontWeight.w900,
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 24),
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
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
