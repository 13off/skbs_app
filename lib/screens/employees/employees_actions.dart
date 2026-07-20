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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final position = scrollController.position;
      final target = savedOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > .5) {
        scrollController.jumpTo(target);
      }
    });
  }

  Future<void> addEmployee() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute(
        builder: (_) => AddEmployeeScreen(initialObjectName: objectName),
      ),
    );
    if (mounted && saved == true) await loadEmployees();
  }

  void openPayments() {
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => PaymentsScreen(
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  Future<void> downloadSummary() async {
    try {
      final source = employees.isNotEmpty
          ? List<Employee>.from(employees)
          : await EmployeeRepository.fetchEmployees(
              objectName: widget.selectedObjectName,
              includeFired: true,
            );
      final ids = source
          .map((employee) => employee.id ?? '')
          .where((id) => id.trim().isNotEmpty)
          .toList();
      final privateData =
          await EmployeePrivateDataRepository.fetchMapByEmployeeIds(ids);
      await EmployeePrivateSummaryExporter.downloadSummary(
        employees: source,
        privateDataByEmployeeId: privateData,
        objectName: widget.selectedObjectName,
      );
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

  String money(int value) {
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$formatted ₽';
  }
}
