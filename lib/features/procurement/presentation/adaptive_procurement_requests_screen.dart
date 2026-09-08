import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../navigation/app_page_route.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';
import 'procurement_request_editor_screen.dart';
import 'procurement_requests_screen.dart';

class AdaptiveProcurementRequestsScreen extends StatelessWidget {
  final AppUserProfile profile;

  const AdaptiveProcurementRequestsScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppUi.desktopBreakpoint) {
          return ProcurementRequestsScreen(profile: profile);
        }
        return _DesktopProcurementRequestsScreen(profile: profile);
      },
    );
  }
}

class _DesktopProcurementRequestsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const _DesktopProcurementRequestsScreen({required this.profile});

  @override
  State<_DesktopProcurementRequestsScreen> createState() =>
      _DesktopProcurementRequestsScreenState();
}

class _DesktopProcurementRequestsScreenState
    extends State<_DesktopProcurementRequestsScreen> {
  final TextEditingController searchController = TextEditingController();
  late Future<List<ProcurementRequest>> future;
  StreamSubscription<AppDataChange>? subscription;
  String filter = 'open';

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

  Future<List<ProcurementRequest>> load() {
    return ProcurementRepository.fetchRequests(
      companyId: widget.profile.activeCompanyId,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> openEditor([ProcurementRequest? request]) async {
    final changed = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => ProcurementRequestEditorScreen(
          profile: widget.profile,
          request: request,
        ),
      ),
    );
    if (changed == true && mounted) await refresh();
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

  Future<void> cancel(ProcurementRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить заявку?'),
        content: Text(request.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отменить заявку'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ProcurementRepository.setStatus(
        requestId: request.id,
        status: 'canceled',
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

  String money(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
      buffer.write(digits[index]);
    }
    return '${buffer.toString()} ₽';
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  Color statusColor(ProcurementRequest request) {
    if (request.status == 'delivered') return Colors.green;
    if (request.status == 'canceled') return AppAdaptivePalette.textMuted;
    if (request.isOverdue || request.priority == 'urgent') {
      return AppAdaptivePalette.danger;
    }
    if (request.isDelivery) return Colors.blue;
    return AppAdaptivePalette.accent;
  }

  List<ProcurementRequest> visible(List<ProcurementRequest> source) {
    final query = searchController.text.trim().toLowerCase();
    final result = source.where((item) {
      final matchesFilter = switch (filter) {
        'open' => !item.isClosed,
        'delivery' => item.isDelivery,
        'closed' => item.isClosed,
        _ => true,
      };
      final haystack = <String>[
        item.title,
        item.objectName,
        item.supplierName,
        item.invoiceNumber,
        item.comment,
        ...item.items.map((entry) => entry.name),
      ].join(' ').toLowerCase();
      return matchesFilter && (query.isEmpty || haystack.contains(query));
    }).toList();

    result.sort((first, second) {
      if (first.isOverdue != second.isOverdue) return first.isOverdue ? -1 : 1;
      if (first.priority == 'urgent' && second.priority != 'urgent') return -1;
      if (second.priority == 'urgent' && first.priority != 'urgent') return 1;
      return second.updatedAt.compareTo(first.updatedAt);
    });
    return result;
  }

  Widget metric({
    required IconData icon,
    required String title,
    required String value,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
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
          ],
        ),
      ),
    );
  }

  Widget summary(List<ProcurementRequest> all) {
    final open = all.where((item) => !item.isClosed).toList();
    final delivery = all.where((item) => item.isDelivery).length;
    final attention = all
        .where((item) => item.isOverdue || item.priority == 'urgent')
        .length;
    final openAmount = open.fold<double>(
      0,
      (sum, item) => sum + item.totalAmount,
    );

    return Row(
      children: [
        metric(
          icon: Icons.inventory_2_outlined,
          title: 'Открытые заявки',
          value: '${open.length}',
        ),
        const SizedBox(width: 12),
        metric(
          icon: Icons.local_shipping_outlined,
          title: 'В доставке',
          value: '$delivery',
          accent: Colors.blue,
        ),
        const SizedBox(width: 12),
        metric(
          icon: Icons.warning_amber_rounded,
          title: 'Требуют внимания',
          value: '$attention',
          accent: attention > 0
              ? AppAdaptivePalette.danger
              : AppAdaptivePalette.textMuted,
        ),
        const SizedBox(width: 12),
        metric(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Сумма открытых',
          value: money(openAmount),
        ),
      ],
    );
  }

  Widget filters() {
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
                hintText: 'Заявка, объект, поставщик, счёт или позиция',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('open', 'В работе'),
              chip('delivery', 'Доставка'),
              chip('closed', 'Закрытые'),
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

  Widget requestTitle(ProcurementRequest request) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            request.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (request.invoiceNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Счёт ${request.invoiceNumber}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget actionCell(ProcurementRequest request) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (request.nextStatus != null)
          Tooltip(
            message: request.nextActionTitle ?? 'Следующий этап',
            child: IconButton.filledTonal(
              onPressed: () => moveNext(request),
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),
            ),
          ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Открыть',
          onPressed: () => openEditor(request),
          icon: const Icon(Icons.open_in_new_rounded, size: 19),
        ),
        if (!request.isClosed)
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            onSelected: (value) {
              if (value == 'edit') unawaited(openEditor(request));
              if (value == 'cancel') unawaited(cancel(request));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Редактировать')),
              PopupMenuItem(value: 'cancel', child: Text('Отменить')),
            ],
          ),
      ],
    );
  }

  Widget table(List<ProcurementRequest> rows) {
    if (rows.isEmpty) {
      return PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AppAdaptivePalette.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Заявок по выбранному фильтру нет',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
            final tableWidth = constraints.maxWidth < 1180
                ? 1180.0
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 50,
                  dataRowMinHeight: 66,
                  dataRowMaxHeight: 78,
                  horizontalMargin: 18,
                  columnSpacing: 20,
                  headingTextStyle: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  columns: const [
                    DataColumn(label: Text('Заявка')),
                    DataColumn(label: Text('Объект')),
                    DataColumn(label: Text('Статус')),
                    DataColumn(label: Text('Приоритет')),
                    DataColumn(label: Text('Поставщик')),
                    DataColumn(label: Text('Срок')),
                    DataColumn(label: Text('Сумма'), numeric: true),
                    DataColumn(label: Text('Поз.')),
                    DataColumn(label: Text('Действия')),
                  ],
                  rows: rows.map((request) {
                    final color = statusColor(request);
                    final deadline =
                        request.expectedDeliveryAt ?? request.neededBy;
                    return DataRow(
                      onSelectChanged: (_) => openEditor(request),
                      cells: [
                        DataCell(requestTitle(request)),
                        DataCell(
                          Text(
                            request.objectName.isEmpty ? '—' : request.objectName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          _DesktopStatusPill(
                            label: request.statusTitle,
                            color: color,
                          ),
                        ),
                        DataCell(
                          _DesktopStatusPill(
                            label: request.priorityTitle,
                            color: request.priority == 'urgent'
                                ? AppAdaptivePalette.danger
                                : AppAdaptivePalette.textMuted,
                          ),
                        ),
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
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DataCell(Text('${request.items.length}')),
                        DataCell(actionCell(request)),
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

        final body = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          body.add(
            const PremiumWorkCard(
              radius: 22,
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          body.add(
            PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 38),
                  const SizedBox(height: 12),
                  const Text(
                    'Не удалось загрузить заявки',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
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
          body.addAll([
            summary(all),
            const SizedBox(height: 14),
            filters(),
            const SizedBox(height: 14),
            table(rows),
          ]);
        }

        return AppPage(
          title: 'Заявки',
          subtitle: 'Закупка, согласование и доставка по объектам',
          onRefresh: refresh,
          headerTrailing: FilledButton.icon(
            onPressed: openEditor,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Новая заявка'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        );
      },
    );
  }
}

class _DesktopStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _DesktopStatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
