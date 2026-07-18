import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/dispatcher_summary_repository.dart';

class DispatcherSettingsScreen extends StatefulWidget {
  const DispatcherSettingsScreen({super.key});

  @override
  State<DispatcherSettingsScreen> createState() => _DispatcherSettingsScreenState();
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
        runs = center.runs;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> save() async {
    if (saving) return;
    if (settings.weekdays.isEmpty || settings.recipientRoles.isEmpty) {
      setState(() => errorText = 'Выбери хотя бы один день и одного получателя.');
      return;
    }
    if (!settings.inAppEnabled && !settings.pushEnabled) {
      setState(() => errorText = 'Включи колокольчик или push.');
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
      if (mounted) {
        setState(() => errorText = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> runNow() async {
    if (running) return;
    setState(() {
      running = true;
      errorText = null;
    });
    try {
      await DispatcherSummaryRepository.save(settings);
      await DispatcherSummaryRepository.runNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сводка поставлена в обработку')),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await load();
    } catch (error) {
      if (mounted) {
        setState(() => errorText = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  TimeOfDay _time(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30,
    );
  }

  String _formatTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _time(settings.localTime),
      helpText: 'Время ежедневной сводки',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (result == null || !mounted) return;
    setState(() => settings = settings.copyWith(localTime: _formatTime(result)));
  }

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.enabled,
            onChanged: saving ? null : (value) => setState(() => settings = settings.copyWith(enabled: value)),
            title: const Text('Ежедневная сводка', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Оператор сам проверяет компанию и присылает итог дня.'),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Время отправки', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${settings.localTime} · ${DispatcherSummaryRepository.timezoneTitles[settings.timezone] ?? settings.timezone}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: saving ? null : pickTime,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: DispatcherSummaryRepository.timezoneTitles.containsKey(settings.timezone)
                ? settings.timezone
                : 'Europe/Moscow',
            decoration: const InputDecoration(
              labelText: 'Часовой пояс',
              prefixIcon: Icon(Icons.public_rounded),
            ),
            items: DispatcherSummaryRepository.timezoneTitles.entries
                .map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) setState(() => settings = settings.copyWith(timezone: value));
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
          const Text('Дни отправки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
                        setState(() => settings = settings.copyWith(weekdays: next));
                      },
              );
            }).toList(),
          ),
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
            onChanged: saving ? null : (value) => setState(() => settings = settings.copyWith(inAppEnabled: value)),
            title: const Text('Колокольчик', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Сохранять сводку внутри AppСтрой.'),
          ),
          const Divider(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.pushEnabled,
            onChanged: saving ? null : (value) => setState(() => settings = settings.copyWith(pushEnabled: value)),
            title: const Text('Push-уведомление', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Присылать сводку на зарегистрированные устройства.'),
          ),
          const Divider(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.aiCommentary,
            onChanged: saving ? null : (value) => setState(() => settings = settings.copyWith(aiCommentary: value)),
            title: const Text('Комментарий ИИ', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('ИИ выделяет риски и предлагает конкретные действия. Без него остаётся автоматическая цифровая сводка.'),
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
          const Text('Получатели', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Кому оператор отправляет ежедневную сводку.', style: TextStyle(color: Color(0xFF6B7075))),
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
                      setState(() => settings = settings.copyWith(recipientRoles: next));
                    },
              title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w800)),
            );
          }),
        ],
      ),
    );
  }

  Widget contentCard() {
    final items = <({String title, String subtitle, bool value, void Function(bool) update})>[
      (title: 'Задачи', subtitle: 'Выполнено, незакрыто и задачи с проблемами.', value: settings.includeTasks, update: (v) => settings = settings.copyWith(includeTasks: v)),
      (title: 'Табель', subtitle: 'Выходы, смены и сотрудники без отметки.', value: settings.includeAttendance, update: (v) => settings = settings.copyWith(includeAttendance: v)),
      (title: 'Сотрудники', subtitle: 'Активные и добавленные за день.', value: settings.includeEmployees, update: (v) => settings = settings.copyWith(includeEmployees: v)),
      (title: 'Выплаты', subtitle: 'Операции, суммы и выплаты без чека.', value: settings.includePayments, update: (v) => settings = settings.copyWith(includePayments: v)),
      (title: 'Подбор персонала', subtitle: 'Активные кандидаты и входящие сообщения.', value: settings.includeRecruitment, update: (v) => settings = settings.copyWith(includeRecruitment: v)),
      (title: 'Юридическое', subtitle: 'Просрочки, риски и истекающие документы.', value: settings.includeLegal, update: (v) => settings = settings.copyWith(includeLegal: v)),
      (title: 'Цели и этапы', subtitle: 'Открытые, просроченные и ближайшие сроки.', value: settings.includeMilestones, update: (v) => settings = settings.copyWith(includeMilestones: v)),
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
              title: Text(items[index].title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(items[index].subtitle),
            ),
            if (index != items.length - 1) const Divider(height: 18),
          ],
          const Divider(height: 22),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.includeEmptySections,
            onChanged: saving ? null : (value) => setState(() => settings = settings.copyWith(includeEmptySections: value)),
            title: const Text('Показывать пустые разделы', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Добавлять в сводку направления, где за день ничего не произошло.'),
          ),
        ],
      ),
    );
  }

  Widget actionsCard() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: saving || running ? null : save,
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving || running ? null : runNow,
            icon: running
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: const Text('Проверить сейчас'),
          ),
        ),
      ],
    );
  }

  String runStatus(DispatcherSummaryRun run) {
    return switch (run.status) {
      'sent' => run.aiUsed ? 'Отправлено · с ИИ' : 'Отправлено · автоанализ',
      'processing' => 'Формируется',
      'failed' => 'Ошибка',
      _ => 'В очереди',
    };
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Без даты';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Widget historyCard() {
    if (runs.isEmpty) {
      return const PremiumWorkCard(
        radius: 26,
        child: Text('Сводок пока нет. Нажми «Проверить сейчас» или включи расписание.'),
      );
    }
    return Column(
      children: runs.take(8).map((run) {
        final failed = run.status == 'failed';
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
                    Icon(
                      failed ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
                      color: failed ? Theme.of(context).colorScheme.error : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        run.title.isEmpty ? 'Сводка за ${dateText(run.summaryDate)}' : run.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(runStatus(run), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
                if (run.body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(run.body, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.35)),
                ],
                if (run.errorText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(run.errorText, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'ИИ-диспетчер',
      subtitle: 'Ежедневный контроль компании, риски и персональная сводка',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || saving ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorText != null) ...[
                  PremiumWorkCard(
                    radius: 20,
                    child: Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                  const SizedBox(height: 12),
                ],
                mainCard(),
                sectionTitle('Расписание', 'Выбери дни и точное местное время.'),
                weekdaysCard(),
                sectionTitle('Доставка', 'Где появится сводка и кто её получит.'),
                deliveryCard(),
                const SizedBox(height: 12),
                recipientsCard(),
                sectionTitle('Содержание сводки', 'Оператор анализирует только включённые направления.'),
                contentCard(),
                const SizedBox(height: 14),
                actionsCard(),
                sectionTitle('История', 'Последние автоматические и ручные запуски.'),
                historyCard(),
              ],
            ),
    );
  }
}
