import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/estimator_closing_operations_repository.dart';
import '../models/estimator_closing_operations.dart';
import '../models/estimator_payment_candidate.dart';
import '../models/estimator_period_closing.dart';

class EstimatorClosingOperationsScreen extends StatefulWidget {
  final EstimatorPeriodClosing closing;
  final AppUserProfile profile;

  const EstimatorClosingOperationsScreen({
    super.key,
    required this.closing,
    required this.profile,
  });

  @override
  State<EstimatorClosingOperationsScreen> createState() => _EstimatorClosingOperationsScreenState();
}

class _EstimatorClosingOperationsScreenState extends State<EstimatorClosingOperationsScreen> {
  late Future<List<EstimatorClosingPackageEntry>> packageFuture;
  late Future<List<EstimatorClosingPayoutLine>> payoutFuture;
  bool busy = false;

  bool get canEditPackage => const {'estimator', 'admin', 'developer'}.contains(widget.profile.role);
  bool get canVerifyPackage => const {'lawyer', 'accountant', 'admin', 'developer'}.contains(widget.profile.role);
  bool get canSeeFinance => const {'accountant', 'admin', 'developer'}.contains(widget.profile.role);

  @override
  void initState() {
    super.initState();
    packageFuture = EstimatorClosingOperationsRepository.fetchPackage(widget.closing.id);
    payoutFuture = _loadPayouts();
  }

  Future<List<EstimatorClosingPayoutLine>> _loadPayouts() async {
    if (!canSeeFinance) return const <EstimatorClosingPayoutLine>[];
    await EstimatorClosingOperationsRepository.refreshPayouts(widget.closing.id);
    return EstimatorClosingOperationsRepository.fetchPayouts(widget.closing.id);
  }

