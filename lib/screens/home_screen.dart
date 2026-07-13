import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_data_sync.dart';
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
import '../widgets/premium_ui.dart';

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
  static const String _archiveListValue = '__archive_list__';
  static const String _editObjectPrefix = '__edit_object__::';
  static const String _archiveObjectPrefix = '__archive_object__::';

  Future<_HomeDashboardData>? dashboardFuture;
  Future<List<String>>? objectNamesFuture;
  FinancePeriod financePeriod = FinancePeriod.current(AppState.today);
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  @override
  void initState() {
    super.initState();
    dashboardFuture = loadDashboardData();
    objectNamesFuture = EmployeeRepository.fetchObjectNames();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      dashboardFuture = loadDashboardData();
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    super.dispose();
  }

  void handleDataChange(AppDataChange change) {
    const dashboardDomains = <AppDataDomain>{
      AppDataDomain.attendance,
      AppDataDomain.payments,
      AppDataDomain.employees,
      AppDataDomain.tasks,
      AppDataDomain.objects,
    };

    if (!mounted || !change.affectsAny(dashboardDomains)) return;

    final refreshObjects = change.affects(AppDataDomain.objects);

    setState(() {
      if (refreshObjects) {
        objectNamesFuture = EmployeeRepository.fetchObjectNames(
          forceRefresh: true,
        );
      }
      dashboardFuture = loadDashboardData(forceRefresh: true);
    });
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  String normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String get objectTitle {
    return cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';
  }

  String dateText(DateTime date) {
    const months = [
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

  bool isSameObject(String? first, String? second) {
    return cleanObjectName(first) == cleanObjectName(second);
  }

  bool isSameFinancePeriod(FinancePeriod first, FinancePeriod second) {
    return first.year == second.year && first.month == second.month;
  }

  Future<_HomeDashboardData> loadDashboardData({
    bool forceRefresh = false,
  }) async {
    final today = AppState.today;
    final selectedObject = cleanObjectName(widget.selectedObjectName);

    final results = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      AttendanceRepository.fetchWorkedEmployeeIds(
        today,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      TaskRepository.fetchTasksForDate(
        today,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      FinanceSummaryRepository.fetchSummary(
        period: financePeriod,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      if (selectedObject == null)
        ObjectRepository.fetchObjectNames(forceRefresh: forceRefresh),
    ]);

    final employees = results[0] as List<Employee>;
    final workedEmployeeIds = results[1] as Set<String>;
    var tasks = results[2] as List<TaskItemData>;

    if (selectedObject == null) {
      final activeObjectNames = (results[4] as List<String>).toSet();
      tasks = tasks
          .where((task) => activeObjectNames.contains(task.objectName.trim()))
          .toList();
    }

    return _HomeDashboardData(
      employees: employees,
      workedEmployeeIds: workedEmployeeIds,
      tasks: tasks,
      finance: results[3] as FinanceSummaryData,
    );
  }

  void refreshObjectsAndDashboard() {
    ObjectRepository.clearCache();
    EmployeeRepository.clearCache();
    AttendanceRepository.clearCache();
    TaskRepository.clearTaskListCache();
    FinanceSummaryRepository.clearCache();

    if (!mounted) return;

    setState(() {
      objectNamesFuture = EmployeeRepository.fetchObjectNames(
        forceRefresh: true,
      );
      dashboardFuture = loadDashboardData(forceRefresh: true);
    });
  }

  Future<String?> showObjectNameSheet({String? currentName}) async {
    if (!widget.profile.isAdmin) return null;

    final isEdit = currentName != null;
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentName ?? '');
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
                        newName: controller.text,
                      )
                    : await ObjectRepository.addObject(name: controller.text);

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext, savedName);
              } catch (error) {
                if (!sheetContext.mounted) return;

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
                                isEdit
                                    ? 'Редактировать объект'
                                    : 'Новый объект',
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
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: controller,
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
                          onFieldSubmitted: (_) => saveObject(),
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
                          height: 52,
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
                                : Icon(
                                    isEdit
                                        ? Icons.save_outlined
                                        : Icons.add_business_outlined,
                                  ),
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

    controller.dispose();
    return result;
  }

  Future<void> handleAddObject() async {
    final createdName = await showObjectNameSheet();

    if (createdName == null || createdName.trim().isEmpty) return;

    widget.onObjectChanged(createdName);
    refreshObjectsAndDashboard();
  }

  Future<void> handleRenameObject(String oldName) async {
    final newName = await showObjectNameSheet(currentName: oldName);

    if (newName == null || newName.trim().isEmpty) return;

    if (isSameObject(widget.selectedObjectName, oldName)) {
      widget.onObjectChanged(newName);
    }

    refreshObjectsAndDashboard();
  }

  Future<void> handleArchiveObject(String objectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Архивировать объект?'),
          content: Text(
            'Объект "$objectName" исчезнет из рабочего списка. Табели, задачи, выплаты и документы сохранятся. Сотрудники на этом объекте будут отмечены как уволенные.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('В архив'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final wasSelected = isSameObject(widget.selectedObjectName, objectName);

      await ObjectRepository.archiveObject(name: objectName);

      if (wasSelected) {
        widget.onObjectChanged(null);
      }

      refreshObjectsAndDashboard();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Объект "$objectName" перемещён в архив')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> showArchivedObjectsSheet(BuildContext context) async {
    List<String> archivedObjects;

    try {
      archivedObjects = await ObjectRepository.fetchArchivedObjectNames(
        forceRefresh: true,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Архив объектов',
                        style: TextStyle(
                          color: _text,
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
                if (archivedObjects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 42,
                          color: _muted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Архив пуст',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: archivedObjects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final objectName = archivedObjects[index];

                        return Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: _softCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  objectName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await ObjectRepository.restoreObject(
                                      name: objectName,
                                    );

                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                    refreshObjectsAndDashboard();

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Объект "$objectName" восстановлен',
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!sheetContext.mounted) return;

                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text('Вернуть'),
                              ),
                            ],
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
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
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
                      tooltip: 'Архив объектов',
                      onPressed: () {
                        Navigator.pop(sheetContext, _archiveListValue);
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(sheetContext, _addObjectValue);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Объект'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
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
                        title: 'Все объекты',
                        subtitle: 'Сводка по всем активным объектам',
                        icon: Icons.apartment_outlined,
                        isSelected: selectedValue == _allObjectsValue,
                        onTap: () {
                          Navigator.pop(sheetContext, _allObjectsValue);
                        },
                      ),
                      ...objects.map((objectName) {
                        return _ObjectPickerTile(
                          title: objectName,
                          subtitle: 'Данные только по этому объекту',
                          icon: Icons.business_outlined,
                          isSelected: objectName == selectedValue,
                          onTap: () {
                            Navigator.pop(sheetContext, objectName);
                          },
                          onEdit: () {
                            Navigator.pop(
                              sheetContext,
                              '$_editObjectPrefix$objectName',
                            );
                          },
                          onArchive: () {
                            Navigator.pop(
                              sheetContext,
                              '$_archiveObjectPrefix$objectName',
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

    if (!context.mounted) return;
    if (pickedValue == null) return;

    if (pickedValue == _archiveListValue) {
      await showArchivedObjectsSheet(context);
      return;
    }

    if (pickedValue == _addObjectValue) {
      await handleAddObject();
      return;
    }

    if (pickedValue.startsWith(_editObjectPrefix)) {
      final objectName = pickedValue.substring(_editObjectPrefix.length);
      await handleRenameObject(objectName);
      return;
    }

    if (pickedValue.startsWith(_archiveObjectPrefix)) {
      final objectName = pickedValue.substring(_archiveObjectPrefix.length);
      await handleArchiveObject(objectName);
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

    final picked = await showModalBottomSheet<FinancePeriod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      onPressed: () => Navigator.pop(sheetContext),
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
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.pop(sheetContext, period),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? _softCard : _card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? _accent : _line,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  period.isAllTime
                                      ? Icons.all_inclusive
                                      : Icons.calendar_month_outlined,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    period.pickerTitle(),
                                    style: const TextStyle(
                                      color: _text,
                                      fontWeight: FontWeight.w900,
                                    ),
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

    if (picked == null || isSameFinancePeriod(picked, financePeriod)) return;

    setState(() {
      financePeriod = picked;
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
        final objects = snapshot.data ?? const <String>[];

        return _ObjectSelectorShell(
          icon: Icons.apartment_outlined,
          title: objectTitle,
          onTap: () => showObjectPicker(context, objects),
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
            const PremiumBrandMark(size: 52, animate: false),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AppСтрой',
                    style: TextStyle(
                      color: _text,
                      fontSize: 31,
                      height: 1,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.1,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Рабочая сводка',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            NotificationBell(selectedObjectName: widget.selectedObjectName),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: _muted, size: 20),
            const SizedBox(width: 10),
            Text(
              'Сегодня, ${dateText(today)}',
              style: const TextStyle(
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
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
    final employeeById = <String, Employee>{};
    final activeEmployeeNames = <String>{};

    for (final employee in employees) {
      final id = employee.id?.trim();

      if (id != null && id.isNotEmpty) {
        employeeById[id] = employee;
      }

      activeEmployeeNames.add(normalizeName(employee.name));
    }

    final workedEmployeeNames = <String>{};

    for (final employeeId in workedEmployeeIds) {
      final employee = employeeById[employeeId];

      if (employee != null) {
        workedEmployeeNames.add(normalizeName(employee.name));
      }
    }

    final totalEmployees = activeEmployeeNames.length;
    final workedEmployees = workedEmployeeNames.length;
    final totalTasks = tasks.length;
    final doneTasks = tasks.where((task) => task.status == 'Выполнено').length;
    final employeesProgress = totalEmployees == 0
        ? 0.0
        : workedEmployees / totalEmployees;
    final tasksProgress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

    return PremiumWorkBackdrop(
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
                      value: isLoading ? '...' : workedEmployees.toString(),
                      secondaryValue: isLoading ? '...' : 'из $totalEmployees',
                      progress: employeesProgress,
                      footerTitle: 'На объекте',
                      footerValue: isLoading
                          ? '...'
                          : workedEmployees.toString(),
                      footerColor: _success,
                    ),
                    const SizedBox(height: 14),
                    _DashboardMetricCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Задачи на сегодня',
                      value: isLoading ? '...' : totalTasks.toString(),
                      secondaryValue: 'всего',
                      progress: tasksProgress,
                      footerTitle: 'Выполнено',
                      footerValue: isLoading ? '...' : doneTasks.toString(),
                      footerColor: _accent,
                    ),
                    if (widget.profile.isAdmin) ...[
                      const SizedBox(height: 14),
                      _FinanceSummaryCard(
                        title: 'Выплаты ${financePeriod.title()}',
                        objectTitle: objectTitle,
                        finance: isLoading ? FinanceSummaryData.empty : finance,
                        isLoading: isLoading,
                        onPeriodTap: () => showFinancePeriodPicker(context),
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
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  const _ObjectPickerTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
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
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Редактировать объект',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              if (onArchive != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Архивировать объект',
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined, size: 20),
                ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: _accent),
                ),
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
  final String footerTitle;
  final String footerValue;
  final Color footerColor;

  const _DashboardMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.secondaryValue,
    required this.progress,
    required this.footerTitle,
    required this.footerValue,
    required this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();

    return PremiumWorkCard(
      radius: 28,
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
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 44,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        secondaryValue,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: safeProgress,
                    backgroundColor: const Color(0xFFE8E2DB),
                    valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
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
                          color: footerColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          footerTitle,
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        footerValue,
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
    final text = value.abs().round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$sign$text ₽';
  }

  @override
  Widget build(BuildContext context) {
    final balance = finance.balance;
    final balanceTitle = balance < 0 ? 'Переплата' : 'Осталось';
    final balanceValue = balance < 0 ? balance.abs() : balance;
    final progressPercent = (finance.paidProgress * 100).round();

    return PremiumWorkCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBox(icon: Icons.payments_outlined, color: _accent),
              const SizedBox(width: 14),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MoneyPill(
                title: 'Начислено',
                value: formatMoney(finance.accrued),
              ),
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
