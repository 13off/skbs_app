import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import '../app/app_adaptive_palette.dart';
import '../data/app_data_sync.dart';
import '../data/offline_sync_service.dart';

class OfflineSyncHost extends StatefulWidget {
  final String userId;
  final String companyId;
  final Widget child;

  const OfflineSyncHost({
    super.key,
    required this.userId,
    required this.companyId,
    required this.child,
  });

  @override
  State<OfflineSyncHost> createState() => _OfflineSyncHostState();
}

class _OfflineSyncHostState extends State<OfflineSyncHost>
    with WidgetsBindingObserver {
  static const Duration _retryInterval = Duration(seconds: 20);

  Timer? _retryTimer;
  StreamSubscription<AppDataChange>? _dataChangeSubscription;
  StreamSubscription<html.Event>? _onlineSubscription;
  StreamSubscription<html.Event>? _offlineSubscription;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isOnline = !kIsWeb || html.window.navigator.onLine == true;
    _configure();
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (_isOnline) unawaited(OfflineSyncService.flush());
    });
    _dataChangeSubscription = AppDataSync.changes.listen((change) {
      if (change.isRemote) unawaited(_syncAfterConnectivitySignal());
    });
    if (kIsWeb) {
      _onlineSubscription = html.window.onOnline.listen((_) {
        if (mounted) setState(() => _isOnline = true);
        unawaited(_syncAfterConnectivitySignal());
      });
      _offlineSubscription = html.window.onOffline.listen((_) {
        if (mounted) setState(() => _isOnline = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant OfflineSyncHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.companyId != widget.companyId) {
      _configure();
    }
  }

  Future<void> _configure() async {
    await OfflineSyncService.configure(
      userId: widget.userId,
      companyId: widget.companyId,
    );
    if (_isOnline) await OfflineSyncService.flush();
  }

  Future<void> _syncAfterConnectivitySignal() async {
    if (kIsWeb && html.window.navigator.onLine != true) {
      if (mounted && _isOnline) setState(() => _isOnline = false);
      return;
    }
    if (mounted && !_isOnline) setState(() => _isOnline = true);
    if (OfflineSyncService.pendingCount > 0) {
      await OfflineSyncService.flush();
      return;
    }
    await OfflineSyncService.markSynced();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isOnline) {
      unawaited(OfflineSyncService.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _dataChangeSubscription?.cancel();
    _onlineSubscription?.cancel();
    _offlineSubscription?.cancel();
    super.dispose();
  }

  void _showStatus(OfflineSyncState state) {
    final lastSyncText = state.lastSyncAt == null
        ? 'Последняя синхронизация ещё не выполнялась.'
        : 'Последняя синхронизация: ${DateFormat('HH:mm').format(state.lastSyncAt!.toLocal())}.';
    final String message;
    if (!_isOnline) {
      message =
          'Нет соединения с интернетом. Продолжайте работать — изменения сохраняются на устройстве и будут автоматически отправлены на сервер после восстановления связи. $lastSyncText';
    } else if (state.isSyncing) {
      message =
          'Связь есть. Данные отправляются на сервер. Осталось операций: ${state.pendingCount}.';
    } else {
      message =
          'Данные сохранены на устройстве и ожидают отправки на сервер. Осталось операций: ${state.pendingCount}. $lastSyncText';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineSyncState>(
      valueListenable: OfflineSyncService.state,
      builder: (context, state, _) {
        final showIndicator =
            !_isOnline || state.isSyncing || state.pendingCount > 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (showIndicator)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                right: 12,
                child: _OfflineStatusButton(
                  online: _isOnline,
                  state: state,
                  onTap: () => _showStatus(state),
                  onRetry: _isOnline && !state.isSyncing
                      ? () => unawaited(OfflineSyncService.flush())
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OfflineStatusButton extends StatelessWidget {
  final bool online;
  final OfflineSyncState state;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  const _OfflineStatusButton({
    required this.online,
    required this.state,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final syncing = online && state.isSyncing;
    final waiting = online && !syncing && state.pendingCount > 0;
    final background = !online
        ? AppAdaptivePalette.danger
        : syncing
        ? AppAdaptivePalette.accentStrong
        : AppAdaptivePalette.warning;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: !online
            ? 'Нет сети'
            : syncing
            ? 'Данные отправляются'
            : 'Ожидает отправки',
        child: InkWell(
          onTap: onTap,
          onLongPress: onRetry,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    !online
                        ? Icons.signal_wifi_connected_no_internet_4_rounded
                        : waiting
                        ? Icons.schedule_send_rounded
                        : Icons.sync_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}
