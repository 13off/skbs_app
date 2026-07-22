import 'package:flutter/material.dart';

import '../../developer/data/developer_constructor_repository.dart';
import '../models/ai_assistant_result.dart';

class AiReminderDraftScreen extends StatefulWidget {
  final AiAssistantAction action;

  const AiReminderDraftScreen({super.key, required this.action});

  @override
  State<AiReminderDraftScreen> createState() => _AiReminderDraftScreenState();
}

class _AiReminderDraftScreenState extends State<AiReminderDraftScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController objectController = TextEditingController();

  late DateTime runOnceAt;
  late Set<String> recipientRoles;
  bool inAppEnabled = true;
  bool pushEnabled = true;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.action.text('title');
    bodyController.text = widget.action.text('message');
    objectController.text = widget.action.text('object_name');
    recipientRoles = widget.action.stringList('recipient_roles').toSet();
    if (recipientRoles.isEmpty) recipientRoles = <String>{'admin'};

    final date = widget.action.date('date') ?? DateTime.now();
    final timeParts = widget.action.text('local_time').split(':');
    runOnceAt = DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(timeParts.first) ?? 9,
      timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    bodyController.dispose();
    objectController.dispose();
    super.dispose();
  }

  Future<void> pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: runOnceAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
      helpText: 'Дата напоминания',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(runOnceAt),
      helpText: 'Время напоминания',
    );
    if (time == null) return;
    setState(() {
      runOnceAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    final body = bodyController.text.trim();
    if (name.isEmpty || body.isEmpty) {
      setState(() => errorText = 'Заполни название и текст напоминания');
      return;
    }
    if (recipientRoles.isEmpty) {
      setState(() => errorText = 'Выбери хотя бы одну роль получателя');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final saved = await DeveloperConstructorRepository.saveReminder(
        DeveloperReminderRule(
          name: name,
          body: body,
          scheduleType: 'once',
          runOnceAt: runOnceAt,
          localTime:
              '${runOnceAt.hour.toString().padLeft(2, '0')}:${runOnceAt.minute.toString().padLeft(2, '0')}',
          recipientRoles: recipientRoles,
          inAppEnabled: inAppEnabled,
          pushEnabled: pushEnabled,
          objectName: objectController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, saved.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = 'Не удалось сохранить напоминание: $error';
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String dateTimeText() {
    return '${runOnceAt.day.toString().padLeft(2, '0')}.'
        '${runOnceAt.month.toString().padLeft(2, '0')}.'
        '${runOnceAt.year} · '
        '${runOnceAt.hour.toString().padLeft(2, '0')}:'
        '${runOnceAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Новое напоминание'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Проверь настройки перед сохранением',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Напоминание будет создано только после кнопки «Сохранить напоминание».',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: bodyController,
            enabled: !saving,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Текст уведомления',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: objectController,
            enabled: !saving,
            decoration: const InputDecoration(
              labelText: 'Объект',
              hintText: 'Пусто — все объекты',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: saving ? null : pickDateTime,
            icon: const Icon(Icons.event_outlined),
            label: Text(dateTimeText()),
          ),
          const SizedBox(height: 16),
          const Text(
            'Получатели',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DeveloperConstructorRepository.roleTitles.entries.map((
              entry,
            ) {
              final selected = recipientRoles.contains(entry.key);
              return FilterChip(
                selected: selected,
                label: Text(entry.value),
                onSelected: saving
                    ? null
                    : (value) {
                        setState(() {
                          if (value) {
                            recipientRoles.add(entry.key);
                          } else {
                            recipientRoles.remove(entry.key);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            value: inAppEnabled,
            onChanged: saving
                ? null
                : (value) => setState(() => inAppEnabled = value),
            title: const Text('Показывать в колокольчике'),
          ),
          SwitchListTile(
            value: pushEnabled,
            onChanged: saving
                ? null
                : (value) => setState(() => pushEnabled = value),
            title: const Text('Отправлять push'),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Сохраняем...' : 'Сохранить напоминание'),
          ),
        ],
      ),
    );
  }
}
