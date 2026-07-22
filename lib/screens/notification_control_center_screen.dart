import 'package:flutter/material.dart';

import '../data/notification_repository.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';

class NotificationControlCenterScreen extends StatefulWidget {
  const NotificationControlCenterScreen({super.key});

  @override
  State<NotificationControlCenterScreen> createState() =>
      _NotificationControlCenterScreenState();
}

class _NotificationControlCenterScreenState
    extends State<NotificationControlCenterScreen> {
  bool isLoading = true;
  bool isSaving = false;
  String? errorText;
  NotificationControlSettings settings = NotificationControlSettings.defaults();
  List<ReminderControlSetting> reminders = <ReminderControlSetting>[];

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });
    try {
      final data =
          await NotificationRepository.fetchNotificationControlCenter();
      if (!mounted) return;
      setState(() {
        settings = data.settings;
        reminders = data.reminders;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorText = 'Не удалось загрузить настройки: $error';
      });
    }
  }

  Future<void> saveSettings() async {
    if (isSaving) return;
    setState(() {
      isSaving = true;
      errorText = null;
    });
    try {
      final saved = await NotificationRepository.saveNotificationControlCenter(
        settings: settings,
        reminders: reminders,
      );
      if (!mounted) return;
      setState(() {
        settings = saved.settings;
        reminders = saved.reminders;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки уведомлений сохранены')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = 'Не удалось сохранить настройки: $error';
      });
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String formatTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> pickReminderTime(int index) async {
    final current = parseTime(reminders[index].localTime);
    final selected = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Время напоминания',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (selected == null || !mounted) return;
    setState(() {
      reminders[index] = reminders[index].copyWith(
        localTime: formatTime(selected),
      );
    });
  }

  void updateRole(String role, bool selected) {
    final next = Set<String>.from(settings.selectedRoles);
    selected ? next.add(role) : next.remove(role);
    setState(() => settings = settings.copyWith(selectedRoles: next));
  }

  void updateEventGroup(String group, bool selected) {
    final next = Set<String>.from(settings.selectedEventGroups);
    selected ? next.add(group) : next.remove(group);
    setState(() => settings = settings.copyWith(selectedEventGroups: next));
  }

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
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

  Widget channelsCard() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.inAppEnabled,
            onChanged: isSaving
                ? null
                : (value) {
                    setState(() {
                      settings = settings.copyWith(inAppEnabled: value);
                    });
                  },
            title: const Text(
              'Внутренний колокольчик',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Показывать руководителю уведомления внутри приложения.',
            ),
          ),
          const Divider(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.pushEnabled,
            onChanged: isSaving
                ? null
                : (value) {
                    setState(() {
                      settings = settings.copyWith(pushEnabled: value);
                    });
                  },
            title: const Text(
              'Системные push',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Отправлять руководителю push на зарегистрированные устройства.',
            ),
          ),
        ],
      ),
    );
  }

  Widget rolesCard() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Роли и направления',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () {
                        setState(() {
                          settings = settings.copyWith(
                            selectedRoles: NotificationRepository
                                .allNotificationRoles
                                .toSet(),
                          );
                        });
                      },
                child: const Text('Выбрать все'),
              ),
            ],
          ),
          const Text(
            'От уведомлений каких ролей руководитель будет получать события.',
            style: TextStyle(color: Color(0xFF6B7075), height: 1.35),
          ),
          const SizedBox(height: 8),
          ...NotificationRepository.allNotificationRoles.map((role) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.selectedRoles.contains(role),
              onChanged: isSaving
                  ? null
                  : (value) => updateRole(role, value == true),
              title: Text(
                NotificationRepository.notificationRoleTitles[role] ?? role,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }

  Widget eventGroupsCard() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Типы событий',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () {
                        setState(() {
                          settings = settings.copyWith(
                            selectedEventGroups: NotificationRepository
                                .allNotificationEventGroups
                                .toSet(),
                          );
                        });
                      },
                child: const Text('Выбрать все'),
              ),
            ],
          ),
          const Text(
            'Какие внутренние события показывать в колокольчике и отправлять через push.',
            style: TextStyle(color: Color(0xFF6B7075), height: 1.35),
          ),
          const SizedBox(height: 8),
          ...NotificationRepository.allNotificationEventGroups.map((group) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.selectedEventGroups.contains(group),
              onChanged: isSaving
                  ? null
                  : (value) => updateEventGroup(group, value == true),
              title: Text(
                NotificationRepository.notificationEventGroupTitles[group] ??
                    group,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }

  Widget reminderCard(int index) {
    final reminder = reminders[index];
    final definition = NotificationRepository.reminderDefinitions[reminder.key];
    final roleTitle =
        NotificationRepository.notificationRoleTitles[reminder.recipientRole] ??
        reminder.recipientRole;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.enabled,
              onChanged: isSaving
                  ? null
                  : (value) {
                      setState(() {
                        reminders[index] = reminder.copyWith(enabled: value);
                      });
                    },
              title: Text(
                definition?.title ?? reminder.key,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(definition?.description ?? ''),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Получатель: $roleTitle',
                    style: const TextStyle(
                      color: Color(0xFF6B7075),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : () => pickReminderTime(index),
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(reminder.localTime),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget remindersBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Напоминания компании',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () {
                      setState(() {
                        reminders = reminders
                            .map((item) => item.copyWith(enabled: false))
                            .toList();
                      });
                    },
              child: const Text('Выключить все'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'Сейчас все напоминания выключены. Руководитель сам включает нужные и задаёт время по Москве.',
            style: TextStyle(
              color: Color(0xFF6B7075),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...List<Widget>.generate(reminders.length, reminderCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Настройка уведомлений'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPage(
        title: 'Центр уведомлений',
        subtitle:
            'Все внутренние настройки колокольчика, push и напоминаний компании.',
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorText != null) ...[
                    PremiumWorkCard(
                      radius: 22,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  sectionTitle(
                    'Каналы руководителя',
                    'Общее включение внутреннего колокольчика и системных push.',
                  ),
                  channelsCard(),
                  const SizedBox(height: 16),
                  rolesCard(),
                  const SizedBox(height: 12),
                  eventGroupsCard(),
                  const SizedBox(height: 22),
                  remindersBlock(),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: isSaving ? null : saveSettings,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Сохранить все настройки'),
                  ),
                ],
              ),
      ),
    );
  }
}
