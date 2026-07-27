from pathlib import Path
import re

path = Path('lib/features/payments/presentation/screens/payments_screen.dart')
source = path.read_text(encoding='utf-8')
pattern = re.compile(
    r"  Widget buildDesktopPaymentsBody\(List<_PaymentDisplayRow> visibleRows\) \{.*?\n  \}\n\n  @override",
    re.S,
)
replacement = r'''  Widget buildDesktopPaymentsBody(List<_PaymentDisplayRow> visibleRows) {
    final leading = <Widget>[
      buildMonthPanel(),
      const SizedBox(height: 18),
      buildDesktopSummaryPanel(),
      const SizedBox(height: 18),
      buildSearch(),
      const SizedBox(height: 14),
      ...buildPaymentStatus(visibleRows),
    ];
    final rowCount = isLoading && visibleRows.isEmpty ? 0 : visibleRows.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => loadPaymentsData(forceRefresh: true),
                child: ListView.builder(
                  // Flutter 3.44 deprecates this field before exposing its replacement.
                  // ignore: deprecated_member_use
                  cacheExtent: 800,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 22, 0, 132),
                  itemCount: leading.length + rowCount,
                  itemBuilder: (context, index) {
                    final child = index < leading.length
                        ? leading[index]
                        : buildPaymentCard(
                            visibleRows[index - leading.length],
                          );
                    return RepaintBoundary(child: child);
                  },
                ),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 22, 28, 132),
                children: [
                  buildPaymentFilters(),
                  const SizedBox(height: 14),
                  PremiumWorkCard(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountingMode ==
                                  _PaymentAccountingMode.settlementPeriod
                              ? 'Расчётный учёт'
                              : 'Движение денег',
                          style: TextStyle(
                            color: AppAdaptivePalette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          accountingMode ==
                                  _PaymentAccountingMode.settlementPeriod
                              ? 'Выплаты относятся к выбранному месяцу независимо от даты выдачи денег.'
                              : 'Показываются только деньги, фактически выданные за выбранные даты.',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
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
      ),
    );
  }

  @override'''
updated, count = pattern.subn(replacement, source, count=1)
if count != 1:
    raise SystemExit(f'desktop body replacements: {count}')
path.write_text(updated, encoding='utf-8')
