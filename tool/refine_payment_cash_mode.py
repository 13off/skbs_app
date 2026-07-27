from pathlib import Path

path = Path('lib/features/payments/presentation/screens/payments_screen.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global text
    if old not in text:
        raise SystemExit(f'Marker not found: {old[:140]!r}')
    text = text.replace(old, new, 1)


replace_once(
    """        rows = buildPaymentRows(
          periodRows,
          paidByEmployeeId,
          paymentEmployees: scopedEmployees,
        );
""",
    """        rows = buildPaymentRows(
          mode == _PaymentAccountingMode.settlementPeriod
              ? periodRows
              : const <PeriodTimesheetRow>[],
          paidByEmployeeId,
          paymentEmployees: scopedEmployees,
        );
""",
)

replace_once(
    """          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneySummaryItem(
                  title: 'Начислено',
                  value: formatMoney(totalAccrued),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneySummaryItem(
                  title: 'Выплачено',
                  value: formatMoney(totalPaid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MoneySummaryItem(
            title: totalBalance >= 0 ? 'Остаток' : 'Переплата',
            value: formatMoney(totalBalance.abs()),
          ),
""",
    """          const SizedBox(height: 12),
          if (accountingMode == _PaymentAccountingMode.paymentDate)
            _MoneySummaryItem(
              title: 'Фактически выплачено',
              value: formatMoney(totalPaid),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MoneySummaryItem(
                    title: 'Начислено',
                    value: formatMoney(totalAccrued),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneySummaryItem(
                    title: 'Выплачено за период',
                    value: formatMoney(totalPaid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MoneySummaryItem(
              title: totalBalance >= 0 ? 'Остаток' : 'Переплата',
              value: formatMoney(totalBalance.abs()),
            ),
          ],
""",
)

replace_once(
    """          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MoneyLine(
                  title: 'Начислено',
                  value: formatMoney(row.accrued),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoneyLine(
                  title: 'Выплачено',
                  value: formatMoney(row.paid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MoneyLine(
            title: balanceTitle,
            value: formatMoney(balance.abs()),
            valueColor: balanceColor,
          ),
""",
    """          const SizedBox(height: 14),
          if (accountingMode == _PaymentAccountingMode.paymentDate)
            _MoneyLine(
              title: 'Фактически выплачено',
              value: formatMoney(row.paid),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MoneyLine(
                    title: 'Начислено',
                    value: formatMoney(row.accrued),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyLine(
                    title: 'Выплачено за период',
                    value: formatMoney(row.paid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MoneyLine(
              title: balanceTitle,
              value: formatMoney(balance.abs()),
              valueColor: balanceColor,
            ),
          ],
""",
)

path.write_text(text, encoding='utf-8')

test_path = Path('test/payment_settlement_period_contract_test.dart')
test = test_path.read_text(encoding='utf-8')
marker = """    expect(screen, contains(\"label: const Text('По дате выплаты')\"));
"""
replacement = marker + """    expect(screen, contains(\"title: 'Фактически выплачено'\"));
    expect(
      screen,
      contains('mode == _PaymentAccountingMode.settlementPeriod'),
    );
"""
if marker not in test:
    raise SystemExit('Test marker not found')
test_path.write_text(test.replace(marker, replacement, 1), encoding='utf-8')
