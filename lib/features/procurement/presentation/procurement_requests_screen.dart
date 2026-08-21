import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';
import 'procurement_request_editor_screen.dart';
import '../../../navigation/app_page_route.dart';

class ProcurementRequestsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ProcurementRequestsScreen({super.key, required this.profile});

  @override
  State<ProcurementRequestsScreen> createState() =>
      _ProcurementRequestsScreenState();
}

class _ProcurementRequestsScreenState extends State<ProcurementRequestsScreen> {
  late Future<List<ProcurementRequest>> future;
  StreamSubscription<AppDataChange>? subscription;
  String filter = 'open';
  final TextEditingController searchController = TextEditingController();

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
    searchController.dispose();
    super.dispose();
  }

  Future<List<ProcurementRequest>> load() =>
      ProcurementRepository.fetchRequests(
        companyId: widget.profile.activeCompanyId,
      );

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> openEditor([ProcurementRequest? request]) async {
    final changed = await Navigator.push<bool>(
      context,
      AppPageRoute(
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

  String money(double value) => '${value.round()} ₽';

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
    return source.where((item) {
      final matchesFilter = switch (filter) {
        'open' => !item.isClosed,
        'delivery' => item.isDelivery,
        'closed' => item.isClosed,
        _ => true,
      };
      final haystack = '${item.title} ${item.objectName} ${item.supplierName}'
          .toLowerCase();
      return matchesFilter && (query.isEmpty || haystack.contains(query));
    }).toList();
  }

  Widget card(ProcurementRequest request) {
    final color = statusColor(request);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        request.objectName,
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') openEditor(request);
                    if (value == 'cancel') cancel(request);
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    if (!request.isClosed)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                    if (!request.isClosed)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Отменить'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: request.statusTitle, color: color),
                _Chip(
                  label: request.priorityTitle,
                  color: AppAdaptivePalette.textMuted,
                ),
                _Chip(
                  label: money(request.totalAmount),
                  color: AppAdaptivePalette.textPrimary,
                ),
                _Chip(
                  label: '${request.items.length} поз.',
                  color: AppAdaptivePalette.textMuted,
                ),
              ],
            ),
            if (request.supplierName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                request.supplierName,
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (request.nextStatus != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => moveNext(request),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(request.nextActionTitle!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('В работе'),
            selected: filter == 'open',
            onSelected: (_) => setState(() => filter = 'open'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Доставка'),
            selected: filter == 'delivery',
            onSelected: (_) => setState(() => filter = 'delivery'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Закрытые'),
            selected: filter == 'closed',
            onSelected: (_) => setState(() => filter = 'closed'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Все'),
            selected: filter == 'all',
            onSelected: (_) => setState(() => filter = 'all'),
          ),
        ],
      ),
    );
  }

  Widget loadingPage() {
    return AppPage(
      title: 'Заявки',
      headerTrailing: IconButton(
        tooltip: 'Новая заявка',
        onPressed: openEditor,
        icon: const Icon(Icons.add_rounded),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget errorPage(Object? error) {
    return AppPage(
      title: 'Заявки',
      headerTrailing: IconButton(
        tooltip: 'Новая заявка',
        onPressed: openEditor,
        icon: const Icon(Icons.add_rounded),
      ),
      child: PremiumWorkCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'Не удалось загрузить заявки',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProcurementRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loadingPage();
        }
        if (snapshot.hasError) return errorPage(snapshot.error);

        final rows = visible(snapshot.data ?? const <ProcurementRequest>[]);
        return AppLazyPage(
          title: 'Заявки',
          subtitle: '',
          headerTrailing: IconButton(
            tooltip: 'Новая заявка',
            onPressed: openEditor,
            icon: const Icon(Icons.add_rounded),
          ),
          leading: [
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Поиск',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            filters(),
            const SizedBox(height: 14),
          ],
          itemCount: rows.length,
          itemBuilder: (_, index) => card(rows[index]),
          trailing: rows.isEmpty
              ? <Widget>[
                  PremiumWorkCard(
                    radius: 20,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text(
                          'Заявок по выбранному фильтру нет',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        PremiumActionButton(
                          onPressed: openEditor,
                          icon: Icons.add_rounded,
                          label: 'Новая заявка',
                        ),
                      ],
                    ),
                  ),
                ]
              : const <Widget>[],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
