// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

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
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        policy = loaded;
        isLoadingPolicy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        policy = DeveloperPolicyRepository.policyForObjectSync(
          widget.objectName,
        );
        isLoadingPolicy = false;
      });
    }
  }

  Future<void> loadEmployees() async {
    setState(() {
      isLoadingEmployees = true;
      errorText = null;
    });

    try {
      final result = await OfflineEmployeeRepository.fetchEmployees(
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
        errorText = 'Не удалось открыть сохранённый список сотрудников: $error';
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
