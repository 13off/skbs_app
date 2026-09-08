import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/object_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/construction_object.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/estimator_closing_repository.dart';
import '../models/estimator_period_closing.dart';
import '../models/task_completion_report.dart';

class EstimatorClosingsScreen extends StatefulWidget {
  const EstimatorClosingsScreen({super.key});

  @override
  State<EstimatorClosingsScreen> createState() => _EstimatorClosingsScreenState();
}

class _EstimatorClosingsScreenState extends State<EstimatorClosingsScreen> {
  late Future<List<EstimatorPeriodClosing>> future;
  List<ConstructionObject> objects = const [];
  String? selectedObjectId;
  late DateTime period;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    period = DateTime(now.year, now.month);
    future = EstimatorClosingRepository.fetchClosings();
    loadObjects();
  }

  Future<void> loadObjects() async {
    final next = await ObjectRepository.fetchObjects();
    if (!mounted) return;
    setState(() {
      objects = next;
      if (selectedObjectId == null && next.isNotEmpty) selectedObjectId = next.first.id;
    });
  }

  Future<void> refresh() async {
    final next = EstimatorClosingRepository.fetchClosings();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> choosePeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: period,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Выберите месяц закрытия',
    );
    if (picked != null && mounted) setState(() => period = DateTime(picked.year, picked.month));
  }

  Future<void> buildPeriod() async {
    final objectId = selectedObjectId;
    if (busy || objectId == null || objectId.isEmpty) return;
    setState(() => busy = true);
    try {
      await EstimatorClosingRepository.createOrRefresh(objectId: objectId, year: period.year, month: period.month);
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Период собран из подтверждённых объёмов')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось собрать период: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit(EstimatorPeriodClosing closing) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await EstimatorClosingRepository.submit(closing.id);
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Закрытие передано юристу')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось передать закрытие: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Закрытие периода',
      subtitle: 'Подтверждённые объёмы → документы → руководитель → заказчик.',
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodBuilderCard(
            objects: objects,
            selectedObjectId: selectedObjectId,
            period: period,
            busy: busy,
            onObjectChanged: (value) => setState(() => selectedObjectId = value),
            onChoosePeriod: choosePeriod,
            onBuild: buildPeriod,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<EstimatorPeriodClosing>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              if (snapshot.hasError) return _ErrorCard(text: 'Не удалось загрузить закрытия: ${snapshot.error}', onRetry: refresh);
              final items = snapshot.data ?? const <EstimatorPeriodClosing>[];
              if (items.isEmpty) return const _EmptyCard(text: 'Закрытий пока нет. Выберите объект и месяц, затем соберите период.');
              return Column(
                children: items.map((closing) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClosingCard(
                    closing: closing,
                    showFinance: false,
                    actions: [
                      OutlinedButton(onPressed: () => _showClosingDetails(context, closing: closing, profile: null), child: const Text('Состав')),
                      if (closing.canEdit) ...[
                        OutlinedButton(onPressed: busy ? null : () async {
                          selectedObjectId = closing.objectId;
                          period = DateTime(closing.periodYear, closing.periodMonth);
                          await buildPeriod();
                        }, child: const Text('Пересобрать')),
                        FilledButton(onPressed: busy || closing.itemCount == 0 ? null : () => submit(closing), child: const Text('Передать')),
                      ],
                    ],
                  ),
                )).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class EstimatorClosingInboxScreen extends StatefulWidget {
  final AppUserProfile profile;
  const EstimatorClosingInboxScreen({super.key, required this.profile});

  @override
  State<EstimatorClosingInboxScreen> createState() => _EstimatorClosingInboxScreenState();
}

class _EstimatorClosingInboxScreenState extends State<EstimatorClosingInboxScreen> {
  late Future<List<EstimatorPeriodClosing>> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<EstimatorPeriodClosing>> load() {
    final role = widget.profile.role;
    if (role == 'lawyer') return EstimatorClosingRepository.fetchClosings(statuses: const ['legal_review']);
    if (role == 'accountant') return EstimatorClosingRepository.fetchClosings(statuses: const ['accounting_review', 'sent_to_client']);
    return EstimatorClosingRepository.fetchClosings(statuses: const ['manager_review', 'ready_for_client', 'sent_to_client']);
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> review(EstimatorPeriodClosing closing, String decision) async {
    final controller = TextEditingController();
    final requiresComment = decision == 'returned';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(decision == 'approved' ? 'Подтвердить этап?' : 'Вернуть сметчику?'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: requiresComment ? 'Причина возврата · обязательно' : 'Комментарий · необязательно', alignLabelWithHint: true),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(onPressed: () {
            if (requiresComment && controller.text.trim().isEmpty) return;
            Navigator.pop(dialogContext, true);
          }, child: Text(decision == 'approved' ? 'Подтвердить' : 'Вернуть')),
        ],
      ),
    );
    final comment = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    await _run(() => EstimatorClosingRepository.review(closingId: closing.id, decision: decision, comment: comment));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await refresh();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Операция не выполнена: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool canReview(EstimatorPeriodClosing closing) {
    final role = widget.profile.role;
    if (closing.status == 'legal_review') return role == 'lawyer' || widget.profile.isAdmin;
    if (closing.status == 'accounting_review') return role == 'accountant' || widget.profile.isAdmin;
    if (closing.status == 'manager_review') return widget.profile.isAdmin;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isFinance = widget.profile.isAccountant || widget.profile.isAdmin;
    return AppPage(
      title: 'Закрытия',
      subtitle: widget.profile.isLawyer
          ? 'Проверка документов по подтверждённым объёмам.'
          : widget.profile.isAccountant
              ? 'Финансовая проверка и внутренний расчёт выработки.'
              : 'Решение руководителя и передача заказчику.',
      onRefresh: refresh,
      headerTrailing: widget.profile.isAccountant
          ? FilledButton.icon(onPressed: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const EstimatorPieceRatesScreen())), icon: const Icon(Icons.price_change_outlined), label: const Text('Расценки'))
          : null,
      child: FutureBuilder<List<EstimatorPeriodClosing>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return _ErrorCard(text: 'Не удалось загрузить очередь: ${snapshot.error}', onRetry: refresh);
          final items = snapshot.data ?? const <EstimatorPeriodClosing>[];
          if (items.isEmpty) return const _EmptyCard(text: 'Сейчас по вашему этапу ничего не ожидает проверки.');
          return Column(
            children: items.map((closing) {
              final actions = <Widget>[
                OutlinedButton(onPressed: () => _showClosingDetails(context, closing: closing, profile: isFinance ? widget.profile : null), child: const Text('Открыть')),
              ];
              if (canReview(closing)) {
                actions.add(OutlinedButton(onPressed: busy ? null : () => review(closing, 'returned'), child: const Text('Вернуть')));
                actions.add(FilledButton(onPressed: busy ? null : () => review(closing, 'approved'), child: const Text('Подтвердить')));
              }
              if (closing.status == 'ready_for_client' && widget.profile.isAdmin) {
                actions.add(FilledButton(onPressed: busy ? null : () => _run(() => EstimatorClosingRepository.markSent(closing.id)), child: const Text('Передано заказчику')));
              }
              if (closing.status == 'sent_to_client' && (widget.profile.isAccountant || widget.profile.isAdmin)) {
                actions.add(FilledButton(onPressed: busy ? null : () => _run(() => EstimatorClosingRepository.markPaid(closing.id)), child: const Text('Оплачено')));
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClosingCard(closing: closing, showFinance: isFinance, actions: actions),
              );
            }).toList(growable: false),
          );
        },
      ),
    );
  }
}

