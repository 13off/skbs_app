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
import 'procurement_deliveries_screen.dart';

class AdaptiveProcurementDeliveriesScreen extends StatelessWidget {
  final AppUserProfile profile;

  const AdaptiveProcurementDeliveriesScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppUi.desktopBreakpoint) {
          return ProcurementDeliveriesScreen(profile: profile);
        }
        return _DesktopProcurementDeliveriesScreen(profile: profile);
      },
    );
  }
}

class _DesktopProcurementDeliveriesScreen extends StatefulWidget {
  final AppUserProfile profile;

  const _DesktopProcurementDeliveriesScreen({required this.profile});

  @override
  State<_DesktopProcurementDeliveriesScreen> createState() =>
      _DesktopProcurementDeliveriesScreenState();
}

class _DesktopProcurementDeliveriesScreenState
    extends State<_DesktopProcurementDeliveriesScreen> {
  final searchController = TextEditingController();
  late Future<List<ProcurementRequest>> future;
  StreamSubscription<AppDataChange>? subscription;
  String filter = 'active';

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.procurement)) {
        unawaited(refresh());
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<List<ProcurementRequest>> load() async {
    final rows = await ProcurementRepository.fetchRequests(
      companyId: widget.profile.activeCompanyId,
    );
    return rows
        .where(
          (item) => const <String>{
            'ordered',
            'in_delivery',
            'delivered',
          }.contains(item.status),
        )
        .toList();
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> moveNext(ProcurementRequest request) async {
    final next = request.nextStatus;
    if (next == null) return;
    try {
      await ProcurementRepository.setStatus(
        requestId: request.id,
        status: next,
      );
      if (mounted) await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String money(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
      buffer.write(digits[index]);
    }
    return '${buffer.toString()} ₽';
  }

  List<ProcurementRequest> visible(List<ProcurementRequest> rows) {
    final query = searchController.text.trim().toLowerCase();
    final result = rows.where((request) {
      if (filter == 'active' && request.status == 'delivered') return false;
      if (filter == 'delivered' && request.status != 'delivered') return false;
      if (query.isEmpty) return true;
      return <String>[
        request.title,
        request.objectName,
        request.supplierName,
        request.invoiceNumber,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    result.sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      final aDate = a.expectedDeliveryAt ?? a.neededBy ?? a.updatedAt;
      final bDate = b.expectedDeliveryAt ?? b.neededBy ?? b.updatedAt;
      return aDate.compareTo(bDate);
    });
    return result;
  }

  Widget metric(
    String label,
    String value,
    IconData icon, {
    Color? accent,
  }) {
    final color = accent ?? AppAdaptivePalette.textPrimary;
    return Expanded(
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget summary(List<ProcurementRequest> rows) {
    final ordered = rows.where((item) => item.status == 'ordered').length;
    final inDelivery = rows.where((item) => item.status == 'in_delivery').length;
    final overdue = rows.where((item) => item.isOverdue).length;
    final amount = rows
        .where((item) => item.status != 'delivered')
        .fold<double>(0, (sum, item) => sum + item.totalAmount);
    return Row(
      children: [
        metric('Заказано', '$ordered', Icons.inventory_2_outlined),
        const SizedBox(width: 12),
        metric(
          'В пути',
          '$inDelivery',
          Icons.local_shipping_outlined,
          accent: Colors.blue,
        ),
        const SizedBox(width: 12),
        metric(
          'Просрочено',
          '$overdue',
          Icons.warning_amber_rounded,
          accent: overdue > 0
              ? AppAdaptivePalette.danger
              : AppAdaptivePalette.textMuted,
        ),
        const SizedBox(width: 12),
        metric(
          'Сумма в пути',
          money(amount),
          Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget toolbar() {
    Widget chip(String value, String label) {
      return ChoiceChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) => setState(() => filter = value),
      );
    }

    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Заявка, объект, поставщик или счёт',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 8,
            children: [
              chip('active', 'Активные'),
              chip('delivered', 'Доставлено'),
              chip('all', 'Все'),
            ],
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget status(ProcurementRequest request) {
    final color = request.status == 'delivered'
        ? Colors.green
        : request.isOverdue
        ? AppAdaptivePalette.danger
        : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        request.statusTitle,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget table(List<ProcurementRequest> rows) {
    if (rows.isEmpty) {
      return PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 54),
        child: Center(
          child: Text(
            'Доставок по выбранному фильтру нет',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return PremiumWorkCard(
      radius: 24,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 1080
                ? 1080.0
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: DataTable(
                  headingRowHeight: 50,
                  dataRowMinHeight: 62,
                  dataRowMaxHeight: 72,
                  horizontalMargin: 18,
                  columnSpacing: 22,
                  headingTextStyle: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  columns: const [
                    DataColumn(label: Text('Поставка')),
                    DataColumn(label: Text('Объект')),
                    DataColumn(label: Text('Поставщик')),
                    DataColumn(label: Text('Статус')),
                    DataColumn(label: Text('Срок')),
                    DataColumn(label: Text('Сумма'), numeric: true),
                    DataColumn(label: Text('Действие')),
                  ],
                  rows: rows.map((request) {
                    final deadline =
                        request.expectedDeliveryAt ?? request.neededBy;
                    return DataRow(
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              request.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        DataCell(Text(request.objectName)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              request.supplierName.isEmpty
                                  ? '—'
                                  : request.supplierName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(status(request)),
                        DataCell(
                          Text(
                            date(deadline),
                            style: TextStyle(
                              color: request.isOverdue
                                  ? AppAdaptivePalette.danger
                                  : AppAdaptivePalette.textPrimary,
                              fontWeight: request.isOverdue
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            money(request.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DataCell(
                          request.status != 'delivered' &&
                                  request.nextStatus != null
                              ? FilledButton.tonalIcon(
                                  onPressed: () => moveNext(request),
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: Text(request.nextActionTitle!),
                                )
                              : Text(
                                  'Завершено',
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProcurementRequest>>(
      future: future,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ProcurementRequest>[];
        final rows = visible(all);
        final children = <Widget>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const PremiumWorkCard(
              radius: 22,
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Не удалось загрузить доставки',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppAdaptivePalette.textMuted),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        } else {
          children.addAll([
            summary(all),
            const SizedBox(height: 14),
            toolbar(),
            const SizedBox(height: 14),
            table(rows),
          ]);
        }

        return AppPage(
          title: 'Доставки',
          subtitle: 'Заказы в пути, сроки и приёмка на объекте',
          onRefresh: refresh,
          headerTrailing: IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}
