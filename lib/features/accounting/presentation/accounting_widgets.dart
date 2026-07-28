import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';

Color get accountingText => AppAdaptivePalette.textPrimary;
Color get accountingMuted => AppAdaptivePalette.textMuted;
Color get accountingSoft => AppAdaptivePalette.surfaceSoft;

String accountingMoney(num value) {
  final text = value.round().toString();
  final formatted = text.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '$formatted ₽';
}

String accountingMonth(DateTime month) {
  const names = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

String accountingDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

class AccountingMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  const AccountingMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23),
      child: PremiumWorkCard(
        radius: 23,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: accountingSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accountingText),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: accountingText,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: accountingText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: accountingMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppAdaptivePalette.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class AccountingMoneyBlock extends StatelessWidget {
  final String title;
  final String value;
  final bool prominent;

  const AccountingMoneyBlock({
    super.key,
    required this.title,
    required this.value,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = prominent
        ? scheme.inverseSurface
        : AppAdaptivePalette.surfaceElevated;
    final foreground = prominent ? scheme.onInverseSurface : accountingText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: prominent ? background : AppAdaptivePalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: prominent
                  ? foreground.withValues(alpha: 0.72)
                  : accountingMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontSize: prominent ? 20 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
