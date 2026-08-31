import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _dismissedForSession = false;
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
    if (!mounted || !kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPrompt());
  }

  void _maybeShowPrompt() {
    if (!mounted || _dialogOpen) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _userId = null;
      _dismissedForSession = false;
      return;
    }
    if (_userId != user.id) {
      _userId = user.id;
      _dismissedForSession = false;
    }
    if (_dismissedForSession) return;

    final snapshot = PushNotificationService.state.value;
    if (!snapshot.enabled ||
        !snapshot.configured ||
        snapshot.registered ||
        snapshot.busy ||
        snapshot.permission == PushPermissionState.denied ||
        snapshot.permission == PushPermissionState.unknown) {
      return;
    }

    _dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Включить уведомления'),
        content: const Text(
          'AppСтрой будет присылать задачи, важные сообщения и рабочие напоминания прямо на телефон.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _dismissedForSession = true;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Позже'),
          ),
          FilledButton.icon(
            onPressed: () {
              // В iOS Web Push системный запрос должен быть запущен прямо из
              // нажатия пользователя. Не ставим никаких await перед subscribe.
              final browserSubscription = WebPushBridge.subscribe(
                _webPushPublicKey,
              );
              Navigator.of(dialogContext).pop();
              unawaited(
                browserSubscription.then((_) async {
                  await PushNotificationService.syncForCurrentSession();
                }).catchError((_) {}),
              );
            },
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Включить'),
          ),
        ],
      ),
    ).whenComplete(() {
      _dialogOpen = false;
      _dismissedForSession = true;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
