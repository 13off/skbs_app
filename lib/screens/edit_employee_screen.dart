import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/employee_repository.dart';
import '../models/employee.dart';

class EditEmployeeScreen extends StatefulWidget {
  final Employee employee;

  const EditEmployeeScreen({super.key, required this.employee});

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final formKey = GlobalKey<FormState>();

  final fioController = TextEditingController();
  final positionController = TextEditingController();
  final phoneController = TextEditingController();
  final monthlySalaryController = TextEditingController();
  final commentController = TextEditingController();

  late String selectedObjectName;

  bool isSaving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    fioController.text = widget.employee.name;
    positionController.text = widget.employee.position;
    phoneController.text = formatRussianPhone(widget.employee.phone);
    monthlySalaryController.text = widget.employee.monthlySalary > 0
        ? widget.employee.monthlySalary.toString()
        : '';
    commentController.text = widget.employee.comment;

    final objectName = widget.employee.objectName.trim();
    selectedObjectName = objectName.isEmpty
        ? EmployeeRepository.baseObjects.first
        : objectName;
  }

  @override
  void dispose() {
    fioController.dispose();
    positionController.dispose();
    phoneController.dispose();
    monthlySalaryController.dispose();
    commentController.dispose();
    super.dispose();
  }

  List<String> get objectItems {
    final objects = <String>{
      ...EmployeeRepository.baseObjects,
      selectedObjectName,
    }.toList();

    objects.sort();

    return objects;
  }

  int parseMonthlySalary() {
    final cleanText = monthlySalaryController.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    final value = double.tryParse(cleanText);

    if (value == null) return widget.employee.monthlySalary;

    return value.round();
  }

  Future<void> saveEmployee() async {
    final employeeId = widget.employee.id;

    if (employeeId == null || employeeId.isEmpty) {
      setState(() {
        errorText = 'Не найден ID сотрудника. Нельзя сохранить изменения.';
      });
      return;
    }

    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    setState(() {
      isSaving = true;
      errorText = null;
    });

    final monthlySalary = parseMonthlySalary();

    try {
      await EmployeeRepository.updateEmployee(
        employeeId: employeeId,
        fio: fioController.text,
        position: positionController.text,
        phone: cleanPhoneForSave(phoneController.text),
        objectName: selectedObjectName,
        monthlySalary: monthlySalary,
        comment: commentController.text,
      );

      if (!mounted) return;

      final updatedEmployee = Employee(
        fioController.text.trim(),
        positionController.text.trim(),
        widget.employee.status,
        id: employeeId,
        phone: cleanPhoneForSave(phoneController.text),
        objectName: selectedObjectName,
        monthlySalary: monthlySalary,
        isActive: widget.employee.isActive,
        comment: commentController.text.trim(),
      );

      Navigator.pop(context, updatedEmployee);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка сохранения сотрудника: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildSection({required String title, required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget buildObjectSelector() {
    return DropdownButtonFormField<String>(
      initialValue: selectedObjectName,
      decoration: const InputDecoration(
        labelText: 'Объект',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.apartment_outlined),
      ),
      items: objectItems.map((objectName) {
        return DropdownMenuItem<String>(
          value: objectName,
          child: Text(objectName),
        );
      }).toList(),
      onChanged: isSaving
          ? null
          : (value) {
              if (value == null) return;

              setState(() {
                selectedObjectName = value;
              });
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Редактировать сотрудника'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            buildSection(
              title: 'Основные данные',
              children: [
                TextFormField(
                  controller: fioController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'ФИО',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Введите ФИО';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: positionController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Должность',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Введите должность';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+7 (999) 999-99-99',
                  ),
                  inputFormatters: [RussianPhoneTextInputFormatter()],
                  validator: validateRussianPhone,
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildSection(
              title: 'Работа',
              children: [
                buildObjectSelector(),
                const SizedBox(height: 14),
                TextFormField(
                  controller: monthlySalaryController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Зарплата в месяц, ₽',
                    hintText: 'Например: 180000',
                    helperText: 'Начисляется за расчётный месяц независимо от табеля',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim().replaceAll(' ', '') ?? '';

                    if (text.isEmpty) {
                      return 'Введите зарплату за месяц';
                    }

                    final number = double.tryParse(text.replaceAll(',', '.'));

                    if (number == null || number <= 0) {
                      return 'Введите корректную зарплату';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: commentController,
                  enabled: !isSaving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    hintText: 'Необязательно',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
            if (errorText != null) ...[
              const SizedBox(height: 14),
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: isSaving ? null : saveEmployee,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isSaving ? 'Сохраняем...' : 'Сохранить изменения'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String onlyDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String cleanPhoneForSave(String value) {
  final digits = onlyDigits(value);

  if (digits.length <= 1) {
    return '';
  }

  if (digits.length == 11 && digits.startsWith('8')) {
    return formatRussianPhone('7${digits.substring(1)}');
  }

  if (digits.length == 10) {
    return formatRussianPhone('7$digits');
  }

  return formatRussianPhone(digits);
}

String formatRussianPhone(String value) {
  var digits = onlyDigits(value);

  if (digits.isEmpty) {
    return '+7 ';
  }

  if (digits.startsWith('8')) {
    digits = '7${digits.substring(1)}';
  }

  if (!digits.startsWith('7')) {
    digits = '7$digits';
  }

  if (digits.length > 11) {
    digits = digits.substring(0, 11);
  }

  final local = digits.length > 1 ? digits.substring(1) : '';
  final buffer = StringBuffer('+7');

  if (local.isEmpty) {
    buffer.write(' ');
    return buffer.toString();
  }

  buffer.write(' ');

  if (local.isNotEmpty) {
    final end = local.length >= 3 ? 3 : local.length;
    buffer.write('(');
    buffer.write(local.substring(0, end));

    if (local.length >= 3) {
      buffer.write(')');
    }
  }

  if (local.length > 3) {
    final end = local.length >= 6 ? 6 : local.length;
    buffer.write(' ');
    buffer.write(local.substring(3, end));
  }

  if (local.length > 6) {
    final end = local.length >= 8 ? 8 : local.length;
    buffer.write('-');
    buffer.write(local.substring(6, end));
  }

  if (local.length > 8) {
    final end = local.length >= 10 ? 10 : local.length;
    buffer.write('-');
    buffer.write(local.substring(8, end));
  }

  return buffer.toString();
}

String? validateRussianPhone(String? value) {
  final digits = onlyDigits(value ?? '');

  if (digits.length <= 1) {
    return null;
  }

  if (digits.length != 11) {
    return 'Телефон должен быть в формате +7 (999) 999-99-99';
  }

  if (!digits.startsWith('7')) {
    return 'Телефон должен начинаться с +7';
  }

  return null;
}

class RussianPhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = formatRussianPhone(newValue.text);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
