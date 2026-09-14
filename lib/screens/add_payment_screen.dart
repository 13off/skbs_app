import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skbs_app/widgets/app_input_formatters.dart';

import '../app/app_adaptive_palette.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/payment_receipt_repository.dart';
import '../data/payment_repository.dart';
import '../models/employee.dart';
import '../widgets/object_employee_scope.dart';

List<Employee> searchPaymentEmployees({
  required Iterable<Employee> employees,
  required String query,
  int limit = 12,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final ranked = employees.map((employee) {
    final normalizedName = employee.name.trim().toLowerCase();
    final words = normalizedName.split(RegExp(r'\s+'));
    final rank = normalizedQuery.isEmpty
        ? 0
        : normalizedName.startsWith(normalizedQuery)
        ? 0
        : words.any((word) => word.startsWith(normalizedQuery))
        ? 1
        : normalizedName.contains(normalizedQuery)
        ? 2
        : 3;
    return (employee: employee, rank: rank);
  }).where((item) => item.rank < 3).toList();
  ranked.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    return a.employee.name.compareTo(b.employee.name);
  });
  return ranked.take(limit).map((item) => item.employee).toList();
}

class AddPaymentScreen extends StatefulWidget {
  final int periodYear;
  final int periodMonth;
  final String periodTitle;
  final String? initialEmployeeId;
  final String? initialObjectName;

