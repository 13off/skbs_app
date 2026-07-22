import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/developer_constructor_repository.dart';

class DeveloperConstructorScreen extends StatefulWidget {
  const DeveloperConstructorScreen({super.key});

  @override
  State<DeveloperConstructorScreen> createState() =>
      _DeveloperConstructorScreenState();
}

class _DeveloperConstructorScreenState
    extends State<DeveloperConstructorScreen> {
  static const weekdayTitles = <int, String>{
    1: 'Пн',
    2: 'Вт',
    3: 'Ср',
    4: 'Чт',
    5: 'Пт',
    6: 'Сб',
    7: 'Вс',
  };

  bool loading = true;
  bool busy = false;
  String? errorText;
  List<DeveloperReminderRule> reminders = <DeveloperReminderRule>[];
  List<DeveloperCustomSetting> settings = <DeveloperCustomSetting>[];

  @override
  void initState() {
    super.initState();
    load();
  }

  String readableError(Object error) {
    final raw = error.toString();
    final match = RegExp(r'message:\s*([^,}]+)').firstMatch(raw);
    return match?.group(1)?.trim() ??
        raw.replaceFirst('PostgrestException(', '').replaceAll(')', '');
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final data = await DeveloperConstructorRepository.fetch();
      if (!mounted) return;
      setState(() {
        reminders = data.reminders;
        settings = data.settings;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Не удалось загрузить конструктор: ${readableError(error)}';
      });
    }
  }

  Future<void> guarded(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      errorText = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => errorText = readableError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String scheduleText(DeveloperReminderRule rule) {
    if (rule.scheduleType == 'once') {
      final value = rule.runOnceAt;
      if (value == null) return 'Один раз · дата не выбрана';
      return 'Один раз · ${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} · ${formatTime(TimeOfDay.fromDateTime(value))}';
    }
    final days = rule.weekdays.toList()..sort();
    final dayText = days.length == 7
        ? 'Каждый день'
        : days.map((day) => weekdayTitles[day] ?? '$day').join(', ');
    return '$dayText · ${rule.localTime} · ${rule.timezone}';
  }

  String recipientsText(DeveloperReminderRule rule) {
    final roles = rule.recipientRoles.toList()..sort();
    return roles
        .map((role) => DeveloperConstructorRepository.roleTitles[role] ?? role)
        .join(', ');
  }

  Future<void> editReminder([DeveloperReminderRule? source]) async {
    final edited = await showReminderEditor(
      source ?? DeveloperReminderRule.empty(),
    );
    if (edited == null) return;
    await guarded(() async {
      await DeveloperConstructorRepository.saveReminder(edited);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Напоминание сохранено')),
        );
      }
    });
  }

  Future<void> removeReminder(DeveloperReminderRule rule) async {
    if (rule.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: Text('«${rule.name}» будет удалено из планировщика.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await guarded(() async {
      await DeveloperConstructorRepository.deleteReminder(rule.id);
      await load();
    });
  }

  Future<void> testReminder(DeveloperReminderRule rule) async {
    if (rule.id.isEmpty) return;
    await guarded(() async {
      final count = await DeveloperConstructorRepository.testReminder(rule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Проверочное уведомление создано'
                : 'Правило проверено, новых уведомлений нет',
          ),
        ),
      );
    });
  }

  Future<void> toggleReminder(
    DeveloperReminderRule rule,
    bool enabled,
  ) async {
    await guarded(() async {
      await DeveloperConstructorRepository.saveReminder(
        rule.copyWith(enabled: enabled),
      );
      await load();
    });
  }

  Future<void> editSetting([DeveloperCustomSetting? source]) async {
    final edited = await showSettingEditor(
      source ?? DeveloperCustomSetting.empty(),
    );
    if (edited == null) return;
    await guarded(() async {
      await DeveloperConstructorRepository.saveSetting(edited);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Системный параметр сохранён')),
        );
      }
    });
  }

  Future<void> removeSetting(DeveloperCustomSetting setting) async {
    if (setting.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить параметр?'),
        content: Text('Ключ «${setting.key}» перестанет быть доступен системе.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await guarded(() async {
      await DeveloperConstructorRepository.deleteSetting(setting.id);
      await load();
    });
  }

  Future<void> toggleSetting(
    DeveloperCustomSetting setting,
    bool enabled,
  ) async {
    await guarded(() async {
      await DeveloperConstructorRepository.saveSetting(
        setting.copyWith(enabled: enabled),
      );
      await load();
    });
  }

  Future<DeveloperReminderRule?> showReminderEditor(
    DeveloperReminderRule initial,
  ) async {
    var draft = initial;
    final nameController = TextEditingController(text: initial.name);
    final bodyController = TextEditingController(text: initial.body);
    final objectController = TextEditingController(text: initial.objectName);
    final result = await showDialog<DeveloperReminderRule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: parseTime(draft.localTime),
              helpText: 'Время напоминания',
            );
            if (picked == null) return;
            setDialogState(
              () => draft = draft.copyWith(localTime: formatTime(picked)),
            );
          }

          Future<void> pickOnce() async {
            final now = DateTime.now();
            final current = draft.runOnceAt ?? now.add(const Duration(hours: 1));
            final date = await showDatePicker(
              context: context,
              initialDate: current,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 3),
              helpText: 'Дата отправки',
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(current),
              helpText: 'Время отправки',
            );
            if (time == null) return;
            setDialogState(
              () => draft = draft.copyWith(
                runOnceAt: DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                ),
              ),
            );
          }

          return AlertDialog(
            title: Text(initial.id.isEmpty ? 'Новое напоминание' : 'Настройка напоминания'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Текст уведомления',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: draft.scheduleType,
                      decoration: const InputDecoration(labelText: 'Расписание'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Каждый выбранный день')),
                        DropdownMenuItem(value: 'weekly', child: Text('По выбранным дням недели')),
                        DropdownMenuItem(value: 'once', child: Text('Один раз')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(
                          () => draft = draft.copyWith(
                            scheduleType: value,
                            clearRunOnceAt: value != 'once',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (draft.scheduleType == 'once')
                      OutlinedButton.icon(
                        onPressed: pickOnce,
                        icon: const Icon(Icons.event_rounded),
                        label: Text(scheduleText(draft)),
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: pickTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text('Время: ${draft.localTime}'),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: weekdayTitles.entries.map((entry) {
                          final selected = draft.weekdays.contains(entry.key);
                          return FilterChip(
                            selected: selected,
                            label: Text(entry.value),
                            onSelected: (value) {
                              final next = Set<int>.from(draft.weekdays);
                              value ? next.add(entry.key) : next.remove(entry.key);
                              setDialogState(
                                () => draft = draft.copyWith(weekdays: next),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text('Получатели', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: DeveloperConstructorRepository.roleTitles.entries.map((entry) {
                        final selected = draft.recipientRoles.contains(entry.key);
                        return FilterChip(
                          selected: selected,
                          label: Text(entry.value),
                          onSelected: (value) {
                            final next = Set<String>.from(draft.recipientRoles);
                            value ? next.add(entry.key) : next.remove(entry.key);
                            setDialogState(
                              () => draft = draft.copyWith(recipientRoles: next),
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: objectController,
                      decoration: const InputDecoration(
                        labelText: 'Объект — необязательно',
                        hintText: 'Например, Чона',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: draft.priority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Низкий')),
                        DropdownMenuItem(value: 'normal', child: Text('Обычный')),
                        DropdownMenuItem(value: 'high', child: Text('Высокий')),
                        DropdownMenuItem(value: 'critical', child: Text('Критический')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => draft = draft.copyWith(priority: value));
                        }
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.inAppEnabled,
                      title: const Text('Колокольчик'),
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(inAppEnabled: value),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: draft.pushEnabled,
                      title: const Text('Push'),
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(pushEnabled: value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty || draft.recipientRoles.isEmpty ||
                      (draft.scheduleType != 'once' && draft.weekdays.isEmpty) ||
                      (!draft.inAppEnabled && !draft.pushEnabled) ||
                      (draft.scheduleType == 'once' && draft.runOnceAt == null)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Заполни название, расписание, получателей и канал доставки')),
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    draft.copyWith(
                      name: name,
                      body: bodyController.text,
                      objectName: objectController.text,
                    ),
                  );
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    bodyController.dispose();
    objectController.dispose();
    return result;
  }

  Future<DeveloperCustomSetting?> showSettingEditor(
    DeveloperCustomSetting initial,
  ) async {
    var draft = initial;
    final keyController = TextEditingController(text: initial.key);
    final nameController = TextEditingController(text: initial.name);
    final descriptionController = TextEditingController(text: initial.description);
    final categoryController = TextEditingController(text: initial.category);
    final valueController = TextEditingController(
      text: initial.valueType == 'json'
          ? const JsonEncoder.withIndent('  ').convert(initial.value)
          : initial.value?.toString() ?? '',
    );
    final result = await showDialog<DeveloperCustomSetting>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(initial.id.isEmpty ? 'Новый системный параметр' : 'Системный параметр'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: keyController,
                    enabled: initial.id.isEmpty,
                    decoration: const InputDecoration(
                      labelText: 'Системный ключ',
                      hintText: 'tasks.default_deadline',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Раздел'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: draft.valueType,
                    decoration: const InputDecoration(labelText: 'Тип значения'),
                    items: const [
                      DropdownMenuItem(value: 'boolean', child: Text('Переключатель')),
                      DropdownMenuItem(value: 'text', child: Text('Текст')),
                      DropdownMenuItem(value: 'number', child: Text('Число')),
                      DropdownMenuItem(value: 'time', child: Text('Время')),
                      DropdownMenuItem(value: 'json', child: Text('JSON / структура')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => draft = draft.copyWith(valueType: value));
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (draft.valueType == 'boolean')
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Значение'),
                      value: draft.value == true,
                      onChanged: (value) => setDialogState(
                        () => draft = draft.copyWith(value: value),
                      ),
                    )
                  else
                    TextField(
                      controller: valueController,
                      minLines: draft.valueType == 'json' ? 3 : 1,
                      maxLines: draft.valueType == 'json' ? 8 : 2,
                      decoration: const InputDecoration(labelText: 'Значение'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final key = keyController.text.trim().toLowerCase();
                final name = nameController.text.trim();
                if (!RegExp(r'^[a-z][a-z0-9_.-]{1,79}$').hasMatch(key) || name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Проверь название и системный ключ')),
                  );
                  return;
                }
                dynamic value = draft.value;
                try {
                  if (draft.valueType == 'number') {
                    value = num.parse(valueController.text.trim());
                  } else if (draft.valueType == 'json') {
                    value = jsonDecode(valueController.text.trim());
                  } else if (draft.valueType != 'boolean') {
                    value = valueController.text;
                  }
                } catch (_) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Значение не соответствует выбранному типу')),
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  draft.copyWith(
                    key: key,
                    name: name,
                    description: descriptionController.text,
                    category: categoryController.text.trim().isEmpty
                        ? 'Общие'
                        : categoryController.text.trim(),
                    value: value,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    keyController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    valueController.dispose();
    return result;
  }

  Widget reminderCard(DeveloperReminderRule rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: rule.enabled,
              onChanged: busy ? null : (value) => toggleReminder(rule, value),
              title: Text(rule.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              subtitle: Text(rule.body.isEmpty ? 'Без дополнительного текста' : rule.body),
            ),
            Text(scheduleText(rule), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Получатели: ${recipientsText(rule)}', style: const TextStyle(color: Color(0xFF6B7075))),
            if (rule.objectName.isNotEmpty)
              Text('Объект: ${rule.objectName}', style: const TextStyle(color: Color(0xFF6B7075))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => editReminder(rule),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Изменить'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => testReminder(rule),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Проверить'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => removeReminder(rule),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget settingCard(DeveloperCustomSetting setting) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(setting.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(setting.key, style: const TextStyle(color: Color(0xFF6B7075), fontFamily: 'monospace')),
                  if (setting.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(setting.description),
                  ],
                  const SizedBox(height: 5),
                  Text('${setting.category} · ${setting.valueType} · ${setting.value}', style: const TextStyle(color: Color(0xFF6B7075))),
                ],
              ),
            ),
            Switch.adaptive(
              value: setting.enabled,
              onChanged: busy ? null : (value) => toggleSetting(setting, value),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') editSetting(setting);
                if (value == 'delete') removeSetting(setting);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionHeader(String title, String subtitle, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7075), height: 1.35)),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Добавить',
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Конструктор',
      showBackButton: true,
      subtitle: 'Создание напоминаний и системных параметров без правок в коде',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || busy ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorText != null) ...[
                  PremiumWorkCard(
                    radius: 22,
                    padding: const EdgeInsets.all(15),
                    child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 10),
                ],
                sectionHeader(
                  'Напоминания',
                  'Название, текст, время, дни, объект, получатели, колокольчик и push.',
                  editReminder,
                ),
                if (reminders.isEmpty)
                  const PremiumWorkCard(
                    radius: 22,
                    child: Text('Пользовательских напоминаний пока нет.'),
                  )
                else
                  ...reminders.map(reminderCard),
                sectionHeader(
                  'Системные параметры',
                  'Произвольные переключатели, числа, время, текст и JSON для новых функций.',
                  editSetting,
                ),
                if (settings.isEmpty)
                  const PremiumWorkCard(
                    radius: 22,
                    child: Text('Пользовательских системных параметров пока нет.'),
                  )
                else
                  ...settings.map(settingCard),
              ],
            ),
    );
  }
}
