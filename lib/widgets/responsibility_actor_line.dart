import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../models/responsibility_actor.dart';

class ResponsibilityActorLine extends StatelessWidget {
  final String label;
  final ResponsibilityActor actor;
  final bool showTime;
  final bool compact;

  const ResponsibilityActorLine({
    super.key,
    required this.label,
    required this.actor,
    this.showTime = true,
    this.compact = false,
  });

  List<String> get _nameParts => actor.fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  String get _initials {
    final parts = _nameParts.take(2).toList(growable: false);
    if (parts.isEmpty) return '?';
    return parts.map((part) => part.characters.first.toUpperCase()).join();
  }

  String get _shortName {
    final parts = _nameParts;
    if (parts.isEmpty) return 'Неизвестно';
    if (parts.length == 1) return parts.first;
    // В профилях AppСтрой ФИО хранится как «Фамилия Имя Отчество».
    // В подсказке оставляем только «Имя Фамилия».
    return '${parts[1]} ${parts[0]}';
  }

  String? get _timeText {
    if (!showTime || actor.actedAt == null) return null;
    return DateFormat('dd.MM HH:mm').format(actor.actedAt!);
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 22.0 : 26.0;
    final timeText = _timeText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _shortName,
          triggerMode: TooltipTriggerMode.tap,
          waitDuration: Duration.zero,
          showDuration: const Duration(seconds: 3),
          preferBelow: false,
          verticalOffset: 14,
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppAdaptivePalette.border),
          ),
          textStyle: TextStyle(
            color: AppAdaptivePalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          child: _InitialsAvatar(initials: _initials, size: avatarSize),
        ),
        SizedBox(width: compact ? 6 : 8),
        Flexible(
          child: Text(
            timeText == null ? label : '$label · $timeText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const _InitialsAvatar({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppAdaptivePalette.textPrimary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
