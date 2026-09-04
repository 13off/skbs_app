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
    );
  }
}

class AccountingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
