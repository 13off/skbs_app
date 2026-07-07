import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_repository.dart';
import '../data/payment_repository.dart';
import '../models/employee.dart';

class AddPaymentScreen extends StatefulWidget {
  final int periodYear;
  final int periodMonth;
  final String periodTitle;
  final String? initialEmployeeId;

  const AddPaymentScreen({
    super.key,
    required this.periodYear,
    required this.periodMonth,
    required this.periodTitle,
    this.initialEmployeeId,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final amountController = TextEditingController();
  final commentController = TextEditingController();

  String? selectedEmployeeId;
  DateTime paymentDate = DateTime.now();

  String selectedPaymentType = 'advance';

  final Map<String, String> paymentTypeLabels = const {
    'advance': 'Аванс',
    'salary': 'Заработная плата',
    'fine': 'Штраф',
  };

  List<Employee> employees = [];

  bool isLoadingEmployees = true;
  bool isSaving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

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
      final loadedEmployees = await EmployeeRepository.fetchEmployees(
        includeFired: true,
      );

      final employeesWithId = loadedEmployees
          .where((employee) => employee.id != null)
          .toList();

      if (!mounted) return;

      final selectedIdExists = employeesWithId.any(
        (employee) => employee.id == selectedEmployeeId,
      );

      setState(() {
        employees = employeesWithId;

        if (employeesWithId.isEmpty) {
          selectedEmployeeId = null;
        } else if (selectedEmployeeId == null || !selectedIdExists) {
          selectedEmployeeId = employeesWithId.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки сотрудников: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmployees = false;
        });
      }
    }
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

  Future<void> savePayment() async {
    final selectedEmployee = findSelectedEmployee();
    final amount = parseAmount();

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
            value: selectedEmployeeId,
            items: employees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee.id,
                child: Text(employee.name),
              );
            }).toList(),
            onChanged: isSaving
                ? null
                : (employeeId) {
                    setState(() {
                      selectedEmployeeId = employeeId;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Сотрудник',
              border: OutlineInputBorder(),
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
            value: selectedPaymentType,
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
      appBar: AppBar(title: const Text('Добавить выплату')),
      body: body,
    );
  }
}
