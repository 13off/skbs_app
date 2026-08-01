import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';

class ProcurementDeliveriesScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ProcurementDeliveriesScreen({super.key, required this.profile});

  @override
  State<ProcurementDeliveriesScreen> createState() => _ProcurementDeliveriesScreenState();
}

class _ProcurementDeliveriesScreenState extends State<ProcurementDeliveriesScreen> {
  late Future<List<ProcurementRequest>> future;
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

  Future<List<ProcurementRequest>> load() async {
    final rows = await ProcurementRepository.fetchRequests(
      companyId: widget.profile.activeCompanyId,
    );
    return rows
        .where((item) => const {'ordered', 'in_delivery', 'delivered'}.contains(item.status))
        .toList();
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> moveNext(ProcurementRequest request) async {
    final next = request.nextStatus;
    if (next == null) return;
    try {
      await ProcurementRepository.setStatus(requestId: request.id, status: next);
      if (mounted) await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Срок не указан';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Widget card(ProcurementRequest request) {
    final color = request.status == 'delivered'
        ? Colors.green
        : request.isOverdue
            ? AppAdaptivePalette.danger
            : Colors.blue;
    final deadline = request.expectedDeliveryAt ?? request.neededBy;
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.local_shipping_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('${request.objectName} · ${request.statusTitle}', style: TextStyle(color: AppAdaptivePalette.textMuted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: request.isOverdue ? AppAdaptivePalette.danger : AppAdaptivePalette.textMuted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    dateText(deadline),
                    style: TextStyle(color: request.isOverdue ? AppAdaptivePalette.danger : AppAdaptivePalette.textMuted, fontWeight: FontWeight.w800),
                  ),
                ),
                if (request.supplierName.isNotEmpty)
                  Flexible(
                    child: Text(request.supplierName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppAdaptivePalette.textMuted, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (request.status != 'delivered' && request.nextStatus != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => moveNext(request),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(request.nextActionTitle!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Доставки',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<List<ProcurementRequest>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: PremiumActionButton(onPressed: refresh, icon: Icons.refresh_rounded, label: 'Повторить'));
          }
          final rows = snapshot.data ?? const <ProcurementRequest>[];
          if (rows.isEmpty) {
            return Center(
              child: Text('Нет доставок', style: TextStyle(color: AppAdaptivePalette.textMuted, fontWeight: FontWeight.w700)),
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 36),
              itemCount: rows.length,
              itemBuilder: (_, index) => card(rows[index]),
            ),
          );
        },
      ),
    );
  }
}
