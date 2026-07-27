from pathlib import Path

path = Path('lib/features/payments/presentation/screens/payments_screen.dart')
text = path.read_text(encoding='utf-8')
old = """      final paidValue =
          employeeId.isNotEmpty && appliedPaymentIds.add(employeeId)
          ? paidByEmployeeId[employeeId] ?? 0
          : 0;
"""
new = """      final paidValue =
          employeeId.isNotEmpty && appliedPaymentIds.add(employeeId)
          ? paidByEmployeeId[employeeId] ?? 0.0
          : 0.0;
"""
if old not in text:
    raise SystemExit('Paid value marker not found')
text = text.replace(old, new, 1)
old = """      if (employeeId.isEmpty || appliedPaymentIds.contains(employeeId))
        continue;
"""
new = """      if (employeeId.isEmpty || appliedPaymentIds.contains(employeeId)) {
        continue;
      }
"""
if old not in text:
    raise SystemExit('Curly braces marker not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
