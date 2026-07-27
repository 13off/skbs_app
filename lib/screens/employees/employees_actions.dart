part of '../employees_screen.dart';

extension _EmployeesActions on _EmployeesScreenState {
  Future<void> openEmployee(Employee employee) async {
    final savedOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;

    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) =>
            EmployeeDetailsScreen(profile: widget.profile, employee: employee),
      ),
    );
    if (!mounted) return;

    await loadEmployees();
    if (!mounted) return;
    EmployeeDirectoryLogic.restoreScrollOffset(scrollController, savedOffset);
  }

  Future<void> addEmployee() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => AddEmployeeScreen(initialObjectName: objectName),
      ),
    );
    if (mounted && saved == true) await loadEmployees();
  }

  void openPayments() {
    Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => PaymentsScreen(
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  Future<void> downloadSummary() async {
    try {
      await directoryController.downloadSummary();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Сводка скачана')));
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка формирования сводки: $exception')),
        );
      }
    }
  }

  String money(int value) => EmployeeDirectoryLogic.money(value);
}
