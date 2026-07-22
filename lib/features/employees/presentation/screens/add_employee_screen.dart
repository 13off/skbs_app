import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/employee_repository.dart';

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

  String selectedObjectName = '';
  late Future<List<String>> objectNamesFuture;

  bool isSaving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();

    selectedObjectName = widget.initialObjectName?.trim() ?? '';
    objectNamesFuture = loadObjectNames();
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

  Future<List<String>> loadObjectNames({bool forceRefresh = false}) async {
    final loaded = await EmployeeRepository.fetchObjectNames(
      forceRefresh: forceRefresh,
    );
    final objects =
        loaded
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final initialObject = widget.initialObjectName?.trim();
    if (initialObject != null &&
        initialObject.isNotEmpty &&
        !objects.contains(initialObject)) {
      objects.add(initialObject);
      objects.sort();
    }

    if (mounted && selectedObjectName.isEmpty && objects.isNotEmpty) {
      setState(() {
        selectedObjectName = objects.first;
      });
    }

    return objects;
  }

  void retryObjects() {
    setState(() {
      objectNamesFuture = loadObjectNames(forceRefresh: true);
    });
  }

  int parseDailyRate() {
    final cleanText = dailyRateController.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    final value = double.tryParse(cleanText);

    return value?.round() ?? 6000;
  }

  Future<void> saveEmployee() async {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid || isSaving) return;

    final objectName = selectedObjectName.trim();
    if (objectName.isEmpty) {
      setState(() {
        errorText = 'Сначала выберите объект';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await EmployeeRepository.addEmployee(
        fio: fioController.text,
        position: positionController.text,
        phone: cleanPhoneForSave(phoneController.text),
        objectName: objectName,
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
    return FutureBuilder<List<String>>(
      future: objectNamesFuture,
      builder: (context, snapshot) {
        final objects = snapshot.data ?? const <String>[];
        final selectedValue = objects.contains(selectedObjectName)
            ? selectedObjectName
            : null;
        final isLoadingObjects =
            snapshot.connectionState == ConnectionState.waiting;

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
              const Text(
                'Объект',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (isLoadingObjects)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Загружаем список объектов...'),
                    ],
                  ),
                )
              else if (snapshot.hasError)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Не удалось загрузить объекты',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: retryObjects,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Повторить'),
                    ),
                  ],
                )
              else if (objects.isEmpty)
                const Text(
                  'Сначала создайте объект на главной странице',
                  style: TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('employee_object_$selectedValue'),
                  initialValue: selectedValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Выберите объект',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  items: objects.map((objectName) {
                    return DropdownMenuItem<String>(
                      value: objectName,
                      child: Text(
                        objectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Выберите объект';
                    }

                    return null;
                  },
                ),
              if (!isLoadingObjects &&
                  !snapshot.hasError &&
                  objects.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Сотрудник будет добавлен в выбранный объект.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Добавить сотрудника')),
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
                    if ((value ?? '').trim().isEmpty) return 'Введите ФИО';
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
                    if ((value ?? '').trim().isEmpty) {
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
                    final text = (value ?? '').trim().replaceAll(' ', '');
                    final number = double.tryParse(text.replaceAll(',', '.'));

                    if (text.isEmpty) return 'Введите ставку';
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
                onPressed: isSaving || selectedObjectName.trim().isEmpty
                    ? null
                    : saveEmployee,
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

  if (digits.length <= 1) return '';
  if (digits.length == 11 && digits.startsWith('8')) {
    return formatRussianPhone('7${digits.substring(1)}');
  }
  if (digits.length == 10) return formatRussianPhone('7$digits');

  return formatRussianPhone(digits);
}

String formatRussianPhone(String value) {
  var digits = onlyDigits(value);

  if (digits.isEmpty) return '+7 ';
  if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
  if (!digits.startsWith('7')) digits = '7$digits';
  if (digits.length > 11) digits = digits.substring(0, 11);

  final local = digits.length > 1 ? digits.substring(1) : '';
  final buffer = StringBuffer('+7 ');

  if (local.isEmpty) return buffer.toString();

  final firstEnd = local.length >= 3 ? 3 : local.length;
  buffer
    ..write('(')
    ..write(local.substring(0, firstEnd));

  if (local.length >= 3) buffer.write(')');

  if (local.length > 3) {
    final end = local.length >= 6 ? 6 : local.length;
    buffer
      ..write(' ')
      ..write(local.substring(3, end));
  }

  if (local.length > 6) {
    final end = local.length >= 8 ? 8 : local.length;
    buffer
      ..write('-')
      ..write(local.substring(6, end));
  }

  if (local.length > 8) {
    final end = local.length >= 10 ? 10 : local.length;
    buffer
      ..write('-')
      ..write(local.substring(8, end));
  }

  return buffer.toString();
}

String? validateRussianPhone(String? value) {
  final digits = onlyDigits(value ?? '');

  if (digits.length <= 1) return null;
  if (digits.length != 11) {
    return 'Телефон должен быть в формате +7 (999) 999-99-99';
  }
  if (!digits.startsWith('7')) return 'Телефон должен начинаться с +7';

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
