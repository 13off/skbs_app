import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/employee_repository.dart';

class AddEmployeeScreen extends StatefulWidget {
  final String? initialObjectName;

  const AddEmployeeScreen({super.key, this.initialObjectName});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final formKey = GlobalKey<FormState>();

  final fioController = TextEditingController();
  final positionController = TextEditingController();
  final phoneController = TextEditingController(text: '+7 ');
  final dailyRateController = TextEditingController(text: '6000');
  final commentController = TextEditingController();

  late String selectedObjectName;

  bool isSaving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    final initialObject = widget.initialObjectName?.trim();

    if (initialObject != null && initialObject.isNotEmpty) {
      selectedObjectName = initialObject;
    } else {
      selectedObjectName = EmployeeRepository.baseObjects.first;
    }
  }

  @override
  void dispose() {
    fioController.dispose();
    positionController.dispose();
    phoneController.dispose();
    dailyRateController.dispose();
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

  int parseDailyRate() {
    final cleanText = dailyRateController.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    final value = double.tryParse(cleanText);

    if (value == null) return 6000;

    return value.round();
  }

  Future<void> saveEmployee() async {
    final isValid = formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await EmployeeRepository.addEmployee(
        fio: fioController.text,
        position: positionController.text,
        phone: cleanPhoneForSave(phoneController.text),
        objectName: selectedObjectName,
        dailyRate: parseDailyRate(),
        comment: commentController.text,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка добавления сотрудника: $e';
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget buildObjectSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Объект',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedObjectName,
            decoration: const InputDecoration(
              labelText: 'Выберите объект',
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
          ),
          const SizedBox(height: 8),
          Text(
            'Сотрудник будет добавлен в выбранный объект.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить сотрудника')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            buildObjectSelector(),

            const SizedBox(height: 16),

            buildSection(
              title: 'Основные данные',
              children: [
                TextFormField(
                  controller: fioController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'ФИО',
                    hintText: 'Например: Иванов Иван Иванович',
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
                    hintText: 'Например: Бетонщик',
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
                    hintText: '+7 (999) 999-99-99',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
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
                TextFormField(
                  controller: dailyRateController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ставка за смену',
                    hintText: 'Например: 6000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim().replaceAll(' ', '') ?? '';

                    if (text.isEmpty) {
                      return 'Введите ставку';
                    }

                    final number = double.tryParse(text.replaceAll(',', '.'));

                    if (number == null || number <= 0) {
                      return 'Введите корректную ставку';
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
              Text(errorText!, style: const TextStyle(color: Colors.red)),
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
                label: Text(isSaving ? 'Сохраняем...' : 'Сохранить сотрудника'),
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