  const AddPaymentScreen({
    super.key,
    required this.periodYear,
    required this.periodMonth,
    required this.periodTitle,
    this.initialEmployeeId,
    this.initialObjectName,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final amountController = TextEditingController();
  final commentController = TextEditingController();
  final employeeSearchController = TextEditingController();
  final employeeSearchFocusNode = FocusNode();

  String? selectedObjectName;
  String? selectedEmployeeId;
  DateTime paymentDate = DateTime.now();
  late DateTime settlementMonth;

  String selectedPaymentType = 'advance';

  final Map<String, String> paymentTypeLabels = const {
    'advance': 'Аванс',
    'salary': 'Заработная плата',
    'fine': 'Штраф',
  };

  List<String> objectNames = [];
  List<Employee> employees = [];
  List<PickedPaymentReceiptFile> receiptFiles = [];

  bool isLoadingEmployees = true;
  bool isSaving = false;
  bool isPickingReceipts = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    settlementMonth = DateTime(widget.periodYear, widget.periodMonth, 1);
    final initialObject = widget.initialObjectName?.trim();
    selectedObjectName = initialObject == null || initialObject.isEmpty
        ? null
        : initialObject;
    selectedEmployeeId = widget.initialEmployeeId;
    loadEmployees();
  }

  @override
  void dispose() {
    amountController.dispose();
    commentController.dispose();
    employeeSearchController.dispose();
    employeeSearchFocusNode.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String monthName(int month) {
    const names = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    if (month < 1 || month > names.length) return 'Месяц';
    return names[month - 1];
  }

  String get settlementPeriodTitle =>
      '${monthName(settlementMonth.month)} ${settlementMonth.year}';

  Future<void> pickSettlementPeriod() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        var year = settlementMonth.year;
        var month = settlementMonth.month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Расчётный период'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Предыдущий год',
                          onPressed: () => setDialogState(() => year -= 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '$year',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Следующий год',
                          onPressed: () => setDialogState(() => year += 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(12, (index) {
                        final value = index + 1;
                        return ChoiceChip(
                          label: Text(monthName(value)),
                          selected: month == value,
                          onSelected: (_) {
                            setDialogState(() => month = value);
                          },
                        );
                      }),
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
                  onPressed: () {
                    Navigator.pop(dialogContext, DateTime(year, month, 1));
                  },
                  child: const Text('Выбрать'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => settlementMonth = picked);
  }

  double? parseAmount() {
    final text = AppInputFormatters.normalizeNumber(amountController.text);

    if (text.isEmpty) return null;

    return double.tryParse(text);
  }

  Future<void> loadEmployees() async {
    setState(() {
      isLoadingEmployees = true;
      errorText = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(includeFired: true),
        ObjectRepository.fetchObjectNames(),
      ]);
      final loadedEmployees = results[0] as List<Employee>;
      final employeesWithId = loadedEmployees
          .where((employee) => employee.id != null)
          .toList();
      final names = <String>{
        ...(results[1] as List<String>).map((name) => name.trim()),
        ...employeesWithId.map((employee) => employee.objectName.trim()),
      }.where((name) => name.isNotEmpty).toList()..sort();

      Employee? selectedEmployee;
      for (final employee in employeesWithId) {
        if (employee.id == selectedEmployeeId) {
          selectedEmployee = employee;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        employees = employeesWithId;
        objectNames = names;

        if (selectedEmployee != null) {
          final employeeObject = selectedEmployee.objectName.trim();
          selectedObjectName = employeeObject.isEmpty ? null : employeeObject;
        } else {
          final objectStillExists =
              selectedObjectName != null &&
              names.contains(selectedObjectName!.trim());
          if (!objectStillExists) {
            selectedObjectName = null;
            selectedEmployeeId = null;
          } else if (!employeesForSelectedObject().any(
            (employee) => employee.id == selectedEmployeeId,
          )) {
            selectedEmployeeId = null;
          }
        }
      });
      employeeSearchController.text = findSelectedEmployee()?.name ?? '';
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки объектов и сотрудников: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmployees = false;
        });
      }
    }
  }

  List<Employee> employeesForSelectedObject() {
    final result = filterEmployeesByObject<Employee>(
      employees: employees,
      selectedObject: selectedObjectName,
      objectNameOf: (employee) => employee.objectName,
    );
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Employee? findSelectedEmployee() {
    if (selectedEmployeeId == null) return null;

    for (final employee in employees) {
      if (employee.id == selectedEmployeeId) {
        return employee;
      }
    }

    return null;
  }

  Future<void> pickPaymentDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Дата выплаты',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null) return;

    setState(() {
      paymentDate = pickedDate;
    });
  }

  Future<void> pickReceipts() async {
    if (isSaving || isPickingReceipts) return;

    setState(() {
      isPickingReceipts = true;
      errorText = null;
    });

    try {
      final pickedFiles = await PaymentReceiptRepository.pickReceiptFiles();

      if (!mounted || pickedFiles.isEmpty) return;

      setState(() {
        receiptFiles.addAll(pickedFiles);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка выбора чека: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isPickingReceipts = false;
        });
      }
    }
  }

  void removeReceiptFile(int index) {
    if (isSaving) return;

    if (index < 0 || index >= receiptFiles.length) return;

    setState(() {
      receiptFiles.removeAt(index);
    });
  }

  Future<void> savePayment() async {
    final selectedEmployee = findSelectedEmployee();
    final amount = parseAmount();

    if (selectedObjectName == null || selectedObjectName!.trim().isEmpty) {
      setState(() {
        errorText = 'Сначала выберите объект';
      });
      return;
    }

    if (selectedEmployee == null || selectedEmployee.id == null) {
      setState(() {
        errorText = 'Выберите сотрудника';
      });
      return;
    }

    if (amount == null || amount <= 0) {
      setState(() {
        errorText = 'Введите сумму выплаты';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await PaymentRepository.addPayment(
        employeeId: selectedEmployee.id!,
        periodYear: settlementMonth.year,
        periodMonth: settlementMonth.month,
        paymentDate: paymentDate,
        amount: amount,
        paymentType: selectedPaymentType,
        comment: commentController.text.trim(),
        receiptFiles: receiptFiles,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка сохранения выплаты: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorText ?? 'Ошибка загрузки сотрудников',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppAdaptivePalette.danger),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loadEmployees,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return const Center(child: Text('Нет сотрудников для выплаты'));
  }

  Widget buildReceiptSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Чеки',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            receiptFiles.isEmpty
                ? 'Можно прикрепить фото или PDF чека.'
                : 'Прикреплено: ${receiptFiles.length}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (receiptFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...receiptFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${file.originalName} • ${PaymentReceiptRepository.formatFileSize(file.sizeBytes)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Убрать чек',
                      onPressed: isSaving
                          ? null
                          : () {
                              removeReceiptFile(index);
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isSaving || isPickingReceipts ? null : pickReceipts,
              icon: isPickingReceipts
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              label: Text(
                isPickingReceipts
                    ? 'Выбираем...'
                    : receiptFiles.isEmpty
                    ? 'Добавить чек'
                    : 'Добавить ещё чек',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (isLoadingEmployees) {
      body = buildLoadingState();
    } else if (employees.isEmpty && errorText != null) {
      body = buildErrorState();
    } else if (employees.isEmpty) {
      body = buildEmptyState();
    } else {
      final availableEmployees = employeesForSelectedObject();
      body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppAdaptivePalette.surfaceSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppAdaptivePalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Расчётный период',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'За какой месяц относится эта выплата',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : pickSettlementPeriod,
                    icon: const Icon(Icons.event_note_outlined),
                    label: Text('За период: $settlementPeriodTitle'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            key: const ValueKey('payment-object-field'),
            initialValue: selectedObjectName,
            items: [
              const DropdownMenuItem<String>(
                value: allObjectsScopeValue,
                child: Text('Все объекты'),
              ),
              ...objectNames.map((objectName) {
                return DropdownMenuItem<String>(
                  value: objectName,
                  child: Text(objectName),
                );
              }),
            ],
            onChanged: isSaving
                ? null
                : (objectName) {
                    setState(() {
                      selectedObjectName = objectName;
                      selectedEmployeeId = null;
                    });
                    employeeSearchController.clear();
                  },
            decoration: const InputDecoration(
              labelText: 'Объект',
              hintText: 'Сначала выберите объект',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              return RawAutocomplete<Employee>(
                textEditingController: employeeSearchController,
                focusNode: employeeSearchFocusNode,
                displayStringForOption: (employee) => employee.name,
                optionsBuilder: (value) {
                  if (selectedObjectName == null) return const <Employee>[];
                  return searchPaymentEmployees(
                    employees: availableEmployees,
                    query: value.text,
                  );
                },
                onSelected: (employee) {
                  setState(() => selectedEmployeeId = employee.id);
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        key: ValueKey(
                          'payment-employee-${selectedObjectName ?? 'none'}',
                        ),
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !isSaving && selectedObjectName != null,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: AppInputFormatters.sentences,
                        onChanged: (value) {
                          final selected = findSelectedEmployee();
                          if (selected != null &&
                              value.trim() != selected.name.trim()) {
                            setState(() => selectedEmployeeId = null);
                          }
                        },
                        onSubmitted: (_) => onFieldSubmitted(),
                        decoration: InputDecoration(
                          labelText: 'Сотрудник',
                          hintText: selectedObjectName == null
                              ? 'Сначала выберите объект'
                              : availableEmployees.isEmpty
                              ? 'На объекте нет сотрудников'
                              : 'Начните вводить ФИО',
                          suffixIcon: const Icon(Icons.search_rounded),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  final items = options.toList(growable: false);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final employee = items[index];
                              final object = employee.objectName.trim();
                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(employee.name),
                                subtitle: isAllObjectsScope(
                                          selectedObjectName,
                                        ) &&
                                        object.isNotEmpty
                                    ? Text(object)
                                    : null,
                                onTap: () => onSelected(employee),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: isSaving ? null : pickPaymentDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('Дата выплаты: ${formatDate(paymentDate)}'),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: selectedPaymentType,
            items: paymentTypeLabels.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: isSaving
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      selectedPaymentType = value;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Тип выплаты',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: AppInputFormatters.groupedNumber,
            decoration: const InputDecoration(
              labelText: 'Сумма выплаты',
              hintText: 'Например: 10000',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: AppInputFormatters.sentences,
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText: 'Например: аванс, зарплата, штраф за прогул',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          buildReceiptSection(),

          if (errorText != null) ...[
            const SizedBox(height: 14),
            Text(
              errorText!,
              style: TextStyle(color: AppAdaptivePalette.danger),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isSaving ? null : savePayment,
              icon: const Icon(Icons.save),
              label: Text(isSaving ? 'Сохраняем...' : 'Сохранить выплату'),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Добавить выплату'),
      ),
      body: body,
    );
  }
}
