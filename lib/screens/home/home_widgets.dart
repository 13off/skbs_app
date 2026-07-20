part of '../home_screen.dart';

class _ObjectSelectorShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ObjectSelectorShell({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _softCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _text, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.keyboard_arrow_down, color: _text, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ObjectPickerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  const _ObjectPickerTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: isSelected ? _softCard : _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _accent : _line),
          ),
          child: Row(
            children: [
              _IconBox(icon: icon, color: isSelected ? _accent : _text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Редактировать объект',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              if (onArchive != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Архивировать объект',
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined, size: 20),
                ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: _accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String secondaryValue;
  final double progress;
  final String footerTitle;
  final String footerValue;
  final Color footerColor;

  const _DashboardMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.secondaryValue,
    required this.progress,
    required this.footerTitle,
    required this.footerValue,
    required this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    return PremiumWorkCard(
      radius: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: icon, color: _accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 44,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        secondaryValue,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: safeProgress,
                    backgroundColor: const Color(0xFFE8E2DB),
                    valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _softCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: footerColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          footerTitle,
                          style: const TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        footerValue,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  final String title;
  final String objectTitle;
  final FinanceSummaryData finance;
  final bool isLoading;
  final VoidCallback onPeriodTap;

  const _FinanceSummaryCard({
    required this.title,
    required this.objectTitle,
    required this.finance,
    required this.isLoading,
    required this.onPeriodTap,
  });

  String formatMoney(double value) {
    final sign = value < 0 ? '-' : '';
    final text = value.abs().round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$sign$text ₽';
  }

  @override
  Widget build(BuildContext context) {
    final balance = finance.balance;
    final balanceTitle = balance < 0 ? 'Переплата' : 'Осталось';
    final balanceValue = balance < 0 ? balance.abs() : balance;
    final progressPercent = (finance.paidProgress * 100).round();

    return PremiumWorkCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBox(icon: Icons.payments_outlined, color: _accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      objectTitle,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onPeriodTap,
                child: const Text('Период'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MoneyPill(
                title: 'Начислено',
                value: formatMoney(finance.accrued),
              ),
              _MoneyPill(title: 'Выплачено', value: formatMoney(finance.paid)),
              _MoneyPill(title: balanceTitle, value: formatMoney(balanceValue)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: finance.paidProgress,
              backgroundColor: const Color(0xFFE8E2DB),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Закрыто выплатами: $progressPercent%',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MoneyPill extends StatelessWidget {
  final String title;
  final String value;

  const _MoneyPill({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _softCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _SystemMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
