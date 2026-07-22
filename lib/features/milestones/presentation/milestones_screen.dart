import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';
import 'milestone_detail_screen.dart';
import 'milestone_editor_dialog.dart';

class MilestonesScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const MilestonesScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late Future<List<ProjectMilestone>> future;
  bool showCompleted = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  String? cleanObject(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String? get effectiveObject =>
      cleanObject(widget.selectedObjectName) ??
      (widget.profile.isForeman
          ? cleanObject(widget.profile.objectName)
          : null);

  Future<List<ProjectMilestone>> load() {
    return MilestoneRepository.fetchMilestones(objectName: effectiveObject);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> createMilestone() async {
    final draft = await showDialog<MilestoneCreateDraft>(
      context: context,
      builder: (_) => MilestoneEditorDialog(
        profile: widget.profile,
        selectedObjectName: effectiveObject,
      ),
    );
    if (draft == null) return;

    await MilestoneRepository.createMilestone(
      objectName: draft.objectName,
      title: draft.title,
      location: draft.location,
      targetDate: draft.targetDate,
      notes: draft.notes,
      checklist: draft.checklist,
    );
    if (mounted) await refresh();
  }

  Future<void> openMilestone(ProjectMilestone milestone) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => MilestoneDetailScreen(
          profile: widget.profile,
          milestoneId: milestone.id,
          objectName: milestone.objectName,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  String date(ProjectMilestone milestone) {
    final value = milestone.targetDate;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String remaining(ProjectMilestone milestone) {
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final target = DateTime(
      milestone.targetDate.year,
      milestone.targetDate.month,
      milestone.targetDate.day,
    );
    final days = target.difference(cleanToday).inDays;
    if (days == 0) return 'Сегодня';
    if (days == 1) return 'Завтра';
    if (days > 1) return 'Через $days дн.';
    return 'Просрочено на ${days.abs()} дн.';
  }

  Color statusColor(ProjectMilestone milestone) {
    if (milestone.isCompleted) return const Color(0xFF2E7D52);
    if (milestone.status == 'postponed') return const Color(0xFF9A403A);
    return const Color(0xFF6B7075);
  }

  Widget milestoneCard(ProjectMilestone milestone) {
    final accent = statusColor(milestone);
    return PremiumPressable(
      onTap: () => openMilestone(milestone),
      borderRadius: BorderRadius.circular(26),
      child: PremiumWorkCard(
        radius: 26,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        milestone.targetDate.day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        milestone.targetDate.month.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              milestone.title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestone.location.trim().isEmpty
                            ? milestone.objectName
                            : '${milestone.objectName} · ${milestone.location}',
                        style: const TextStyle(
                          color: Color(0xFF6B7075),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(label: milestone.statusTitle, color: accent),
                          _Pill(label: remaining(milestone), color: accent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: milestone.progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE5E7EA),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${milestone.progressPercent}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Готово ${milestone.doneItems} из ${milestone.items.length} пунктов · '
              'задачи ${milestone.doneTaskCount} из ${milestone.linkedTaskCount}',
              style: const TextStyle(
                color: Color(0xFF6B7075),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Цели'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<ProjectMilestone>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 10),
                    Text('Не удалось загрузить этапы: ${snapshot.error}'),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: refresh,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final source = snapshot.data ?? const <ProjectMilestone>[];
          final milestones = source
              .where((item) => showCompleted || !item.isCompleted)
              .toList();

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1060),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Активные цели',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilterChip(
                              selected: showCompleted,
                              label: const Text('Выполненные'),
                              onSelected: (value) {
                                setState(() => showCompleted = value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (milestones.isEmpty)
                          PremiumWorkCard(
                            radius: 28,
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              children: [
                                const Icon(Icons.flag_outlined, size: 46),
                                const SizedBox(height: 12),
                                const Text(
                                  'Целей пока нет',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: createMilestone,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Добавить этап'),
                                ),
                              ],
                            ),
                          )
                        else
                          ...milestones.map(
                            (milestone) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: milestoneCard(milestone),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createMilestone,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новый этап'),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