class EstimatorPieceRatesScreen extends StatefulWidget {
  const EstimatorPieceRatesScreen({super.key});
  @override
  State<EstimatorPieceRatesScreen> createState() => _EstimatorPieceRatesScreenState();
}

class _EstimatorPieceRatesScreenState extends State<EstimatorPieceRatesScreen> {
  late Future<List<EstimatorPieceRate>> future;
  List<ConstructionObject> objects = const [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = EstimatorClosingRepository.fetchRates();
    ObjectRepository.fetchObjects().then((value) { if (mounted) setState(() => objects = value); });
  }

  Future<void> refresh() async {
    final next = EstimatorClosingRepository.fetchRates();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> addRate() async {
    if (objects.isEmpty) return;
    final work = TextEditingController();
    final unit = TextEditingController(text: 'м³');
    final rate = TextEditingController();
    String objectId = objects.first.id;
    DateTime validFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Внутренняя расценка'),
        content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(initialValue: objectId, decoration: const InputDecoration(labelText: 'Объект'), items: objects.map((object) => DropdownMenuItem(value: object.id, child: Text(object.name))).toList(), onChanged: (value) { if (value != null) setDialogState(() => objectId = value); }),
          const SizedBox(height: 12),
          TextField(controller: work, decoration: const InputDecoration(labelText: 'Вид работ', hintText: 'Точно как в задаче/объёмах')),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Ед. изм.'))), const SizedBox(width: 12), Expanded(child: TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '₽ за единицу')))]),
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Действует с'), subtitle: Text(_date(validFrom)), trailing: const Icon(Icons.calendar_month_outlined), onTap: () async { final picked = await showDatePicker(context: context, initialDate: validFrom, firstDate: DateTime(2024), lastDate: DateTime(2100)); if (picked != null) setDialogState(() => validFrom = picked); }),
          const Align(alignment: Alignment.centerLeft, child: Text('Расценка используется только для внутреннего расчёта ГПХ/выработки и не является ценой для заказчика.', style: TextStyle(fontSize: 12))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')), FilledButton(onPressed: () { final amount = double.tryParse(rate.text.trim().replaceAll(',', '.')) ?? 0; if (work.text.trim().isEmpty || unit.text.trim().isEmpty || amount <= 0) return; Navigator.pop(dialogContext, true); }, child: const Text('Сохранить'))],
      )),
    );
    if (saved == true) {
      final amount = double.tryParse(rate.text.trim().replaceAll(',', '.')) ?? 0;
      setState(() => busy = true);
      try {
        await EstimatorClosingRepository.upsertRate(objectId: objectId, work: work.text, unit: unit.text, rateAmount: amount, validFrom: validFrom);
        await refresh();
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    work.dispose(); unit.dispose(); rate.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Внутренние расценки',
      subtitle: 'Только явные ставки компании. Договорные цены заказчика здесь не хранятся.',
      showBackButton: true,
      onRefresh: refresh,
      headerTrailing: FilledButton.icon(onPressed: busy || objects.isEmpty ? null : addRate, icon: const Icon(Icons.add_rounded), label: const Text('Добавить')),
      child: FutureBuilder<List<EstimatorPieceRate>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return _ErrorCard(text: 'Не удалось загрузить расценки: ${snapshot.error}', onRetry: refresh);
          final rates = snapshot.data ?? const <EstimatorPieceRate>[];
          if (rates.isEmpty) return const _EmptyCard(text: 'Расценок пока нет. До их явного ввода заработок по объёмам не рассчитывается.');
          return Column(children: rates.map((item) {
            final objectName = objects.where((object) => object.id == item.objectId).map((object) => object.name).firstOrNull ?? 'Объект';
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: PremiumWorkCard(radius: 20, padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.work, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text('$objectName · ${item.unit} · с ${_date(item.validFrom)}', style: TextStyle(color: AppAdaptivePalette.textMuted))])), Text('${_money(item.rateAmount)} / ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(width: 10), IconButton(tooltip: 'Отключить', onPressed: busy ? null : () async { setState(() => busy = true); try { await EstimatorClosingRepository.deactivateRate(item.id); await refresh(); } finally { if (mounted) setState(() => busy = false); } }, icon: const Icon(Icons.block_outlined))])));
          }).toList(growable: false));
        },
      ),
    );
  }
}

