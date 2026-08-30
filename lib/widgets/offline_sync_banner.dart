import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      if (change.isRemote) unawaited(OfflineSyncService.markSynced());
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
        return Column(
          children: [
            _OfflinePendingBanner(state: state),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}

class _OfflinePendingBanner extends StatelessWidget {
  final OfflineSyncState state;

  const _OfflinePendingBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final lastSyncText = state.lastSyncAt == null
        ? 'Последняя синхронизация: —'
        : 'Последняя синхронизация: ${DateFormat('HH:mm').format(state.lastSyncAt!.toLocal())}';

    return Material(
      color: AppAdaptivePalette.surfaceElevated,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppAdaptivePalette.border),
            ),
          ),
          child: Row(
            children: [
              Icon(
                state.isSyncing
                    ? Icons.sync_rounded
                    : Icons.cloud_upload_outlined,
                size: 18,
                color: AppAdaptivePalette.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Ожидает отправки: ${state.pendingCount} · $lastSyncText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Синхронизировать',
                visualDensity: VisualDensity.compact,
                onPressed: state.isSyncing
                    ? null
                    : () => unawaited(OfflineSyncService.flush()),
                icon: state.isSyncing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
