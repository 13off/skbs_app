import 'package:flutter/material.dart';

import '../../../../app/app_adaptive_palette.dart';
import '../../../../widgets/premium_ui.dart';
import '../../data/absence_fine_repository.dart';

class PendingAbsenceFinesCard extends StatefulWidget {
  final Future<void> Function()? onChanged;

  const PendingAbsenceFinesCard({super.key, this.onChanged});

  @override
  State<PendingAbsenceFinesCard> createState() => _PendingAbsenceFinesCardState();
}

class _PendingAbsenceFinesCardState extends State<PendingAbsenceFinesCard> {
  Future<List<AbsenceFineItem>>? future;
  final Set<String> busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    future = AbsenceFineRepository.fetchPending();
  }

  Future<void> reload() async {
    final next = AbsenceFineRepository.fetchPending();
    if (mounted) setState(() => future = next);
    await next;
  }

  String money(num value) {
    return '${value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ')} ₽';
  }

  String date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Future<void> attachExplanation(AbsenceFineItem fine) async {
    if (busyIds.contains(fine.id)) return;
    setState(() => busyIds.add(fine.id));
    try {
      final file = await AbsenceFineRepository.pickDocument();
      if (file == null || !mounted) return;
      await AbsenceFineRepository.uploadExplanation(fine: fine, file: file);
      if (mounted) await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прикрепить объяснительную: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(fine.id));
    }
  }

  Future<void> attachAct(AbsenceFineItem fine) async {
    if (busyIds.contains(fine.id)) return;
    setState(() => busyIds.add(fine.id));
    try {
      final file = await AbsenceFineRepository.pickDocument();
      if (file == null || !mounted) return;
      await AbsenceFineRepository.uploadAct(fine: fine, file: file);
      if (mounted) await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прикрепить акт о нарушении: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(fine.id));
    }
  }

  Future<void> confirm(AbsenceFineItem fine) async {
    if (!fine.canConfirm || busyIds.contains(fine.id)) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Подтвердить штраф?'),
        content: Text(
          '${fine.employeeName}\nНевыход: ${date(fine.absenceDate)}\nШтраф: ${money(fine.amount)}\n\nОбъяснительная и подписанный акт приложены. После подтверждения штраф попадёт в выплаты.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() => busyIds.add(fine.id));
    try {
      await AbsenceFineRepository.confirm(fine);
      await reload();
      if (widget.onChanged != null) await widget.onChanged!();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Штраф ${money(fine.amount)} добавлен в выплаты')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось подтвердить штраф: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(fine.id));
    }
  }

  Widget documentRow({
    required bool attached,
    required String attachedText,
    required String missingText,
  }) {
    return Row(
      children: [
        Icon(
          attached ? Icons.description_rounded : Icons.pending_actions_rounded,
          size: 17,
          color: attached ? AppAdaptivePalette.success : AppAdaptivePalette.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            attached ? attachedText : missingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: attached
                  ? AppAdaptivePalette.textPrimary
                  : AppAdaptivePalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AbsenceFineItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return PremiumWorkCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppAdaptivePalette.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Не удалось загрузить неподтверждённые штрафы',
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
          );
        }

        final items = snapshot.data ?? const <AbsenceFineItem>[];
        if (items.isEmpty) return const SizedBox.shrink();

        return PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel_rounded, color: AppAdaptivePalette.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Неподтверждённые штрафы',
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppAdaptivePalette.accentSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: AppAdaptivePalette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Штраф уже отмечен, но в расчёт выплат попадёт только после двух документов: объяснительной и подписанного акта о нарушении.',
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...items.map((fine) {
                final busy = busyIds.contains(fine.id);
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppAdaptivePalette.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fine.employeeName,
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${fine.objectName} • невыход ${date(fine.absenceDate)}',
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            money(fine.amount),
                            style: TextStyle(
                              color: AppAdaptivePalette.danger,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      documentRow(
                        attached: fine.hasExplanation,
                        attachedText: 'Объяснительная: ${fine.explanationFileName}',
                        missingText: 'Объяснительная не приложена',
                      ),
                      const SizedBox(height: 7),
                      documentRow(
                        attached: fine.hasAct,
                        attachedText: 'Акт о нарушении: ${fine.actFileName}',
                        missingText: 'Подписанный акт о нарушении не приложен',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => attachExplanation(fine),
                            icon: const Icon(Icons.attach_file_rounded, size: 18),
                            label: Text(
                              fine.hasExplanation
                                  ? 'Заменить объяснительную'
                                  : 'Прикрепить объяснительную',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => attachAct(fine),
                            icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                            label: Text(
                              fine.hasAct
                                  ? 'Заменить акт'
                                  : 'Прикрепить акт',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: !fine.canConfirm || busy
                                ? null
                                : () => confirm(fine),
                            icon: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Подтвердить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
