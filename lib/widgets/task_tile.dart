import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';

import '../models/task_item_data.dart';
import 'premium_ui_v2.dart';
import 'responsibility_actor_line.dart';

Color get _taskText => AppAdaptivePalette.textPrimary;
Color get _taskMuted => AppAdaptivePalette.textMuted;
Color get _taskSoft => AppAdaptivePalette.surfaceSoft;
Color get _taskLine => AppAdaptivePalette.border;

class TaskTile extends StatelessWidget {
  final TaskItemData task;
  final VoidCallback onTap;

  const TaskTile({super.key, required this.task, required this.onTap});

  Color get statusColor {
    switch (task.status) {
      case 'Выполнено':
        return const Color(0xFF66766A);
      case 'Запланировано':
        return const Color(0xFF66717C);
      default:
        return const Color(0xFF6E6762);
    }
  }

  IconData get statusIcon {
    switch (task.status) {
      case 'Выполнено':
        return Icons.check_rounded;
      case 'Запланировано':
        return Icons.schedule_rounded;
      default:
        return Icons.construction_rounded;
    }
  }

  bool get _sameResponsibleActor {
    final creator = task.creator;
    final editor = task.lastEditor;
    if (creator == null || editor == null) return false;

    final creatorId = creator.userId?.trim() ?? '';
    final editorId = editor.userId?.trim() ?? '';
    if (creatorId.isNotEmpty && editorId.isNotEmpty) {
      return creatorId == editorId;
    }

    final creatorName = creator.fullName.trim().toLowerCase();
    final editorName = editor.fullName.trim().toLowerCase();
    return creatorName.isNotEmpty && creatorName == editorName;
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor;
    final creator = task.creator;
    final editor = task.lastEditor;
    final sameResponsibleActor = _sameResponsibleActor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _taskSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _taskLine),
                ),
                child: Icon(
                  Icons.architecture_outlined,
                  color: _taskText,
                  size: 22,
                ),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.axes,
                      style: TextStyle(
                        color: _taskText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      task.work,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _taskMuted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (creator != null || editor != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 7,
                        children: [
                          if (sameResponsibleActor && editor != null)
                            ResponsibilityActorLine(
                              label: 'Создал и изменил',
                              actor: editor,
                              compact: true,
                            )
                          else ...[
                            if (creator != null)
                              ResponsibilityActorLine(
                                label: 'Создал',
                                actor: creator,
                                compact: true,
                              ),
                            if (editor != null)
                              ResponsibilityActorLine(
                                label: 'Изменил',
                                actor: editor,
                                compact: true,
                              ),
                          ],
                        ],
                      ),
                    ],
                    SizedBox(height: 11),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: color.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: color, size: 15),
                          SizedBox(width: 6),
                          Text(
                            task.status,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right_rounded, color: _taskMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
