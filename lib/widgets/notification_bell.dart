import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';

import '../data/app_data_sync.dart';
import '../data/notification_repository.dart';
import '../features/dispatcher/presentation/dispatcher_summary_details_screen.dart';
import 'premium_ui_v2.dart';

Color get _card => AppAdaptivePalette.surfaceElevated;
Color get _softCard => AppAdaptivePalette.surfaceSoft;
Color get _line => AppAdaptivePalette.border;
Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _accent => AppAdaptivePalette.textFaint;

class NotificationBell extends StatefulWidget {
  final String? selectedObjectName;

  const NotificationBell({super.key, required this.selectedObjectName});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Future<bool>? hasUnreadFuture;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  @override
  void initState() {
    super.initState();
    refreshHasUnread();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      refreshHasUnread();
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    super.dispose();
  }

  void handleDataChange(AppDataChange change) {
    if (!mounted || !change.affects(AppDataDomain.notifications)) return;

    final selectedObject = widget.selectedObjectName?.trim() ?? '';
    final changedObject = change.contextValue('object_name') ?? '';
    if (selectedObject.isNotEmpty &&
        changedObject.isNotEmpty &&
        selectedObject != changedObject) {
      return;
    }
    setState(refreshHasUnread);
  }

  void refreshHasUnread() {
    hasUnreadFuture = NotificationRepository.hasUnread(
      objectName: widget.selectedObjectName,
    );
  }

  String formatTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  Future<bool> confirmClear(BuildContext context) async {
    final isAllObjects = widget.selectedObjectName == null ||
        widget.selectedObjectName!.trim().isEmpty;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить уведомления?'),
        content: Text(
          isAllObjects
              ? 'Уведомления будут скрыты для тебя по всем объектам.'
              : 'Уведомления будут скрыты для тебя по объекту ${widget.selectedObjectName!.trim()}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> showNotificationsSheet(BuildContext context) async {
    var notificationsFuture = NotificationRepository.fetchLatest(
      objectName: widget.selectedObjectName,
      limit: 60,
    );
    final markedAsReadIds = <String>{};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> clearCurrentNotifications() async {
            final confirmed = await confirmClear(context);
            if (!confirmed || !context.mounted) return;
            await NotificationRepository.clearNotifications(
              objectName: widget.selectedObjectName,
            );
            setModalState(() {
              notificationsFuture = NotificationRepository.fetchLatest(
                objectName: widget.selectedObjectName,
                limit: 60,
              );
            });
          }

          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4CCC2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Уведомления',
                          style: TextStyle(
                            color: _text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: clearCurrentNotifications,
                        icon: Icon(Icons.delete_sweep_outlined),
                        label: const Text('Очистить'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.selectedObjectName == null ||
                              widget.selectedObjectName!.trim().isEmpty
                          ? 'Последние изменения по всем объектам'
                          : 'Последние изменения: ${widget.selectedObjectName!.trim()}',
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Flexible(
                    child: FutureBuilder<List<AppNotification>>(
                      future: notificationsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return _NotificationMessage(
                            icon: Icons.error_outline,
                            title: 'Не удалось загрузить уведомления',
                            text: snapshot.error.toString(),
                          );
                        }

                        final notifications =
                            snapshot.data ?? <AppNotification>[];
                        if (notifications.isEmpty) {
                          return const _NotificationMessage(
                            icon: Icons.notifications_none_outlined,
                            title: 'Пока пусто',
                            text:
                                'Когда кто-то изменит сотрудников, табель, задачи, выплаты или объекты, записи появятся здесь.',
                          );
                        }

                        final unreadIds = notifications
                            .where((notification) => !notification.isRead)
                            .map((notification) => notification.id)
                            .where(
                              (id) =>
                                  id.trim().isNotEmpty &&
                                  !markedAsReadIds.contains(id),
                            )
                            .toList();
                        if (unreadIds.isNotEmpty) {
                          markedAsReadIds.addAll(unreadIds);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            NotificationRepository.markAsRead(unreadIds);
                          });
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NotificationTile(
                                notification: notification,
                                timeText: formatTime(notification.createdAt),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    setState(refreshHasUnread);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasUnreadFuture,
      builder: (context, snapshot) {
        final hasUnread = snapshot.data == true;
        return PremiumPressable(
          onTap: () => showNotificationsSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  Colors.white.withValues(alpha: 0.76),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hasUnread ? _accent : Colors.white),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF17191C).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_none_outlined,
                    color: _text,
                    size: 25,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: 11,
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: _card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String timeText;

  const _NotificationTile({
    required this.notification,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    final objectName = notification.objectName.trim();
    final actorEmail = notification.actorEmail.trim();
    final isUnread = !notification.isRead;
    final isDispatcherSummary =
        notification.entityType == 'dispatcher_summary' &&
        notification.entityId.trim().isNotEmpty;

    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      tint: isUnread ? _card : _softCard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isUnread ? _softCard : _card,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isDispatcherSummary
                  ? Icons.analytics_outlined
                  : isUnread
                      ? Icons.notifications_active_outlined
                      : Icons.history,
              color: _accent,
              size: 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      timeText,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (isUnread) ...[
                  SizedBox(height: 7),
                  const _NotificationChip(
                    icon: Icons.fiber_new_outlined,
                    text: 'Новое',
                  ),
                ],
                if (notification.body.trim().isNotEmpty) ...[
                  SizedBox(height: 7),
                  Text(
                    notification.body.trim(),
                    style: TextStyle(
                      color: _text,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (isDispatcherSummary) ...[
                  SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DispatcherSummaryDetailsScreen(
                            runId: notification.entityId.trim(),
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.analytics_outlined, size: 19),
                    label: const Text('Разобрать отклонения'),
                  ),
                ],
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _NotificationChip(
                      icon: Icons.person_outline,
                      text: actorEmail.isEmpty
                          ? notification.actorName
                          : '${notification.actorName} • $actorEmail',
                    ),
                    if (objectName.isNotEmpty)
                      _NotificationChip(
                        icon: Icons.business_outlined,
                        text: objectName,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NotificationChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _muted, size: 15),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      tint: _softCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 34),
          SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
