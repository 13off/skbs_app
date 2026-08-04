import 'package:flutter/material.dart';

import '../../../data/employee_repository.dart';
import '../../../screens/add_employee_screen.dart';
import '../models/ai_assistant_result.dart';

class AiEmployeeDraftScreen extends StatefulWidget {
  final AiAssistantAction action;

  const AiEmployeeDraftScreen({super.key, required this.action});

  @override
  State<AiEmployeeDraftScreen> createState() => _AiEmployeeDraftScreenState();
}

class _AiEmployeeDraftScreenState extends State<AiEmployeeDraftScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController fioController;
  late final TextEditingController positionController;
  late final TextEditingController phoneController;
  late final TextEditingController dailyRateController;
  late final TextEditingController commentController;
  late String objectName;
  List<String> objectNames = const <String>[];
  bool loadingObjects = true;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    fioController = TextEditingController(text: widget.action.text('fio'));
    positionController = TextEditingController(
      text: widget.action.text('position'),
    );
    final phone = widget.action.text('phone');
    phoneController = TextEditingController(
      text: phone.isEmpty ? '+7 ' : formatRussianPhone(phone),
    );
    final rate = widget.action.number('daily_rate').round();
    dailyRateController = TextEditingController(
      text: rate > 0 ? rate.toString() : '',
    );
    commentController = TextEditingController(
      text: widget.action.text('comment'),
    );
    objectName = widget.action.text('object_name');
    loadObjects();
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

  Future<void> loadObjects() async {
    try {
      final loaded = await EmployeeRepository.fetchObjectNames(
        forceRefresh: true,
      );
      final result =
          loaded
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (objectName.isNotEmpty && !result.contains(objectName)) {
        result.add(objectName);
        result.sort();
      }
      if (!mounted) return;
      setState(() {
        objectNames = result;
        if (objectName.isEmpty && result.isNotEmpty) objectName = result.first;
        loadingObjects = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingObjects = false;
        errorText = 'Не удалось загрузить объекты: $error';
      });
    }
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false) || saving) return;
    if (objectName.trim().isEmpty) {
      setState(() => errorText = 'Выберите объект');
      return;
    }
    final rate = int.tryParse(
      dailyRateController.text.replaceAll(' ', '').trim(),
    );
    if (rate == null || rate <= 0) {
      setState(() => errorText = 'Введите корректную ставку');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final id = await EmployeeRepository.addEmployee(
        fio: fioController.text,
        position: positionController.text,
        phone: cleanPhoneForSave(phoneController.text),
        objectName: objectName,
        dailyRate: rate,
        comment: commentController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, id ?? 'created');
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка добавления сотрудника: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Черновик сотрудника'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Проверь карточку перед сохранением',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Помощник переносит только известные данные. Ставка и объект требуют ручной проверки перед сохранением.',
            ),
            const SizedBox(height: 18),
            if (loadingObjects)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                initialValue: objectNames.contains(objectName)
                    ? objectName
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Объект',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                items: objectNames
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() => objectName = value ?? ''),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Выберите объект' : null,
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: fioController,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'ФИО',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Введите ФИО' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: positionController,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Должность',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Введите должность' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: phoneController,
              enabled: !saving,
              keyboardType: TextInputType.phone,
              inputFormatters: [RussianPhoneTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Телефон',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: validateRussianPhone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: dailyRateController,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ставка за смену',
                helperText:
                    'Обязательное поле: проверь по согласованным условиям',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                final rate = int.tryParse(
                  (value ?? '').replaceAll(' ', '').trim(),
                );
                return rate == null || rate <= 0
                    ? 'Введите согласованную ставку'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: commentController,
              enabled: !saving,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                prefixIcon: Icon(Icons.notes_outlined),
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
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? 'Сохраняем...' : 'Сохранить сотрудника'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
