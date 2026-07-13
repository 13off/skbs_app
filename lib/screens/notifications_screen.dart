import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_data_sync.dart';
import '../data/notification_repository.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';

class NotificationsScreen extends StatefulWidget {
  final String? focusNotificationId;

  const NotificationsScreen({super.key, this.focusNotificationId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<List<AppNotification>>? notificationsFuture;
  StreamSubscription<AppDataChange>? dataSubscription;

  @override
  void initState() {
    super.initState();
    notificationsFuture = NotificationRepository.fetchLatest(limit: 60);
    dataSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.notifications) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    dataSubscription?.cancel();
    super.dispose();
  }

  void refresh() {
    setState(() {
      notificationsFuture = NotificationRepository.fetchLatest(limit: 60);
    });
  }

  Future<void> markVisibleAsRead(List<AppNotification> notifications) async {
    final unreadIds = notifications
        .where((notification) => !notification.isRead)
        .map((notification) => notification.id)
        .toList();
    if (unreadIds.isEmpty) return;
    await NotificationRepository.markAsRead(unreadIds);
    if (mounted) refresh();
  }

  String formatTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Уведомления'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPage(
        title: 'Уведомления',
        subtitle:
            'Тот же персональный список, который остаётся доступен через внутренний колокольчик.',
        child: FutureBuilder<List<AppNotification>>(
          future: notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              return PremiumWorkCard(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'Не удалось загрузить уведомления',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: refresh,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final notifications = snapshot.data ?? const <AppNotification>[];
            if (notifications.isEmpty) {
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 46),
                      SizedBox(height: 12),
                      Text(
                        'Новых уведомлений нет',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(markVisibleAsRead(notifications));
            });

            return Column(
              children: notifications.map((notification) {
                final isFocused =
                    notification.id == widget.focusNotificationId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumWorkCard(
                    radius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFocused || !notification.isRead
                                ? const Color(0xFF6F747A)
                                : const Color(0xFFD7D9DC),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (notification.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  notification.body,
                                  style: const TextStyle(
                                    color: Color(0xFF5F646A),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 9),
                              Text(
                                [
                                  if (notification.actorName.trim().isNotEmpty)
                                    notification.actorName.trim(),
                                  if (notification.objectName.trim().isNotEmpty)
                                    notification.objectName.trim(),
                                  formatTime(notification.createdAt),
                                ].join(' • '),
                                style: const TextStyle(
                                  color: Color(0xFF8A8F94),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
