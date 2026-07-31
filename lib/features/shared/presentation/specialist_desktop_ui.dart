import 'package:flutter/material.dart';
import 'package:skbs_app/app/app_adaptive_palette.dart';

import '../../../app/app_ui_tokens.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';

const double specialistDesktopBreakpoint = AppUi.specialistDesktopBreakpoint;
Color get specialistText => AppAdaptivePalette.textPrimary;
Color get specialistMuted => AppAdaptivePalette.textMuted;
Color get specialistLine => AppAdaptivePalette.border;
Color get specialistSoft => AppAdaptivePalette.surfaceSoft;
Color get specialistSuccess => AppAdaptivePalette.success;
Color get specialistWarning => AppAdaptivePalette.warning;
Color get specialistDanger => AppAdaptivePalette.danger;

class SpecialistDesktopPage extends StatelessWidget {
  final String storageKey;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool showBackButton;
  final VoidCallback? onBack;

  const SpecialistDesktopPage({
    super.key,
    required this.storageKey,
    required this.title,
    this.subtitle = '',
    required this.children,
    this.trailing,
    this.onRefresh,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      scrollKey: PageStorageKey<String>(storageKey),
      title: title,
      headerTrailing: trailing,
      showBackButton: showBackButton,
      onBack: onBack,
      onRefresh: onRefresh,
      maxContentWidth: AppUi.specialistContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class SpecialistMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final VoidCallback? onTap;
  final Color? accent;

  const SpecialistMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveAccent = accent ?? scheme.primary;
    final content = PremiumWorkCard(
      radius: AppUi.cardRadius,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effectiveAccent.withValues(alpha: 0.22),
                  effectiveAccent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: effectiveAccent.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icon, color: effectiveAccent, size: 27),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.55,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUi.cardRadius),
      pressedScale: 0.975,
      hoverScale: 1.012,
      child: content,
    );
  }
}

class SpecialistStatusPill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const SpecialistStatusPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: effective.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: effective),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: effective,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class SpecialistMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool loading;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const SpecialistMessageCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: AppUi.modalRadius,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Widget specialistCellText(
  String value, {
  Color? color,
  FontWeight weight = FontWeight.w700,
  int maxLines = 2,
}) {
  return Builder(
    builder: (context) => Text(
      value.trim().isEmpty ? '—' : value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontWeight: weight,
        height: 1.25,
      ),
    ),
  );
}
