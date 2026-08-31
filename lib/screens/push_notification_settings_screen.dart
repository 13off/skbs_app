import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skbs_app/app/app_adaptive_palette.dart';

import '../services/push_notification_service.dart';
import '../services/web_push_bridge.dart';
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
  static const String _webPushPublicKey =
      'BEDeIMiSvfz3KavkGnr8UKRZkfE0Ix3PmG8HGNWcm20b70Zh_cWBmNR3crMxi5nYHk4KHbf_frABXuQDontdYn8';

  bool _connecting = false;
  String? _localError;

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

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _localError = null;
    });

    try {
      if (kIsWeb) {
        // На iPhone Notification.requestPermission должен стартовать прямо из
        // пользовательского нажатия. Поэтому сначала вызываем browser API, а
        // уже после создания подписки синхронизируем её с Supabase.
        await WebPushBridge.subscribe(_webPushPublicKey);
        await PushNotificationService.syncForCurrentSession();
      } else {
        await PushNotificationService.syncForCurrentSession(
          requestPermission: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localError =
            'Не удалось подключить уведомления. Проверьте интернет и повторите.';
      });
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
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
            final busy = snapshot.busy || _connecting;
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
                        onChanged: busy
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
                        _localError ?? snapshot.message,
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy || !snapshot.enabled ? null : _connect,
                        icon: busy
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
                PremiumWorkCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'На iPhone AppСтрой должен быть добавлен на экран «Домой» и открыт с иконки. Подписка привязывается к вашему пользователю и активной компании. При выходе устройство отключается.',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
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
            style: TextStyle(
              color: AppAdaptivePalette.textFaint,
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
