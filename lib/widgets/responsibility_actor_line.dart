import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../models/responsibility_actor.dart';
import '../services/profile_avatar_service.dart';

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

  String get _initials {
    final parts = actor.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    return parts.map((part) => part.characters.first.toUpperCase()).join();
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
        _ActorAvatar(
          avatarPath: actor.avatarPath,
          initials: _initials,
          size: avatarSize,
        ),
        SizedBox(width: compact ? 6 : 8),
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                  text: actor.fullName.isEmpty ? 'Неизвестно' : actor.fullName,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (timeText != null) TextSpan(text: ' · $timeText'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  final String? avatarPath;
  final String initials;
  final double size;

  const _ActorAvatar({
    required this.avatarPath,
    required this.initials,
    required this.size,
  });

  Widget _fallback() {
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

  @override
  Widget build(BuildContext context) {
    final path = avatarPath?.trim() ?? '';
    if (path.isEmpty) return _fallback();

    return FutureBuilder<String?>(
      future: ProfileAvatarService.signedUrl(path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return _fallback();
        return ClipOval(
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (_, _, _) => _fallback(),
          ),
        );
      },
    );
  }
}
