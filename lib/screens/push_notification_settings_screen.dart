import 'package:flutter/material.dart';

import '../data/notification_repository.dart';
import '../data/user_repository.dart';
import '../services/push_notification_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  const PushNotificationSettingsScreen({super.key});

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> {
  bool loadingRoles = true;
  bool savingRoles = false;
  bool isManager = false;
  Set<String> selectedRoles = NotificationRepository.allNotificationRoles
      .toSet();
  String? roleError;

  @override
  void initState() {
    super.initState();
    loadRolePreferences();
  }

  Future<void> loadRolePreferences() async {
    try {
      final profile = await UserRepository.fetchCurrentProfile();
      final manager =
          profile?.isAdmin == true || profile?.actualRole == 'admin';
      final roles = manager
          ? await NotificationRepository.fetchSelectedNotificationRoles()
          : <String>{profile?.role ?? ''};
      if (!mounted) return;
      setState(() {
        isManager = manager;
        selectedRoles = roles;
        loadingRoles = false;
        roleError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingRoles = false;
        roleError = 'Не удалось загрузить роли уведомлений: $error';
      });
    }
  }

  Future<void> saveRolePreferences() async {
    if (!isManager || savingRoles) return;
    setState(() {
      savingRoles = true;
      roleError = null;
    });
    try {
      final saved = await NotificationRepository.saveSelectedNotificationRoles(
        selectedRoles,
      );
      if (!mounted) return;
      setState(() => selectedRoles = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Роли для колокольчика и push сохранены')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => roleError = 'Не удалось сохранить роли: $error');
    } finally {
      if (mounted) setState(() => savingRoles = false);
    }
  }

  String permissionLabel(PushPermissionState permission) {
    switch (permission) {
      case PushPermissionState.authorized:
        return 'Разрешены';
      case PushPermissionState.provisional:
        return 'Разрешены предварительно';
      case PushPermissionState.denied:
        return 'Запрещены в системе';
      case PushPermissionState.notDetermined:
        return 'Разрешение ещё не запрошено';
      case PushPermissionState.unknown:
        return 'Статус пока неизвестен';
    }
  }

  Widget rolePreferencesCard() {
    if (loadingRoles) {
      return const PremiumWorkCard(
        radius: 26,
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!isManager) {
      return const PremiumWorkCard(
        radius: 26,
        padding: EdgeInsets.all(20),
        child: Text(
          'Уведомления автоматически ограничены вашей ролью и доступными объектами.',
          style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
        ),
      );
    }

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Какие роли учитывать',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Руководителю по умолчанию доступны все направления. Выбор одинаково действует на внутренний колокольчик и системные push.',
            style: TextStyle(color: Color(0xFF5F646A), height: 1.4),
          ),
          const SizedBox(height: 12),
          ...NotificationRepository.allNotificationRoles.map((role) {
            final title =
                NotificationRepository.notificationRoleTitles[role] ?? role;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selectedRoles.contains(role),
              onChanged: savingRoles
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          selectedRoles.add(role);
                        } else {
                          selectedRoles.remove(role);
                        }
                      });
                    },
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: savingRoles ? null : saveRolePreferences,
            icon: savingRoles
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Сохранить роли'),
          ),
          if (roleError != null) ...[
            const SizedBox(height: 10),
            Text(roleError!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Push-уведомления'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPage(
        title: 'Уведомления',
        subtitle:
            'Настройки системных push и ролевой ленты внутреннего колокольчика.',
        child: ValueListenableBuilder<PushNotificationSnapshot>(
          valueListenable: PushNotificationService.state,
          builder: (context, snapshot, _) {
            return Column(
              children: [
                PremiumWorkCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: snapshot.enabled,
                        onChanged: snapshot.busy
                            ? null
                            : PushNotificationService.setEnabled,
                        title: const Text(
                          'Получать push на этом устройстве',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Настройка относится только к текущему браузеру или телефону.',
                        ),
                      ),
                      const Divider(height: 28),
                      _StatusRow(
                        label: 'Канал',
                        value: snapshot.configured
                            ? 'Системная доставка доступна'
                            : 'Нужна установка приложения или поддерживаемый браузер',
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'Разрешение',
                        value: permissionLabel(snapshot.permission),
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        label: 'Устройство',
                        value: snapshot.registered
                            ? 'Подписка зарегистрирована'
                            : 'Подписка не зарегистрирована',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                rolePreferencesCard(),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        snapshot.message,
                        style: const TextStyle(
                          color: Color(0xFF5F646A),
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: snapshot.busy || !snapshot.enabled
                            ? null
                            : () {
                                PushNotificationService.syncForCurrentSession(
                                  requestPermission: true,
                                );
                              },
                        icon: snapshot.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.notifications_active_rounded),
                        label: Text(
                          snapshot.registered
                              ? 'Обновить регистрацию'
                              : 'Разрешить и подключить',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const PremiumWorkCard(
                  radius: 26,
                  padding: EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'На iPhone AppСтрой должен быть добавлен на экран «Домой» и открыт с иконки. Подписка привязывается к вашему пользователю и активной компании. При выходе устройство отключается.',
                          style: TextStyle(
                            color: Color(0xFF5F646A),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A8F94),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
