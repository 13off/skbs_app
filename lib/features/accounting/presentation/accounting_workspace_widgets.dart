import 'package:flutter/material.dart';

import '../../shared/presentation/specialist_desktop_ui.dart';
import '../../../widgets/premium_ui.dart';

class AccountingSectionSwitcher extends StatelessWidget {
  final String selected;
  final List<(String, String, IconData)> items;
  final ValueChanged<String> onChanged;

  const AccountingSectionSwitcher({
    super.key,
    required this.selected,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: items
                .map(
                  (item) => ButtonSegment<String>(
                    value: item.$1,
                    label: Text(item.$2),
                    icon: Icon(item.$3),
                  ),
                )
                .toList(growable: false),
            selected: <String>{selected},
            onSelectionChanged: (values) {
              if (values.isNotEmpty) onChanged(values.first);
            },
          ),
        ),
      ),
    );
  }
}

class SpecialistDesktopSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const SpecialistDesktopSection({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: specialistMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class AccountingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const AccountingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SpecialistMessageCard(
      icon: icon,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class AccountingStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AccountingStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String accountingDocStatusLabel(String status) {
  return switch (status) {
    'draft' => 'Черновик',
    'ready' => 'Готов',
    'posted' => 'Проведён',
    'attention' => 'Требует внимания',
    _ => status,
  };
}

Color accountingDocStatusColor(String status) {
  return switch (status) {
    'posted' => specialistSuccess,
    'attention' => specialistDanger,
    'ready' => specialistWarning,
    _ => specialistMuted,
  };
}
