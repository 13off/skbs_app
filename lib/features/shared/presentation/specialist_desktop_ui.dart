import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';

const double specialistDesktopBreakpoint = 1050;
const Color specialistText = Color(0xFF1F2328);
const Color specialistMuted = Color(0xFF6B7075);
const Color specialistLine = Color(0xFFE3E5E8);
const Color specialistSoft = Color(0xFFF1F2F4);
const Color specialistSuccess = Color(0xFF2E7D52);
const Color specialistWarning = Color(0xFF9A6816);
const Color specialistDanger = Color(0xFF9A403A);

class SpecialistDesktopPage extends StatelessWidget {
  final String storageKey;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  const SpecialistDesktopPage({
    super.key,
    required this.storageKey,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      key: PageStorageKey<String>(storageKey),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: title,
                  subtitle: subtitle,
                  trailing: trailing,
                ),
                const SizedBox(height: 18),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );

    return PremiumWorkBackdrop(
      child: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
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
    final content = PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (accent ?? specialistMuted).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent ?? specialistText),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: specialistText,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: specialistText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hint != null && hint!.trim().isNotEmpty)
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: specialistMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: specialistMuted),
        ],
      ),
    );

    if (onTap == null) return content;
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
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
    final effective = color ?? specialistMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: effective.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effective),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: effective,
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 42, color: specialistMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: specialistText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: specialistMuted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

Widget specialistCellText(
  String value, {
  Color color = specialistText,
  FontWeight weight = FontWeight.w700,
  int maxLines = 2,
}) {
  return Text(
    value.trim().isEmpty ? '—' : value,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: color, fontWeight: weight, height: 1.25),
  );
}