class _PeriodBuilderCard extends StatelessWidget {
  final List<ConstructionObject> objects;
  final String? selectedObjectId;
  final DateTime period;
  final bool busy;
  final ValueChanged<String?> onObjectChanged;
  final VoidCallback onChoosePeriod;
  final VoidCallback onBuild;
  const _PeriodBuilderCard({required this.objects, required this.selectedObjectId, required this.period, required this.busy, required this.onObjectChanged, required this.onChoosePeriod, required this.onBuild});
  @override
  Widget build(BuildContext context) => PremiumWorkCard(radius: 24, padding: const EdgeInsets.all(18), child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
    SizedBox(width: 320, child: DropdownButtonFormField<String>(key: ValueKey('closing-object-$selectedObjectId-${objects.length}'), initialValue: objects.any((object) => object.id == selectedObjectId) ? selectedObjectId : null, decoration: const InputDecoration(labelText: 'Объект'), items: objects.map((object) => DropdownMenuItem(value: object.id, child: Text(object.name))).toList(), onChanged: busy ? null : onObjectChanged)),
    OutlinedButton.icon(onPressed: busy ? null : onChoosePeriod, icon: const Icon(Icons.calendar_month_outlined), label: Text('${period.month.toString().padLeft(2, '0')}.${period.year}')),
    FilledButton.icon(onPressed: busy || selectedObjectId == null ? null : onBuild, icon: const Icon(Icons.inventory_2_outlined), label: const Text('Собрать период')),
  ]));
}

