import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/milestone_repository.dart';
import '../models/milestone_models.dart';
import 'milestones_screen.dart';

class MilestoneHomeOverlay extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final Widget child;

  const MilestoneHomeOverlay({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.child,
  });

  @override
  State<MilestoneHomeOverlay> createState() => _MilestoneHomeOverlayState();
}

class _MilestoneHomeOverlayState extends State<MilestoneHomeOverlay> {
  late Future<ProjectMilestone?> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void didUpdateWidget(covariant MilestoneHomeOverlay oldWidget) {
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

  Future<ProjectMilestone?> load() {
    return MilestoneRepository.fetchNearest(
      objectName: cleanObject(widget.selectedObjectName) ??
          (widget.profile.isForeman
              ? cleanObject(widget.profile.objectName)
              : null),
    );
  }

  Future<void> openMilestones() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => MilestonesScreen(
          profile: widget.profile,
          selectedObjectName: cleanObject(widget.selectedObjectName) ??
              (widget.profile.isForeman
                  ? cleanObject(widget.profile.objectName)
                  : null),
        ),
      ),
    );
    if (mounted) setState(() => future = load());
  }

  String date(ProjectMilestone milestone) {
    final value = milestone.targetDate;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isAdmin && !widget.profile.isForeman) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: MediaQuery.sizeOf(context).width >= 1050 ? 28 : 12,
          right: MediaQuery.sizeOf(context).width >= 1050 ? null : 12,
          bottom: MediaQuery.sizeOf(context).width >= 1050 ? 20 : 82,
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width >= 1050 ? 430 : null,
              child: FutureBuilder<ProjectMilestone?>(
                future: future,
                builder: (context, snapshot) {
                  final milestone = snapshot.data;
                  return PremiumPressable(
                    onTap: openMilestones,
                    borderRadius: BorderRadius.circular(24),
                    child: Material(
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E4E7)),
                        ),
                        child: snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData
                            ? const SizedBox(
                                height: 54,
                                child: Center(
                                  child: LinearProgressIndicator(),
                                ),
                              )
                            : milestone == null
                                ? const Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Color(0xFFF0F1F3),
                                        child: Icon(Icons.flag_outlined),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ключевые этапы',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              'Добавить первую контрольную цель',
                                              style: TextStyle(
                                                color: Color(0xFF6B7075),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.add_circle_outline_rounded),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F1F3),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: Text(
                                          date(milestone),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              milestone.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              milestone.location.trim().isEmpty
                                                  ? milestone.objectName
                                                  : milestone.location,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF6B7075),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              child: LinearProgressIndicator(
                                                minHeight: 7,
                                                value: milestone.progress,
                                                backgroundColor:
                                                    const Color(0xFFE5E7EA),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${milestone.progressPercent}%',
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
