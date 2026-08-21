// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../employee_details_screen.dart';

extension _EmployeeDetailsNavigation on _EmployeeDetailsScreenState {
  Future<void> openEditEmployee() async {
    final updatedEmployee = await Navigator.push<Employee>(
      context,
      AppPageRoute<Employee>(
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

  Future<void> openProfessionalPassport() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) =>
            EmployeeProfessionalPassportViewerScreen(employee: employee),
      ),
    );
  }

  Future<void> openContribution() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => EmployeeContributionScreen(employee: employee),
      ),
    );
  }

  Future<void> openTimesheet() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => EmployeeTimesheetScreen(employee: employee),
      ),
    );
  }

  Future<void> openDocuments() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => DocumentToolProtectedScreen(
          companyId: widget.profile.activeCompanyId,
          title: 'Документы',
          toolsScreen: CompanyToolsScreen(profile: widget.profile),
          child: EmployeeDocumentsScreen(employee: employee),
        ),
      ),
    );
  }

  Future<void> openPrivateData() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => DocumentToolProtectedScreen(
          companyId: widget.profile.activeCompanyId,
          title: 'Личные данные',
          toolsScreen: CompanyToolsScreen(profile: widget.profile),
          child: EmployeePrivateDataScreen(employee: employee),
        ),
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
      AppPageRoute<bool>(
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
      AppPageRoute<void>(
        builder: (_) => PaymentHistoryScreen(employee: employee),
      ),
    );
  }

  Future<void> openComments() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => EmployeeCommentsScreen(employee: employee),
      ),
    );
  }
}