class _ClosingCard extends StatelessWidget {
  final EstimatorPeriodClosing closing;
  final bool showFinance;
  final List<Widget> actions;
  const _ClosingCard({required this.closing, required this.showFinance, required this.actions});
  @override
  Widget build(BuildContext context) => PremiumWorkCard(radius: 22, padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${closing.objectName} · ${closing.periodTitle}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('${closing.itemCount} позиций · из задач ${closing.taskItemCount} · вручную ${closing.manualItemCount}', style: TextStyle(color: AppAdaptivePalette.textMuted))])), _StatusBadge(text: closing.statusTitle)]),
    if (closing.isReturned && closing.returnComment.isNotEmpty) ...[const SizedBox(height: 10), Text('Возврат: ${closing.returnComment}', style: const TextStyle(fontWeight: FontWeight.w800))],
    if (showFinance) ...[const SizedBox(height: 10), Wrap(spacing: 16, runSpacing: 6, children: [Text('Расчёт: ${_money(closing.earningsTotal)}'), Text('Строк начислений: ${closing.earningsCount}'), Text('Требует внимания: ${closing.earningsIssueCount}')])],
    const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
  ]));
}

class _StatusBadge extends StatelessWidget {
  final String text;
  const _StatusBadge({required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppAdaptivePalette.surfaceSoft, borderRadius: BorderRadius.circular(30)), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)));
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});
  @override
  Widget build(BuildContext context) => PremiumWorkCard(radius: 22, padding: const EdgeInsets.all(22), child: Text(text, textAlign: TextAlign.center));
}

class _ErrorCard extends StatelessWidget {
  final String text;
  final Future<void> Function() onRetry;
  const _ErrorCard({required this.text, required this.onRetry});
  @override
  Widget build(BuildContext context) => PremiumWorkCard(radius: 22, padding: const EdgeInsets.all(18), child: Column(children: [Text(text), const SizedBox(height: 10), OutlinedButton(onPressed: onRetry, child: const Text('Повторить'))]));
}

Future<void> _showClosingDetails(BuildContext context, {required EstimatorPeriodClosing closing, required AppUserProfile? profile}) async {
  final canSeeFinance = profile?.isAccountant == true || profile?.isAdmin == true;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${closing.objectName} · ${closing.periodTitle}'),
      content: SizedBox(width: 760, height: 560, child: FutureBuilder<List<dynamic>>(
        future: Future.wait<dynamic>([
          EstimatorClosingRepository.fetchItems(closing.id),
          EstimatorClosingRepository.fetchReviews(closing.id),
          if (canSeeFinance) EstimatorClosingRepository.fetchEarnings(closing.id),
          if (canSeeFinance) EstimatorClosingRepository.fetchEarningIssues(closing.id),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final values = snapshot.data!;
          final items = values[0] as List<EstimatorClosingItem>;
          final reviews = values[1] as List<EstimatorClosingReview>;
          final earnings = canSeeFinance ? values[2] as List<EstimatorClosingEarning> : const <EstimatorClosingEarning>[];
          final issues = canSeeFinance ? values[3] as List<EstimatorClosingEarningIssue> : const <EstimatorClosingEarningIssue>[];
          return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Подтверждённые объёмы', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: Icon(item.isManual ? Icons.edit_note_outlined : Icons.task_alt_outlined), title: Text(item.work), subtitle: Text('${_date(item.workDate)} · ${item.workLocation.isEmpty ? (item.isManual ? 'Вручную' : 'Из задачи') : item.workLocation}'), trailing: Text('${TaskCompletionReport.formatQuantity(item.quantity)} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w900)))),
            if (reviews.isNotEmpty) ...[const Divider(height: 28), const Text('История проверок', style: TextStyle(fontWeight: FontWeight.w900)), ...reviews.map((review) => ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text('${review.stage} · ${review.decision}'), subtitle: Text('${review.reviewedByName}${review.comment.isEmpty ? '' : ' · ${review.comment}'}')))],
            if (canSeeFinance) ...[const Divider(height: 28), const Text('Внутренний расчёт', style: TextStyle(fontWeight: FontWeight.w900)), if (earnings.isEmpty) const Text('Начислений пока нет: нужны явные расценки и распределение вклада сотрудников.'), ...earnings.map((earning) => ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(earning.employeeName), subtitle: Text('${earning.work} · ${earning.contributionPercent}% · ${TaskCompletionReport.formatQuantity(earning.allocatedQuantity)} ${earning.unit} × ${_money(earning.rateAmount)}'), trailing: Text(_money(earning.amount), style: const TextStyle(fontWeight: FontWeight.w900)))), if (issues.isNotEmpty) ...[const SizedBox(height: 10), const Text('Требует ручного решения', style: TextStyle(fontWeight: FontWeight.w900)), ...issues.map((issue) => ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.warning_amber_rounded), title: Text(issue.message)))]]
          ]));
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Закрыть'))],
    ),
  );
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
