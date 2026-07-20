part of '../employee_details_screen.dart';

extension _EmployeeDetailsNavigation on _EmployeeDetailsScreenState {
  Future<void> openEditEmployee() async {
    final updatedEmployee = await Navigator.push<Employee>(
      context,
      CupertinoPageRoute<Employee>(
        builder: (_) => EditEmployeeScreen(employee: employee),
      ),
    );

    if (updatedEmployee == null) return;
    setState(() => employee = updatedEmployee);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Сотрудник обновлён')));
  }

  Future<void> openTimesheet() async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeTimesheetScreen(employee: employee),
      ),
    );
  }

  Future<void> openDocuments() async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeDocumentsScreen(employee: employee),
      ),
    );
  }

  Future<void> openPrivateData() async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeePrivateDataScreen(employee: employee),
      ),
    );
  }

  Future<void> openAddPayment() async {
    final employeeId = employee.id;
    if (employeeId == null || employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('У сотрудника нет ID')));
      return;
    }

    final now = DateTime.now();
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(
        builder: (_) => AddPaymentScreen(
          periodYear: now.year,
          periodMonth: now.month,
          periodTitle: '${monthName(now.month)} ${now.year}',
          initialEmployeeId: employeeId,
        ),
      ),
    );

    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Выплата сохранена')));
  }

  Future<void> openPayments() async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => PaymentHistoryScreen(employee: employee),
      ),
    );
  }

  Future<void> openComments() async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeCommentsScreen(employee: employee),
      ),
    );
  }
}
