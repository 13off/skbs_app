import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../models/employee.dart';
import '../../../models/monthly_timesheet_row.dart';

class AccountingRepository {
  static Future<AccountingDashboardData> fetchDashboard({
    DateTime? month,
    bool forceRefresh = false,
  }) async {
    final sourceMonth = month ?? DateTime.now();
    final targetMonth = DateTime(sourceMonth.year, sourceMonth.month, 1);

    final employees = await EmployeeRepository.fetchEmployees(
      includeFired: true,
      forceRefresh: forceRefresh,
    );
    final rows = await AttendanceRepository.fetchMonthlyTimesheet(
      year: targetMonth.year,
      month: targetMonth.month,
      includeFired: true,
      forceRefresh: forceRefresh,
    );

    final employeeById = <String, Employee>{};
    final employeeIds = <String>[];
    for (final employee in employees) {
      final id = employee.id?.trim();
      if (id == null || id.isEmpty) continue;
      employeeById[id] = employee;
      employeeIds.add(id);
    }

    final payments = await PaymentRepository.fetchPaymentsForEmployees(
      employeeIds,
      forceRefresh: forceRefresh,
    );
    final monthPayments = payments.where((payment) {
      return payment.periodYear == targetMonth.year &&
          payment.periodMonth == targetMonth.month;
    }).toList();

    final missingReceipts = monthPayments
        .where((payment) => payment.receipts.isEmpty)
        .map((payment) {
          final employee = employeeById[payment.employeeId];
          return AccountingMissingReceipt(
            paymentId: payment.id,
            employeeId: payment.employeeId,
            employeeName: employee?.name ?? 'Сотрудник',
            objectName: employee?.objectName ?? '',
            amount: payment.amount,
            paymentDate: payment.paymentDate,
            paymentType: payment.paymentType,
          );
        })
        .toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    final balances = rows.where((row) => row.balance > 0.009).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    final totalAccrued = rows.fold<double>(
      0,
      (sum, row) => sum + row.accrued,
    );
    final totalPaid = rows.fold<double>(0, (sum, row) => sum + row.paid);

    return AccountingDashboardData(
      month: targetMonth,
      totalAccrued: totalAccrued,
      totalPaid: totalPaid,
      totalBalance: totalAccrued - totalPaid,
      employeeCount: rows.length,
      employeesWithBalance: balances.length,
      paymentCount: monthPayments.length,
      missingReceiptCount: missingReceipts.length,
      largestBalances: balances.take(6).toList(),
      missingReceipts: missingReceipts.take(8).toList(),
    );
  }

  static Future<List<AccountingPaymentRegisterRow>> fetchPaymentRegister({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    final employees = await EmployeeRepository.fetchEmployees(
      includeFired: true,
      forceRefresh: forceRefresh,
    );
    final employeeById = <String, Employee>{};
    final employeeIds = <String>[];

    for (final employee in employees) {
      final id = employee.id?.trim();
      if (id == null || id.isEmpty) continue;
      employeeById[id] = employee;
      employeeIds.add(id);
    }

    final payments = await PaymentRepository.fetchPaymentsForEmployees(
      employeeIds,
      forceRefresh: forceRefresh,
    );
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    final rows = payments.where((payment) {
      return !payment.paymentDate.isBefore(start) &&
          !payment.paymentDate.isAfter(end);
    }).map((payment) {
      final employee = employeeById[payment.employeeId];
      return AccountingPaymentRegisterRow(
        paymentId: payment.id,
        employeeName: employee?.name ?? 'Сотрудник',
        objectName: employee?.objectName ?? '',
        paymentDate: payment.paymentDate,
        amount: payment.amount,
        paymentType: payment.paymentType,
        comment: payment.comment,
        receiptCount: payment.receipts.length,
      );
    }).toList()
      ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

    return rows;
  }
}

class AccountingDashboardData {
  final DateTime month;
  final double totalAccrued;
  final double totalPaid;
  final double totalBalance;
  final int employeeCount;
  final int employeesWithBalance;
  final int paymentCount;
  final int missingReceiptCount;
  final List<MonthlyTimesheetRow> largestBalances;
  final List<AccountingMissingReceipt> missingReceipts;

  const AccountingDashboardData({
    required this.month,
    required this.totalAccrued,
    required this.totalPaid,
    required this.totalBalance,
    required this.employeeCount,
    required this.employeesWithBalance,
    required this.paymentCount,
    required this.missingReceiptCount,
    required this.largestBalances,
    required this.missingReceipts,
  });
}

class AccountingMissingReceipt {
  final String paymentId;
  final String employeeId;
  final String employeeName;
  final String objectName;
  final double amount;
  final DateTime paymentDate;
  final String paymentType;

  const AccountingMissingReceipt({
    required this.paymentId,
    required this.employeeId,
    required this.employeeName,
    required this.objectName,
    required this.amount,
    required this.paymentDate,
    required this.paymentType,
  });
}

class AccountingPaymentRegisterRow {
  final String paymentId;
  final String employeeName;
  final String objectName;
  final DateTime paymentDate;
  final double amount;
  final String paymentType;
  final String comment;
  final int receiptCount;

  const AccountingPaymentRegisterRow({
    required this.paymentId,
    required this.employeeName,
    required this.objectName,
    required this.paymentDate,
    required this.amount,
    required this.paymentType,
    required this.comment,
    required this.receiptCount,
  });
}
