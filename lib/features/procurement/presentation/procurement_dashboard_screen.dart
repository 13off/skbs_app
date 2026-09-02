import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';

class ProcurementDashboardScreen extends StatefulWidget {
  final AppUserProfile profile;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenDeliveries;

  const ProcurementDashboardScreen({
    super.key,
    required this.profile,
    required this.onOpenRequests,
    required this.onOpenDeliveries,
  });

  @override
  State<ProcurementDashboardScreen> createState() =>
      _ProcurementDashboardScreenState();
}

class _ProcurementDashboardScreenState
    extends State<ProcurementDashboardScreen> {
  late Future<ProcurementDashboardData> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.procurement) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<ProcurementDashboardData> load() =>
      ProcurementRepository.fetchDashboard(
        companyId: widget.profile.activeCompanyId,
      );

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  String money(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      if (i > 0 && (rounded.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(rounded[i]);
    }
    return '${buffer.toString()} ₽';
  }

  Widget metric(String value, String label, IconData icon) {
    return Expanded(
      child: PremiumWorkCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppAdaptivePalette.textMuted, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppAdaptivePalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget requestTile(ProcurementRequest request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: PremiumWorkCard(
        radius: 20,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: request.isOverdue
                    ? AppAdaptivePalette.danger.withValues(alpha: 0.13)
                    : AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                request.isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.inventory_2_outlined,
                color: request.isOverdue
                    ? AppAdaptivePalette.danger
                    : AppAdaptivePalette.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${request.objectName} · ${request.statusTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money(request.totalAmount),
              style: TextStyle(
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget actionPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Рабочие разделы',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Быстрый переход без мобильных полноэкранных карточек.',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.onOpenRequests,
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Открыть заявки'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onOpenDeliveries,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Открыть доставки'),
          ),
        ],
      ),
    );
  }

  Widget loadError(Object? error) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(
            'Не удалось загрузить снабжение',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error?.toString().replaceFirst('Exception: ', '') ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          PremiumActionButton(
            onPressed: refresh,
            icon: Icons.refresh_rounded,
            label: 'Повторить',
          ),
        ],
      ),
    );
  }

  Widget mobileContent(ProcurementDashboardData data) {
    final latest = data.requests.where((item) => !item.isClosed).take(5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            metric(
              data.requiresAttention.toString(),
              'Требуют внимания',
              Icons.priority_high_rounded,
            ),
            const SizedBox(width: 10),
            metric(
              data.inPurchase.toString(),
              'В закупке',
              Icons.shopping_cart_checkout_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            metric(
              data.inDelivery.toString(),
              'В доставке',
              Icons.local_shipping_outlined,
            ),
            const SizedBox(width: 10),
            metric(
              money(data.openAmount),
              'Открытая сумма',
              Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: PremiumActionButton(
                onPressed: widget.onOpenRequests,
                icon: Icons.assignment_outlined,
                label: 'Заявки',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onOpenDeliveries,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Доставки'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'В работе',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (latest.isEmpty)
          PremiumWorkCard(
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Text(
              'Нет открытых заявок',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          ...latest.map(requestTile),
      ],
    );
  }

  Widget desktopContent(ProcurementDashboardData data) {
    final latest = data.requests.where((item) => !item.isClosed).take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            metric(
              data.requiresAttention.toString(),
              'Требуют внимания',
              Icons.priority_high_rounded,
            ),
            const SizedBox(width: 12),
            metric(
              data.inPurchase.toString(),
              'В закупке',
              Icons.shopping_cart_checkout_rounded,
            ),
            const SizedBox(width: 12),
            metric(
              data.inDelivery.toString(),
              'В доставке',
              Icons.local_shipping_outlined,
            ),
            const SizedBox(width: 12),
            metric(
              money(data.openAmount),
              'Открытая сумма',
              Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'В работе',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onOpenRequests,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Все заявки'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (latest.isEmpty)
                    PremiumWorkCard(
                      radius: 20,
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Нет открытых заявок',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    ...latest.map(requestTile),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(flex: 3, child: actionPanel()),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Снабжение',
      onRefresh: refresh,
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<ProcurementDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) return loadError(snapshot.error);

          final data =
              snapshot.data ??
              const ProcurementDashboardData(
                requests: <ProcurementRequest>[],
                suppliers: <ProcurementSupplier>[],
              );
          return LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth >= AppUi.desktopBreakpoint
                  ? desktopContent(data)
                  : mobileContent(data);
            },
          );
        },
      ),
    );
  }
}
