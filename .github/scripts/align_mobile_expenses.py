from pathlib import Path

path = Path('lib/features/expenses/presentation/expenses_screen.dart')
source = path.read_text()
start = source.index('  Widget mobileExpenseCard(ExpenseItemData item) {')
end = source.index('  Widget expenseCard(ExpenseItemData item) {', start)
replacement = r'''  Widget mobileExpenseCard(ExpenseItemData item) {
    final objectName = (item.objectName ?? '').trim();
    final responsible = item.counterpartyName.trim();
    final comment = item.comment.trim();
    final meta = <String>[
      formatDate(item.date),
      item.categoryName.trim().isEmpty ? 'Без статьи' : item.categoryName.trim(),
      if (objectName.isNotEmpty) objectName,
      if (!item.isPayment && responsible.isNotEmpty) responsible,
    ];

    return PremiumWorkCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            key: const ValueKey('expense-mobile-header'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  item.isPayment
                      ? Icons.payments_outlined
                      : Icons.receipt_long_outlined,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mobileTitle(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      meta.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 82, maxWidth: 112),
                child: Text(
                  formatMoney(item.amount),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(
                comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.28),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(
              key: const ValueKey('expense-mobile-footer'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: receiptStatus(item),
                  ),
                ),
                const SizedBox(width: 8),
                actionMenu(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

'''
path.write_text(source[:start] + replacement + source[end:])
