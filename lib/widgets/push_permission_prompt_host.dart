import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/push_permission_prompt_store.dart';
import '../services/push_notification_service.dart';
import '../services/web_push_bridge.dart';

class PushPermissionPromptHost extends StatefulWidget {
  final Widget child;

  const PushPermissionPromptHost({super.key, required this.child});

  @override
  State<PushPermissionPromptHost> createState() =>
      _PushPermissionPromptHostState();
}

class _PushPermissionPromptHostState extends State<PushPermissionPromptHost> {
  static const String _webPushPublicKey =
      'BEDeIMiSvfz3KavkGnr8UKRZkfE0Ix3PmG8HGNWcm20b70Zh_cWBmNR3crMxi5nYHk4KHbf_frABXuQDontdYn8';

  StreamSubscription<AuthState>? _authSubscription;
  bool _dialogOpen = false;
  bool _promptCheckInFlight = false;
  bool _handledForSession = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    PushNotificationService.state.addListener(_schedulePromptCheck);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _schedulePromptCheck(),
    );
    _schedulePromptCheck();
  }

  @override
  void dispose() {
    PushNotificationService.state.removeListener(_schedulePromptCheck);
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  void _schedulePromptCheck() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowPrompt());
    });
  }

  bool _canPrompt(PushNotificationSnapshot snapshot) {
    return snapshot.enabled &&
        snapshot.configured &&
        !snapshot.registered &&
        !snapshot.busy &&
        snapshot.permission != PushPermissionState.denied &&
        snapshot.permission != PushPermissionState.unknown;
  }

  Future<void> _maybeShowPrompt() async {
    if (!mounted || _dialogOpen || _promptCheckInFlight) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _userId = null;
      _handledForSession = false;
      return;
    }
    if (_userId != user.id) {
      _userId = user.id;
      _handledForSession = false;
    }
    if (_handledForSession) return;

    final snapshot = PushNotificationService.state.value;
    if (!_canPrompt(snapshot)) return;

    _promptCheckInFlight = true;
    try {
      if (await PushPermissionPromptStore.wasShown(user.id)) {
        _handledForSession = true;
        return;
      }

      if (!mounted || Supabase.instance.client.auth.currentUser?.id != user.id) {
        return;
      }
      if (!_canPrompt(PushNotificationService.state.value)) return;

      // Фиксируем показ до открытия окна: повторная инициализация виджета,
      // вкладки или приложения не сможет открыть второй такой же вопрос.
      // Если пользователь выберет «Позже», push останется доступен в настройках.
      _handledForSession = true;
      final persisted = await PushPermissionPromptStore.markShown(user.id);
      if (!persisted || !mounted) return;

      _dialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Включить уведомления'),
          content: const Text(
            'AppСтрой будет присылать задачи, важные сообщения и рабочие напоминания прямо на телефон.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Позже'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (kIsWeb) {
                  // В iOS Web Push системный запрос должен стартовать прямо
                  // из нажатия пользователя, без await перед subscribe.
                  final browserSubscription = WebPushBridge.subscribe(
                    _webPushPublicKey,
                  );
                  Navigator.of(dialogContext).pop();
                  unawaited(
                    browserSubscription.then((_) async {
                      await PushNotificationService.syncForCurrentSession();
                    }).catchError((_) {}),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();
                unawaited(
                  PushNotificationService.syncForCurrentSession(
                    requestPermission: true,
                  ),
                );
              },
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Включить'),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
      _promptCheckInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
