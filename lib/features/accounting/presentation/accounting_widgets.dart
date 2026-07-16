import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';

const accountingText = Color(0xFF1F2328);
const accountingMuted = Color(0xFF6B7075);
const accountingSoft = Color(0xFFF0F1F3);

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
              child: Icon(icon, color: const Color(0xFF34383D)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: accountingText,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: accountingText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: accountingMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8F94)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: prominent ? const Color(0xFF202328) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: prominent ? const Color(0xFF202328) : const Color(0xFFE1E2DF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: prominent ? Colors.white70 : accountingMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: prominent ? Colors.white : accountingText,
              fontSize: prominent ? 20 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
