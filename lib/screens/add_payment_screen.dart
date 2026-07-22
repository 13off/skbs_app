import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/payment_receipt_repository.dart';
import '../data/payment_repository.dart';
import '../models/employee.dart';
import '../widgets/object_employee_scope.dart';

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

  String? selectedObjectName;
  String? selectedEmployeeId;
  DateTime paymentDate = DateTime.now();

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
    super.dispose();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  double? parseAmount() {
    final text = amountController.text.trim().replaceAll(',', '.');

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
        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
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
              style: const TextStyle(color: Colors.red),
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
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
              color: Colors.grey.shade700,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
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
      final employeeFieldValue =
          availableEmployees.any(
            (employee) => employee.id == selectedEmployeeId,
          )
          ? selectedEmployeeId
          : null;

      body = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Период выплаты',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(widget.periodTitle, style: const TextStyle(fontSize: 16)),
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
                  },
            decoration: const InputDecoration(
              labelText: 'Объект',
              hintText: 'Сначала выберите объект',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            key: ValueKey("payment-employee-${selectedObjectName ?? 'none'}"),
            initialValue: employeeFieldValue,
            items: availableEmployees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee.id,
                child: Text(
                  isAllObjectsScope(selectedObjectName) &&
                          employee.objectName.trim().isNotEmpty
                      ? '${employee.name} — ${employee.objectName.trim()}'
                      : employee.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: isSaving || selectedObjectName == null
                ? null
                : (employeeId) {
                    setState(() {
                      selectedEmployeeId = employeeId;
                    });
                  },
            decoration: InputDecoration(
              labelText: 'Сотрудник',
              hintText: selectedObjectName == null
                  ? 'Сначала выберите объект'
                  : availableEmployees.isEmpty
                  ? 'На объекте нет сотрудников'
                  : 'Выберите сотрудника',
              border: const OutlineInputBorder(),
            ),
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
            decoration: const InputDecoration(
              labelText: 'Сумма выплаты',
              hintText: 'Например: 10000',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
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
            Text(errorText!, style: const TextStyle(color: Colors.red)),
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
