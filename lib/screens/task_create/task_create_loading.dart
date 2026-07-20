part of '../add_task_screen.dart';

extension _TaskCreateLoading on _AddTaskScreenState {
  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String assigneeTitle() {
    if (selectedAssigneeIds.isEmpty) {
      return 'Исполнители не выбраны';
    }
    return 'Выбрано: ${selectedAssigneeIds.length}';
  }

  String selectedEmployeeNames() {
    final selectedEmployees = employees.where((employee) {
      return employee.id != null && selectedAssigneeIds.contains(employee.id);
    }).toList();

    if (selectedEmployees.isEmpty) {
      return 'Нажмите, чтобы выбрать сотрудников';
    }
    return selectedEmployees.map((employee) => employee.name).join(', ');
  }

  Future<void> loadPolicy() async {
    try {
      final loaded = await DeveloperPolicyRepository.ensurePolicy(
        widget.objectName,
      );
      if (!mounted) return;
      setState(() {
        policy = loaded;
        isLoadingPolicy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingPolicy = false;
        errorText = 'Ошибка загрузки ограничений: $error';
      });
    }
  }

  Future<void> loadEmployees() async {
    setState(() {
      isLoadingEmployees = true;
      errorText = null;
    });

    try {
      final result = await EmployeeRepository.fetchEmployees(
        objectName: widget.objectName,
      );
      if (!mounted) return;

      setState(() {
        employees = result.where((employee) {
          return employee.id != null && employee.id!.isNotEmpty;
        }).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = 'Ошибка загрузки сотрудников: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmployees = false;
        });
      }
    }
  }
}
