import 'dart:async';

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configure();
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      unawaited(OfflineSyncService.flush());
    });
    _dataChangeSubscription = AppDataSync.changes.listen((change) {
      if (change.isRemote) unawaited(_syncAfterConnectivitySignal());
    });
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
    await OfflineSyncService.flush();
  }

  Future<void> _syncAfterConnectivitySignal() async {
    if (OfflineSyncService.pendingCount > 0) {
      await OfflineSyncService.flush();
      return;
    }
    await OfflineSyncService.markSynced();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(OfflineSyncService.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _dataChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineSyncState>(
      valueListenable: OfflineSyncService.state,
      builder: (context, state, _) {
        if (state.pendingCount == 0) return widget.child;
        final safeTop = MediaQuery.paddingOf(context).top;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned(
              top: safeTop + 8,
              right: 10,
              child: _OfflineSyncIndicator(state: state),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineSyncIndicator extends StatelessWidget {
  final OfflineSyncState state;

  const _OfflineSyncIndicator({required this.state});

  Future<void> _showStatus(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppAdaptivePalette.surfaceElevated,
      builder: (sheetContext) {
        final syncing = state.isSyncing;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (syncing
                                ? AppAdaptivePalette.accent
                                : AppAdaptivePalette.danger)
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: syncing
                          ? SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppAdaptivePalette.accent,
                              ),
                            )
                          : Icon(
                              Icons.wifi_off_rounded,
                              size: 20,
                              color: AppAdaptivePalette.danger,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        syncing ? 'Отправляем данные' : 'Нет связи с сервером',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  syncing
                      ? 'Соединение восстановлено. AppСтрой отправляет сохранённые изменения на сервер. Осталось: ${state.pendingCount}.'
                      : 'Изменения сохранены на этом устройстве. AppСтрой автоматически отправит их на сервер, когда соединение восстановится.',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!syncing) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        unawaited(OfflineSyncService.flush());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Проверить соединение'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncing = state.isSyncing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStatus(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: syncing
                ? AppAdaptivePalette.accent
                : AppAdaptivePalette.danger,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.wifi_off_rounded, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}
