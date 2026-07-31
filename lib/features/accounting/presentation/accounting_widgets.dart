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
    final scheme = Theme.of(context).colorScheme;
    return PremiumPressable(
      onTap: onTap,
      pressedScale: 0.975,
      hoverScale: 1.012,
      borderRadius: BorderRadius.circular(28),
      child: PremiumWorkCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
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
                    scheme.primary.withValues(alpha: 0.20),
                    scheme.primary.withValues(alpha: 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: scheme.primary, size: 27),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: accountingText,
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accountingMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: prominent ? background : AppAdaptivePalette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: prominent ? 0.18 : 0.06),
            blurRadius: 20,
            spreadRadius: -12,
            offset: const Offset(0, 12),
          ),
        ],
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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontSize: prominent ? 22 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ],
      ),
    );
  }
}