  Future<void> refresh() async {
    final nextPackage = EstimatorClosingOperationsRepository.fetchPackage(widget.closing.id);
    final nextPayout = _loadPayouts();
    if (mounted) {
      setState(() {
        packageFuture = nextPackage;
        payoutFuture = nextPayout;
      });
    }
    await Future.wait<dynamic>([nextPackage, nextPayout]);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Операция не выполнена: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addPackageEntry() async {
    String kind = 'supporting_document';
    final title = TextEditingController();
    final number = TextEditingController();
    final note = TextEditingController();
    DateTime? documentDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить в пакет закрытия'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Тип'),
                  items: const [
                    DropdownMenuItem(value: 'volume_register', child: Text('Ведомость объёмов')),
                    DropdownMenuItem(value: 'supporting_document', child: Text('Подтверждающий документ')),
                    DropdownMenuItem(value: 'client_template', child: Text('Шаблон заказчика')),
                    DropdownMenuItem(value: 'other', child: Text('Другое')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => kind = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 12),
                TextField(controller: number, decoration: const InputDecoration(labelText: 'Номер · необязательно')),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Дата документа'),
                  subtitle: Text(documentDate == null ? 'Не указана' : _date(documentDate!)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: documentDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => documentDate = picked);
                  },
                ),
                TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Комментарий · необязательно')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await run(() async {
        await EstimatorClosingOperationsRepository.addPackageEntry(
          closingId: widget.closing.id,
          kind: kind,
          title: title.text,
          documentNumber: number.text,
          documentDate: documentDate,
          note: note.text,
        );
      });
    }
    title.dispose();
    number.dispose();
    note.dispose();
  }

  Future<void> voidEntry(EstimatorClosingPackageEntry entry) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Аннулировать запись?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Причина · обязательно'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Аннулировать'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed == true) {
      await run(() => EstimatorClosingOperationsRepository.voidPackageEntry(entry.id, reason));
    }
  }

  Future<void> linkPayment(EstimatorClosingPayoutLine line) async {
    final candidates = await EstimatorClosingOperationsRepository.fetchCandidatePayments(
      employeeId: line.employeeId,
      objectId: widget.closing.objectId,
      periodYear: line.periodYear,
      periodMonth: line.periodMonth,
    );
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('За этот период в разделе выплат ещё нет подходящей фактической выплаты.')),
      );
      return;
    }
    final selected = await showDialog<EstimatorPaymentCandidate>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Связать выплату · ${line.employeeName}'),
        content: SizedBox(
          width: 600,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final item = candidates[index];
              return ListTile(
                title: Text('${_money(item.amount)} · ${_date(item.paymentDate)}'),
                subtitle: Text([item.paymentType, item.comment].where((value) => value.trim().isNotEmpty).join(' · ')),
                onTap: () => Navigator.pop(dialogContext, item),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Закрыть'))],
      ),
    );
    if (selected != null) {
      await run(() => EstimatorClosingOperationsRepository.linkPayment(lineId: line.id, paymentId: selected.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Пакет закрытия',
      subtitle: '${widget.closing.objectName} · ${widget.closing.periodTitle}',
      showBackButton: true,
      onRefresh: refresh,
      headerTrailing: canEditPackage
          ? FilledButton.icon(
              onPressed: busy ? null : addPackageEntry,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить документ'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(16),
            child: Text(
              'Ведомость подтверждённых объёмов берётся из самого закрытия. КС-2, КС-3, договорные цены и формы заказчика здесь не придумываются: их можно добавить только как реальные документы/шаблоны компании.',
            ),
          ),
          const SizedBox(height: 16),
          Text('Документы пакета', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          FutureBuilder<List<EstimatorClosingPackageEntry>>(
            future: packageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
              if (snapshot.hasError) return Text('Не удалось загрузить пакет: ${snapshot.error}');
              final items = snapshot.data ?? const <EstimatorClosingPackageEntry>[];
              if (items.isEmpty) return const PremiumWorkCard(radius: 20, padding: EdgeInsets.all(18), child: Text('Дополнительные документы пока не приложены.'));
              return Column(
                children: items.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumWorkCard(
                    radius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                [entry.kindTitle, entry.documentNumber, entry.documentDate == null ? '' : _date(entry.documentDate!), entry.statusTitle]
                                    .where((value) => value.trim().isNotEmpty)
                                    .join(' · '),
                                style: TextStyle(color: AppAdaptivePalette.textMuted),
                              ),
                              if (entry.note.isNotEmpty) ...[const SizedBox(height: 4), Text(entry.note)],
                            ],
                          ),
                        ),
                        if (canVerifyPackage && entry.status == 'attached')
                          IconButton(
                            tooltip: 'Проверено',
                            onPressed: busy ? null : () => run(() => EstimatorClosingOperationsRepository.verifyPackageEntry(entry.id)),
                            icon: const Icon(Icons.verified_outlined),
                          ),
                        if (canEditPackage)
                          IconButton(
                            tooltip: 'Аннулировать',
                            onPressed: busy ? null : () => voidEntry(entry),
                            icon: const Icon(Icons.block_outlined),
                          ),
                      ],
                    ),
                  ),
                )).toList(growable: false),
              );
            },
          ),
          if (canSeeFinance) ...[
            const SizedBox(height: 18),
            Text('Выработка к выплате', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Это подготовка и сверка. Новая выплата автоматически не создаётся.', style: TextStyle(color: AppAdaptivePalette.textMuted)),
            const SizedBox(height: 10),
            FutureBuilder<List<EstimatorClosingPayoutLine>>(
              future: payoutFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                if (snapshot.hasError) return Text('Не удалось загрузить выработку: ${snapshot.error}');
                final lines = snapshot.data ?? const <EstimatorClosingPayoutLine>[];
                if (lines.isEmpty) {
                  return const PremiumWorkCard(
                    radius: 20,
                    padding: EdgeInsets.all(18),
                    child: Text('Строк к выплате нет. Нужны подтверждённые объёмы, явные внутренние расценки и распределение вклада сотрудников.'),
                  );
                }
                return Column(
                  children: lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumWorkCard(
                      radius: 20,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.employeeName, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text('${_money(line.amount)} · ${line.statusTitle}', style: TextStyle(color: AppAdaptivePalette.textMuted)),
                                if (line.blockerNote.isNotEmpty) ...[const SizedBox(height: 4), Text(line.blockerNote)],
                              ],
                            ),
                          ),
                          if (line.isPaid)
                            OutlinedButton(
                              onPressed: busy ? null : () => run(() => EstimatorClosingOperationsRepository.unlinkPayment(line.id)),
                              child: const Text('Отвязать'),
                            )
                          else
                            FilledButton(
                              onPressed: busy || line.isBlocked ? null : () => linkPayment(line),
                              child: const Text('Связать выплату'),
                            ),
                        ],
                      ),
                    ),
                  )).toList(growable: false),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
String _money(double value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(raw[i]);
  }
  return '${buffer.toString()} ₽';
}
