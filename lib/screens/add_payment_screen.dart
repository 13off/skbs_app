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

  bool isSaving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    selectedEmployeeId = widget.initialEmployeeId;
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

  Employee? findSelectedEmployee(List<Employee> employees) {
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

  Future<void> savePayment(List<Employee> employees) async {
    final selectedEmployee = findSelectedEmployee(employees);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить выплату')),
      body: StreamBuilder<List<Employee>>(
        stream: EmployeeRepository.watchEmployees(includeFired: true),
        builder: (context, snapshot) {
          final employees = snapshot.data ?? [];
          final employeesWithId = employees
              .where((employee) => employee.id != null)
              .toList();

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки сотрудников: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (employeesWithId.isEmpty) {
            return const Center(child: Text('Нет сотрудников для выплаты'));
          }

          final selectedIdExists = employeesWithId.any(
            (employee) => employee.id == selectedEmployeeId,
          );

          if (selectedEmployeeId == null || !selectedIdExists) {
            selectedEmployeeId = employeesWithId.first.id;
          }

          return ListView(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.periodTitle,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                value: selectedEmployeeId,
                items: employeesWithId.map((employee) {
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
                  onPressed: isSaving
                      ? null
                      : () {
                          savePayment(employeesWithId);
                        },
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'Сохраняем...' : 'Сохранить выплату'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
