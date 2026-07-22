import 'package:flutter/material.dart';

import '../services/push_notification_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';

class PushNotificationSettingsScreen extends StatelessWidget {
  const PushNotificationSettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Push-уведомления'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPage(
        title: 'Push на устройстве',
        subtitle:
            'Разрешение и регистрация текущего телефона или браузера. Общие правила задаются руководителем отдельно.',
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
