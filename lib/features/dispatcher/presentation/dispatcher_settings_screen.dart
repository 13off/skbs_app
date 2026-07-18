import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/dispatcher_summary_repository.dart';

class DispatcherSettingsScreen extends StatefulWidget {
  const DispatcherSettingsScreen({super.key});

  @override
  State<DispatcherSettingsScreen> createState() =>
      _DispatcherSettingsScreenState();
}

class _DispatcherSettingsScreenState extends State<DispatcherSettingsScreen> {
  static const weekdayTitles = <int, String>{
    1: 'Пн',
    2: 'Вт',
    3: 'Ср',
    4: 'Чт',
    5: 'Пт',
    6: 'Сб',
    7: 'Вс',
  };

  DispatcherSummarySettings settings = DispatcherSummarySettings.defaults;
  List<DispatcherObjectOption> objects = const <DispatcherObjectOption>[];
  List<DispatcherSummaryRun> runs = const <DispatcherSummaryRun>[];
  bool loading = true;
  bool saving = false;
  bool running = false;
  String? errorText;

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
      final center = await DispatcherSummaryRepository.fetchCenter();
      if (!mounted) return;
      setState(() {
        settings = center.settings;
        objects = center.objects;
        runs = center.runs;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = readableError(error);
      });
    }
  }

  String? validate({bool requireObject = false}) {
    if ((settings.enabled || requireObject) && settings.objectId.isEmpty) {
      return 'Выбери объект, по которому диспетчер будет собирать сводку.';
    }
    if (settings.weekdays.isEmpty || settings.recipientRoles.isEmpty) {
      return 'Выбери хотя бы один день и одного получателя.';
    }
    if (!settings.inAppEnabled && !settings.pushEnabled) {
      return 'Включи колокольчик или push.';
    }
    return null;
  }

  Future<void> save() async {
    if (saving) return;
    final validation = validate();
    if (validation != null) {
      setState(() => errorText = validation);
      return;
    }
    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final saved = await DispatcherSummaryRepository.save(settings);
      if (!mounted) return;
      setState(() => settings = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки ИИ-диспетчера сохранены')),
      );
    } catch (error) {
      if (mounted) setState(() => errorText = readableError(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> runNow() async {
    if (running) return;
    final validation = validate(requireObject: true);
    if (validation != null) {
      setState(() => errorText = validation);
      return;
    }
    setState(() {
      running = true;
      errorText = null;
    });
    try {
      await DispatcherSummaryRepository.save(settings);
      await DispatcherSummaryRepository.runNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сводка по объекту «${settings.objectName}» поставлена в обработку',
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await load();
    } catch (error) {
      if (mounted) setState(() => errorText = readableError(error));
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30,
    );
  }

  String formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: parseTime(settings.localTime),
      helpText: 'Время ежедневной сводки',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (result == null || !mounted) return;
    setState(
      () => settings = settings.copyWith(localTime: formatTime(result)),
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B7075),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget mainCard() {
    final selectedObject = objects.any((item) => item.id == settings.objectId)
        ? settings.objectId
        : null;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.enabled,
            onChanged: saving
                ? null
                : (value) => setState(
                    () => settings = settings.copyWith(enabled: value),
                  ),
            title: const Text(
              'Ежедневная сводка',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              settings.objectName.isEmpty
                  ? 'Сначала выбери объект. Данные всей компании смешиваться не будут.'
                  : 'Оператор проверяет только объект «${settings.objectName}».',
            ),
          ),
          const Divider(height: 24),
          DropdownButtonFormField<String>(
            value: selectedObject,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Объект сводки',
              prefixIcon: Icon(Icons.apartment_rounded),
              helperText: 'Задачи, табель и остальные данные берутся только с этого объекта.',
            ),
            items: objects
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (value) {
                    final selected = objects
                        .where((item) => item.id == value)
                        .firstOrNull;
                    setState(
                      () => settings = settings.copyWith(
                        objectId: value ?? '',
                        objectName: selected?.name ?? '',
                      ),
                    );
                  },
          ),
          if (objects.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Нет активных объектов. Сначала создай или включи объект в платформе руководителя.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ],
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text(
              'Время отправки',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${settings.localTime} · ${DispatcherSummaryRepository.timezoneTitles[settings.timezone] ?? settings.timezone}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: saving ? null : pickTime,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: DispatcherSummaryRepository.timezoneTitles
                    .containsKey(settings.timezone)
                ? settings.timezone
                : 'Europe/Moscow',
            decoration: const InputDecoration(
              labelText: 'Часовой пояс',
              prefixIcon: Icon(Icons.public_rounded),
            ),
            items: DispatcherSummaryRepository.timezoneTitles.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(
                        () => settings = settings.copyWith(timezone: value),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget weekdaysCard() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Дни отправки',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weekdayTitles.entries.map((entry) {
              final selected = settings.weekdays.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: saving
                    ? null
                    : (value) {
                        final next = Set<int>.from(settings.weekdays);
                        value ? next.add(entry.key) : next.remove(entry.key);
                        setState(
                          () => settings = settings.copyWith(weekdays: next),
                        );
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget recipientsCard() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Получатели',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Кому отправляется сводка выбранного объекта.',
            style: TextStyle(color: Color(0xFF6B7075)),
          ),
          const SizedBox(height: 8),
          ...DispatcherSummaryRepository.roleTitles.entries.map((entry) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: settings.recipientRoles.contains(entry.key),
              onChanged: saving
                  ? null
                  : (value) {
                      final next = Set<String>.from(settings.recipientRoles);
                      value == true ? next.add(entry.key) : next.remove(entry.key);
                      setState(
                        () => settings = settings.copyWith(
                          recipientRoles: next,
                        ),
                      );
                    },
              title: Text(
                entry.value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget deliveryCard() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.inAppEnabled,
            onChanged: saving
                ? null
                : (value) => setState(
                    () => settings = settings.copyWith(inAppEnabled: value),
                  ),
            title: const Text(
              'Колокольчик',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Сохранять сводку внутри AppСтрой.'),
          ),
          const Divider(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.pushEnabled,
            onChanged: saving
                ? null
                : (value) => setState(
                    () => settings = settings.copyWith(pushEnabled: value),
                  ),
            title: const Text(
              'Push-уведомление',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Присылать сводку на зарегистрированные устройства.',
            ),
          ),
          const Divider(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.aiCommentary,
            onChanged: saving
                ? null
                : (value) => setState(
                    () => settings = settings.copyWith(aiCommentary: value),
                  ),
            title: const Text(
              'Комментарий ИИ',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'ИИ выделяет риски и предлагает действия только по выбранному объекту.',
            ),
          ),
        ],
      ),
    );
  }

  Widget contentCard() {
    final items = <({String title, String subtitle, bool value, void Function(bool) update})>[
      (
        title: 'Задачи',
        subtitle: 'Выполнено, незакрыто и задачи с проблемами.',
        value: settings.includeTasks,
        update: (value) => settings = settings.copyWith(includeTasks: value),
      ),
      (
        title: 'Табель',
        subtitle: 'Выходы, смены и сотрудники без отметки.',
        value: settings.includeAttendance,
        update: (value) =>
            settings = settings.copyWith(includeAttendance: value),
      ),
      (
        title: 'Сотрудники',
        subtitle: 'Активные и добавленные за день.',
        value: settings.includeEmployees,
        update: (value) =>
            settings = settings.copyWith(includeEmployees: value),
      ),
      (
        title: 'Выплаты',
        subtitle: 'Выплаты сотрудникам выбранного объекта и чеки.',
        value: settings.includePayments,
        update: (value) =>
            settings = settings.copyWith(includePayments: value),
      ),
      (
        title: 'Подбор персонала',
        subtitle: 'Кандидаты, назначенные на выбранный объект.',
        value: settings.includeRecruitment,
        update: (value) =>
            settings = settings.copyWith(includeRecruitment: value),
      ),
      (
        title: 'Юридическое',
        subtitle: 'Вопросы и документы, привязанные к объекту.',
        value: settings.includeLegal,
        update: (value) => settings = settings.copyWith(includeLegal: value),
      ),
      (
        title: 'Цели и этапы',
        subtitle: 'Открытые и просроченные этапы объекта.',
        value: settings.includeMilestones,
        update: (value) =>
            settings = settings.copyWith(includeMilestones: value),
      ),
    ];
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: items[index].value,
              onChanged: saving
                  ? null
                  : (value) => setState(() => items[index].update(value)),
              title: Text(
                items[index].title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(items[index].subtitle),
            ),
            if (index != items.length - 1) const Divider(height: 18),
          ],
          const Divider(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.includeEmptySections,
            onChanged: saving
                ? null
                : (value) => setState(
                    () => settings = settings.copyWith(
                      includeEmptySections: value,
                    ),
                  ),
            title: const Text(
              'Показывать пустые разделы',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Добавлять направления, где по объекту ничего не произошло.',
            ),
          ),
        ],
      ),
    );
  }

  String statusTitle(String status) {
    return switch (status) {
      'sent' => 'Отправлена',
      'failed' => 'Ошибка',
      'processing' => 'Обрабатывается',
      _ => 'В очереди',
    };
  }

  Widget historyCard(DispatcherSummaryRun run) {
    final date = run.summaryDate;
    final dateText = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run.objectName.isEmpty ? 'Старая сводка без объекта' : run.objectName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  statusTitle(run.status),
                  style: TextStyle(
                    color: run.status == 'failed' ? Colors.red : const Color(0xFF6B7075),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (dateText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(dateText, style: const TextStyle(color: Color(0xFF6B7075))),
            ],
            if (run.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(run.body, maxLines: 5, overflow: TextOverflow.ellipsis),
            ],
            if (run.errorText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(run.errorText, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'ИИ-диспетчер',
      subtitle: 'Ежедневная сводка по одному выбранному объекту',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || saving || running ? null : load,
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
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                mainCard(),
                sectionTitle(
                  'Расписание',
                  'Когда отправлять сводку выбранного объекта.',
                ),
                weekdaysCard(),
                sectionTitle(
                  'Содержание сводки',
                  'Какие данные объекта должен проверить оператор.',
                ),
                contentCard(),
                sectionTitle(
                  'Получатели',
                  'Кому отправить итог по выбранному объекту.',
                ),
                recipientsCard(),
                sectionTitle(
                  'Доставка и ИИ',
                  'Каналы отправки и интеллектуальный комментарий.',
                ),
                deliveryCard(),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: saving || running ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Сохранить настройки'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: saving || running ? null : runNow,
                  icon: running
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Проверить сейчас'),
                ),
                if (runs.isNotEmpty) ...[
                  sectionTitle(
                    'Последние запуски',
                    'История показывает объект каждой сводки отдельно.',
                  ),
                  ...runs.map(historyCard),
                ],
              ],
            ),
    );
  }
}
