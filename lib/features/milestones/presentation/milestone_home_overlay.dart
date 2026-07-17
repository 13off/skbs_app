import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';
import 'milestone_detail_screen.dart';
import 'milestones_screen.dart';

class MilestoneHomeSection extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const MilestoneHomeSection({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<MilestoneHomeSection> createState() => _MilestoneHomeSectionState();
}

class _MilestoneHomeSectionState extends State<MilestoneHomeSection> {
  late Future<List<ProjectMilestone>> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void didUpdateWidget(covariant MilestoneHomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      future = load();
    }
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

  Future<void> openMilestones() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => MilestonesScreen(
          profile: widget.profile,
          selectedObjectName: effectiveObject,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> openMilestone(ProjectMilestone milestone) async {
    await Navigator.of(context).push<void>(
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

  String shortDate(ProjectMilestone milestone) {
    final value = milestone.targetDate;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  Widget milestoneCard(ProjectMilestone milestone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: () => openMilestone(milestone),
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  shortDate(milestone),
                  style: const TextStyle(
                    color: Color(0xFF1F2328),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2328),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      milestone.location.trim().isEmpty
                          ? milestone.objectName
                          : '${milestone.objectName} · ${milestone.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7075),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: milestone.progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE5E7EA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${milestone.progressPercent}%',
                style: const TextStyle(
                  color: Color(0xFF1F2328),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin && !widget.profile.isForeman) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<ProjectMilestone>>(
      future: future,
      builder: (context, snapshot) {
        final source = snapshot.data ?? const <ProjectMilestone>[];
        final active = source.where((item) => !item.isCompleted).toList();
        final visible = active.take(4).toList();
        final hiddenCount = active.length - visible.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Цели',
                    style: TextStyle(
                      color: Color(0xFF1F2328),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: openMilestones,
                  child: const Text('Все цели'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const PremiumWorkCard(
                radius: 22,
                padding: EdgeInsets.all(18),
                child: LinearProgressIndicator(),
              )
            else if (snapshot.hasError)
              PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(child: Text('Не удалось загрузить цели')),
                    TextButton(
                      onPressed: refresh,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              )
            else if (visible.isEmpty)
              PremiumPressable(
                onTap: openMilestones,
                borderRadius: BorderRadius.circular(22),
                child: const PremiumWorkCard(
                  radius: 22,
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Активных целей пока нет',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        'Открыть',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...visible.map(milestoneCard),
              if (hiddenCount > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: openMilestones,
                    child: Text('Ещё целей: $hiddenCount'),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
