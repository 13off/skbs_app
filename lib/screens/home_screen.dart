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
import '../widgets/notification_bell.dart';

const Color _bg = Color(0xFFF7F8FA);
const Color _card = Color(0xFFFFFFFF);
const Color _softCard = Color(0xFFF2F3F5);
const Color _line = Color(0xFFE6E8EB);
const Color _text = Color(0xFF1F2328);
const Color _muted = Color(0xFF6B7075);
const Color _accent = Color(0xFF8F9499);
const Color _success = Color(0xFF22C55E);

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
  static const String _allObjectsValue = '__all__';
  static const String _addObjectValue = '__add_object__';
  static const String _editObjectPrefix = '__edit_object__::';

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

  String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  String get objectTitle {
    return cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';
  }

  bool isSameFinancePeriod(FinancePeriod a, FinancePeriod b) {
    return a.year == b.year && a.month == b.month;
  }

  bool isSameObject(String? a, String? b) {
    return cleanObjectName(a) == cleanObjectName(b);
  }

  void refreshObjectsAndDashboard() {
    ObjectRepository.clearCache();
    EmployeeRepository.clearCache();
    AttendanceRepository.clearCache();
    TaskRepository.clearTaskListCache();

    setState(() {
      objectNamesFuture = EmployeeRepository.fetchObjectNames(
        forceRefresh: true,
      );
      dashboardFuture = loadDashboardData();
    });
  }

  Future<String?> showObjectNameSheet({String? currentName}) async {
    if (!widget.profile.isAdmin) return null;

    final isEdit = currentName != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: currentName ?? '');

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
                final savedName = isEdit
                    ? await ObjectRepository.renameObject(
                        oldName: currentName,
                        newName: nameController.text,
                      )
                    : await ObjectRepository.addObject(name: nameController.text);

                if (!context.mounted) return;

                Navigator.pop(context, savedName);
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
                            Expanded(
                              child: Text(
                                isEdit ? 'Редактировать объект' : 'Новый объект',
                                style: const TextStyle(
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
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Название объекта',
                            hintText: isEdit ? currentName : 'Например: Талнах',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.business_outlined),
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
                          onFieldSubmitted: (_) {
                            saveObject();
                          },
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
                                : Icon(isEdit ? Icons.save_outlined : Icons.add),
                            label: Text(
                              isSaving
                                  ? 'Сохраняем...'
                                  : isEdit
                                  ? 'Сохранить'
                                  : 'Создать',
                            ),
                          ),
                        ),
                      ],
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

    return result;
  }

  Future<void> handleAddObject() async {
    final createdObjectName = await showObjectNameSheet();

    if (createdObjectName == null || createdObjectName.trim().isEmpty) return;

    refreshObjectsAndDashboard();
    widget.onObjectChanged(createdObjectName);
  }

  Future<void> handleRenameObject(String oldName) async {
    final newName = await showObjectNameSheet(currentName: oldName);

    if (newName == null || newName.trim().isEmpty) return;

    refreshObjectsAndDashboard();

    if (isSameObject(widget.selectedObjectName, oldName)) {
      widget.onObjectChanged(newName);
    }
  }

  Future<void> showObjectPicker(
    BuildContext context,
    List<String> objects,
  ) async {
    if (!widget.profile.isAdmin) return;

    final selectedValue = widget.selectedObjectName ?? _allObjectsValue;

    final pickedValue = await showModalBottomSheet<String>(
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
                        'Выберите объект',
                        style: TextStyle(
                          color: _text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context, _addObjectValue);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Объект'),
                    ),
                    const SizedBox(width: 6),
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
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _ObjectPickerTile(
                        value: _allObjectsValue,
                        title: 'Все объекты',
                        subtitle: 'Сводка по всем объектам',
                        icon: Icons.apartment_outlined,
                        isSelected: selectedValue == _allObjectsValue,
                        onTap: () {
                          Navigator.pop(context, _allObjectsValue);
                        },
                      ),
                      ...objects.map((objectName) {
                        final isSelected = objectName == selectedValue;

                        return _ObjectPickerTile(
                          value: objectName,
                          title: objectName,
                          subtitle: 'Данные только по этому объекту',
                          icon: Icons.business_outlined,
                          isSelected: isSelected,
                          onTap: () {
                            Navigator.pop(context, objectName);
                          },
                          onEdit: () {
                            Navigator.pop(
                              context,
                              '$_editObjectPrefix$objectName',
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedValue == null) return;

    if (pickedValue == _addObjectValue) {
      await handleAddObject();
      return;
    }

    if (pickedValue.startsWith(_editObjectPrefix)) {
      final objectName = pickedValue.substring(_editObjectPrefix.length);
      await handleRenameObject(objectName);
      return;
    }

    if (pickedValue == _allObjectsValue) {
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
            NotificationBell(selectedObjectName: widget.selectedObjectName),
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

class _ObjectPickerTile extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _ObjectPickerTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? _softCard : _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _accent : _line),
          ),
          child: Row(
            children: [
              _IconBox(icon: icon, color: isSelected ? _accent : _text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Редактировать объект',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              if (isSelected)
                const Icon(Icons.check_circle, color: _accent),
            ],
          ),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      objectTitle,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onPeriodTap,
                child: const Text('Период'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MoneyPill(title: 'Начислено', value: formatMoney(finance.accrued)),
              _MoneyPill(title: 'Выплачено', value: formatMoney(finance.paid)),
              _MoneyPill(title: balanceTitle, value: formatMoney(balanceValue)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: finance.paidProgress,
              backgroundColor: const Color(0xFFE8E2DB),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Закрыто выплатами: $progressPercent%',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
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
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 46,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            secondaryValue,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
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
          CircularProgressIndicator(
            value: progress,
            strokeWidth: stroke,
            backgroundColor: const Color(0xFFE8E2DB),
            valueColor: const AlwaysStoppedAnimation<Color>(_accent),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyPill extends StatelessWidget {
  final String title;
  final String value;

  const _MoneyPill({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 15,
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
      width: 42,
      height: 42,
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
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _muted),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: _muted,
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
