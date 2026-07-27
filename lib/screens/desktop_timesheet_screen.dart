import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import 'package:intl/intl.dart';

import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui.dart';
import 'period_timesheet_screen.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _line => AppAdaptivePalette.border;
Color get _soft => AppAdaptivePalette.surfaceSoft;
Color get _worked => AppAdaptivePalette.success;
Color get _warning => AppAdaptivePalette.warning;

class DesktopTimesheetScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const DesktopTimesheetScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<DesktopTimesheetScreen> createState() =>
      _DesktopTimesheetScreenState();
}

class _DesktopTimesheetScreenState extends State<DesktopTimesheetScreen> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController verticalController = ScrollController();

  DateTime selectedDate = AppState.today;
  List<Employee> employees = const <Employee>[];
  Map<String, double> shiftValuesByEmployeeId = <String, double>{};
  Map<String, double> originalShiftValuesByEmployeeId = <String, double>{};

  String? objectFilter;
  String attendanceFilter = 'Все сотрудники';
  bool isLoading = true;
  bool isSaving = false;
  bool hasUnsavedChanges = false;
  bool hasPendingRemoteAttendance = false;
  String? errorText;
  int loadGeneration = 0;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  static const List<double> quickOptions = <double>[0, 0.5, 1, 1.5, 2];

  @override
  void initState() {
    super.initState();
    objectFilter = cleanObjectName(widget.selectedObjectName);
    loadData();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant DesktopTimesheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (cleanObjectName(oldWidget.selectedObjectName) !=
        cleanObjectName(widget.selectedObjectName)) {
      objectFilter = cleanObjectName(widget.selectedObjectName);
      attendanceFilter = 'Все сотрудники';
      searchController.clear();
      loadData(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    searchController.dispose();
    verticalController.dispose();
    super.dispose();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String get objectTitle =>
      cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';

  bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String shortDate(DateTime date) => DateFormat('dd.MM.yyyy').format(date);

  String longDate(DateTime date) {
    const months = <String>[
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
    const weekdays = <String>[
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];
    return '${date.day} ${months[date.month - 1]} · ${weekdays[date.weekday - 1]}';
  }

  String formatShift(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  double shiftValueFor(Employee employee) {
    final id = employee.id;
    return id == null ? 0 : shiftValuesByEmployeeId[id] ?? 0;
  }

  bool changeMatchesCurrentTimesheet(AppDataChange change) {
    final workDate = change.contextValue('work_date');
    if (workDate != null &&
        workDate != AttendanceRepository.dateKey(selectedDate)) {
      return false;
    }

    final selectedObject = cleanObjectName(widget.selectedObjectName);
    final changedObject = cleanObjectName(change.contextValue('object_name'));
    return selectedObject == null ||
        changedObject == null ||
        selectedObject == changedObject;
  }

  void handleDataChange(AppDataChange change) {
    if (!mounted) return;

    final employeesChanged = change.affectsAny(const <AppDataDomain>{
      AppDataDomain.employees,
      AppDataDomain.objects,
    });
    final attendanceChanged = change.affectsAny(const <AppDataDomain>{
      AppDataDomain.attendance,
      AppDataDomain.objects,
    });

    if (employeesChanged) {
      loadData(forceRefresh: true, attendanceOnly: false);
      return;
    }

    if (!attendanceChanged ||
        !change.isRemote ||
        !changeMatchesCurrentTimesheet(change)) {
      return;
    }

    if (hasUnsavedChanges || isSaving || isLoading) {
      hasPendingRemoteAttendance = true;
      return;
    }

    loadData(forceRefresh: true, attendanceOnly: true);
  }

  Future<void> loadData({
    bool forceRefresh = false,
    bool attendanceOnly = false,
  }) async {
    final generation = ++loadGeneration;
    final requestedDate = selectedDate;
    final requestedObject = widget.selectedObjectName;
    hasPendingRemoteAttendance = false;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final employeeFuture = attendanceOnly
          ? Future<List<Employee>>.value(employees)
          : EmployeeRepository.fetchEmployees(
              objectName: requestedObject,
              forceRefresh: forceRefresh,
            );
      final results = await Future.wait<dynamic>([
        employeeFuture,
        AttendanceRepository.fetchShiftValuesForDate(
          requestedDate,
          objectName: requestedObject,
          forceRefresh: forceRefresh,
        ),
      ]);

      if (!mounted || generation != loadGeneration) return;

      final loadedEmployees = results[0] as List<Employee>;
      final loadedValues = results[1] as Map<String, double>;
      final availableObjects = loadedEmployees
          .map((employee) => employee.objectName.trim())
          .where((name) => name.isNotEmpty)
          .toSet();

      setState(() {
        employees = loadedEmployees;
        shiftValuesByEmployeeId = Map<String, double>.from(loadedValues);
        originalShiftValuesByEmployeeId = Map<String, double>.from(
          loadedValues,
        );
        hasUnsavedChanges = false;
        isLoading = false;

        final lockedObject = cleanObjectName(widget.selectedObjectName);
        if (lockedObject != null) {
          objectFilter = lockedObject;
        } else if (objectFilter != null &&
            !availableObjects.contains(objectFilter)) {
          objectFilter = null;
        }
      });
    } catch (error) {
      if (!mounted || generation != loadGeneration) return;
      setState(() {
        isLoading = false;
        errorText = 'Ошибка загрузки табеля: $error';
      });
    }
  }

  void applyPendingRemoteAttendance() {
    if (!mounted ||
        !hasPendingRemoteAttendance ||
        hasUnsavedChanges ||
        isSaving ||
        isLoading) {
      return;
    }
    loadData(forceRefresh: true, attendanceOnly: true);
  }

  void setShiftValue(Employee employee, double value) {
    final id = employee.id;
    if (id == null || shiftValuesByEmployeeId[id] == value) return;

    setState(() {
      shiftValuesByEmployeeId[id] = value;
      hasUnsavedChanges = true;
    });
  }

  void setVisibleShifts(List<Employee> visible, double value) {
    final next = Map<String, double>.from(shiftValuesByEmployeeId);
    var changed = false;

    for (final employee in visible) {
      final id = employee.id;
      if (id == null || next[id] == value) continue;
      next[id] = value;
      changed = true;
    }

    if (!changed) return;
    setState(() {
      shiftValuesByEmployeeId = next;
      hasUnsavedChanges = true;
    });
  }

  Future<void> changeDate(DateTime date) async {
    final cleanDate = DateTime(date.year, date.month, date.day);
    if (isSameDate(cleanDate, selectedDate)) return;

    setState(() {
      selectedDate = cleanDate;
      shiftValuesByEmployeeId = <String, double>{};
      originalShiftValuesByEmployeeId = <String, double>{};
      hasUnsavedChanges = false;
      hasPendingRemoteAttendance = false;
    });
    await loadData(attendanceOnly: true);
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату табеля',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) await changeDate(picked);
  }

  Future<void> showShiftPicker(Employee employee) async {
    var selected = shiftValueFor(employee);

    final picked = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(employee.name),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Смена: ${formatShift(selected)}',
                      style: TextStyle(
                        color: _text,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 18),
                    Slider(
                      value: selected.clamp(0, 3),
                      min: 0,
                      max: 3,
                      divisions: 30,
                      label: formatShift(selected),
                      onChanged: (value) {
                        setDialogState(() => selected = value);
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: quickOptions.map((option) {
                        return ChoiceChip(
                          label: Text(formatShift(option)),
                          selected: selected == option,
                          onSelected: (_) {
                            setDialogState(() => selected = option);
                          },
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selected),
                  child: const Text('Выбрать'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) setShiftValue(employee, picked);
  }

  Future<void> saveTimesheet() async {
    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await AttendanceRepository.saveTimesheet(
        date: selectedDate,
        employees: employees,
        shiftValuesByEmployeeId: shiftValuesByEmployeeId,
        originalShiftValuesByEmployeeId: originalShiftValuesByEmployeeId,
      );

      if (!mounted) return;
      setState(() {
        originalShiftValuesByEmployeeId = Map<String, double>.from(
          shiftValuesByEmployeeId,
        );
        hasUnsavedChanges = false;
      });

      final worked = employees.where((employee) => shiftValueFor(employee) > 0);
      final total = worked.fold<double>(
        0,
        (sum, employee) => sum + shiftValueFor(employee),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Табель сохранён: ${worked.length} человек, ${formatShift(total)} смен',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка сохранения табеля: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
        scheduleMicrotask(applyPendingRemoteAttendance);
      }
    }
  }

  List<String> get objectOptions {
    final values = employees
        .map((employee) => employee.objectName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<Employee> visibleEmployees() {
    final query = searchController.text.trim().toLowerCase();
    final selectedObject = cleanObjectName(objectFilter);

    final result = employees.where((employee) {
      if (selectedObject != null && employee.objectName != selectedObject) {
        return false;
      }

      final shift = shiftValueFor(employee);
      if (attendanceFilter == 'Только вышедшие' && shift <= 0) return false;
      if (attendanceFilter == 'Не вышли' && shift > 0) return false;

      if (query.isEmpty) return true;
      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          employee.objectName.toLowerCase().contains(query);
    }).toList();

    result.sort((first, second) {
      final object = first.objectName.compareTo(second.objectName);
      if (object != 0) return object;
      return first.name.compareTo(second.name);
    });
    return result;
  }

  void openReport() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
        leading: const BackButton(),title: Text('Отчет по табелю — $objectTitle')),
          body: PeriodTimesheetScreen(
            selectedObjectName: widget.selectedObjectName,
          ),
        ),
      ),
    );
  }

  Widget buildToolbar() {
    final enabled = !isLoading && !isSaving;

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _SquareButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Предыдущий день',
            onTap: enabled
                ? () => changeDate(selectedDate.subtract(const Duration(days: 1)))
                : null,
          ),
          SizedBox(width: 10),
          PremiumPressable(
            onTap: enabled ? pickDate : null,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 250,
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: _muted),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortDate(selectedDate),
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          longDate(selectedDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
          _SquareButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Следующий день',
            onTap: enabled
                ? () => changeDate(selectedDate.add(const Duration(days: 1)))
                : null,
          ),
          SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: enabled && !isSameDate(selectedDate, AppState.today)
                ? () => changeDate(AppState.today)
                : null,
            icon: Icon(Icons.today_outlined),
            label: const Text('Сегодня'),
          ),
          const Spacer(),
          if (widget.profile.isAdmin)
            OutlinedButton.icon(
              onPressed: openReport,
              icon: Icon(Icons.analytics_outlined),
              label: const Text('Отчёт'),
            ),
          SizedBox(width: 10),
          IconButton(
            onPressed: enabled ? () => loadData(forceRefresh: true) : null,
            tooltip: 'Обновить табель',
            icon: Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget buildMetrics(List<Employee> visible) {
    final workedCount = visible.where((employee) => shiftValueFor(employee) > 0).length;
    final totalShifts = visible.fold<double>(
      0,
      (sum, employee) => sum + shiftValueFor(employee),
    );
    final absentCount = visible.length - workedCount;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Сотрудников',
            value: '${visible.length}',
            icon: Icons.groups_outlined,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            label: 'Вышли',
            value: '$workedCount',
            icon: Icons.how_to_reg_outlined,
            accent: _worked,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            label: 'Не вышли',
            value: '$absentCount',
            icon: Icons.person_off_outlined,
            accent: _warning,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            label: 'Всего смен',
            value: formatShift(totalShifts),
            icon: Icons.schedule_outlined,
          ),
        ),
      ],
    );
  }

  Widget buildFilters(List<Employee> visible) {
    final lockedObject = cleanObjectName(widget.selectedObjectName);

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по ФИО, должности или объекту',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: _soft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _DropdownShell(
              icon: Icons.apartment_outlined,
              child: DropdownButton<String?>(
                value: lockedObject ?? objectFilter,
                isExpanded: true,
                items: <DropdownMenuItem<String?>>[
                  if (lockedObject == null)
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все объекты'),
                    ),
                  ...objectOptions.map(
                    (objectName) => DropdownMenuItem<String?>(
                      value: objectName,
                      child: Text(
                        objectName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: lockedObject == null
                    ? (value) => setState(() => objectFilter = value)
                    : null,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _DropdownShell(
              icon: Icons.filter_alt_outlined,
              child: DropdownButton<String>(
                value: attendanceFilter,
                isExpanded: true,
                items: const <String>[
                  'Все сотрудники',
                  'Только вышедшие',
                  'Не вышли',
                ]
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => attendanceFilter = value);
                },
              ),
            ),
          ),
          SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: visible.isEmpty || isLoading || isSaving
                ? null
                : () => setVisibleShifts(visible, 1),
            icon: Icon(Icons.done_all_rounded),
            label: const Text('Всем 1'),
          ),
          SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: visible.isEmpty || isLoading || isSaving
                ? null
                : () => setVisibleShifts(visible, 0),
            icon: Icon(Icons.remove_done_rounded),
            label: const Text('Всем 0'),
          ),
        ],
      ),
    );
  }

  Widget buildTable(List<Employee> visible) {
    return PremiumWorkCard(
      radius: 26,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            const _TableHeader(),
            if (visible.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Сотрудники не найдены',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...visible.map(
                (employee) => _TimesheetRow(
                  employee: employee,
                  value: shiftValueFor(employee),
                  formatShift: formatShift,
                  enabled: !isLoading && !isSaving,
                  onSelected: (value) => setShiftValue(employee, value),
                  onCustom: () => showShiftPicker(employee),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleEmployees();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumWorkBackdrop(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: verticalController,
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppPageHeader(
                            title: 'Табель',
                            subtitle:
                                'ПК-вид · быстрый ввод смен за выбранную дату • $objectTitle',
                          ),
                          SizedBox(height: 18),
                          buildToolbar(),
                          SizedBox(height: 16),
                          buildMetrics(visible),
                          SizedBox(height: 16),
                          buildFilters(visible),
                          if (isLoading || isSaving) ...[
                            SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          if (errorText != null) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: _warning.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                errorText!,
                                style: TextStyle(
                                  color: _warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 16),
                          buildTable(visible),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 12),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceElevated,
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasUnsavedChanges
                                ? 'Есть несохранённые изменения'
                                : 'Все изменения сохранены',
                            style: TextStyle(
                              color: hasUnsavedChanges ? _warning : _muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: FilledButton.icon(
                            onPressed: employees.isEmpty || isLoading || isSaving
                                ? null
                                : saveTimesheet,
                            icon: isSaving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.save_outlined),
                            label: Text(
                              hasUnsavedChanges
                                  ? 'Сохранить изменения'
                                  : 'Сохранить табель',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Icon(icon, color: onTap == null ? _line : _text),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppAdaptivePalette.telegramBlue,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: _text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _DropdownShell extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _DropdownShell({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _muted),
          SizedBox(width: 8),
          Expanded(child: DropdownButtonHideUnderline(child: child)),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: _soft,
      child: Row(
        children: [
          Expanded(flex: 4, child: _HeaderText('Сотрудник')),
          Expanded(flex: 2, child: _HeaderText('Объект')),
          Expanded(flex: 2, child: _HeaderText('Должность')),
          Expanded(flex: 4, child: _HeaderText('Смена')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TimesheetRow extends StatelessWidget {
  final Employee employee;
  final double value;
  final String Function(double value) formatShift;
  final bool enabled;
  final ValueChanged<double> onSelected;
  final VoidCallback onCustom;

  const _TimesheetRow({
    required this.employee,
    required this.value,
    required this.formatShift,
    required this.enabled,
    required this.onSelected,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final hasWorked = value > 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasWorked
                        ? _worked.withValues(alpha: 0.12)
                        : _soft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    employee.name.trim().isEmpty
                        ? '—'
                        : employee.name.trim()[0].toUpperCase(),
                    style: TextStyle(
                      color: hasWorked ? _worked : _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    employee.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              employee.objectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              employee.position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ...DesktopTimesheetScreenStateQuickOptions.values.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ShiftButton(
                      label: formatShift(option),
                      selected: value == option,
                      enabled: enabled,
                      onTap: () => onSelected(option),
                    ),
                  ),
                ),
                _ShiftButton(
                  label: value > 2 ||
                          !DesktopTimesheetScreenStateQuickOptions.values
                              .contains(value)
                      ? formatShift(value)
                      : 'Другое',
                  selected: value > 2 ||
                      !DesktopTimesheetScreenStateQuickOptions.values
                          .contains(value),
                  enabled: enabled,
                  onTap: onCustom,
                  wide: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

abstract final class DesktopTimesheetScreenStateQuickOptions {
  static const List<double> values = <double>[0, 0.5, 1, 1.5, 2];
}

class _ShiftButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool wide;

  const _ShiftButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumPressable(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: wide ? 74 : 42,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppAdaptivePalette.accentStrong : _soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppAdaptivePalette.accent : _line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppAdaptivePalette.onAccent : _muted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
