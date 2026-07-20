part of '../employee_details_screen.dart';

extension _EmployeeDetailsStatus on _EmployeeDetailsScreenState {
  Future<void> archiveCurrentEmployee() async {
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty || isArchivingEmployee) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Архивировать сотрудника?'),
        content: Text(
          '${employee.name} исчезнет из рабочего списка. Табель, выплаты, документы и личные данные сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('В архив'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => isArchivingEmployee = true);
    try {
      await EmployeeArchiveRepository.archiveEmployee(employeeId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка архивирования: $error')),
      );
    } finally {
      if (mounted) setState(() => isArchivingEmployee = false);
    }
  }

  Future<void> toggleFiredStatus() async {
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не найден ID сотрудника')));
      return;
    }

    final willFire = employee.isActive;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(willFire ? 'Уволить сотрудника?' : 'Вернуть сотрудника?'),
        content: Text(
          willFire
              ? '${employee.name} будет перенесён в раздел «Уволенные». При необходимости его можно сразу убрать в архив.'
              : '${employee.name} снова появится в активных сотрудниках.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          if (willFire && widget.profile.isAdmin)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'archive'),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Уволить и архивировать'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, willFire ? 'fire' : 'restore'),
            child: Text(willFire ? 'Уволить' : 'Вернуть'),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;
    if (action == 'archive') {
      setState(() => isArchivingEmployee = true);
      try {
        await EmployeeArchiveRepository.archiveEmployee(employeeId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка архивирования: $error')),
        );
      } finally {
        if (mounted) setState(() => isArchivingEmployee = false);
      }
      return;
    }

    setState(() => isChangingStatus = true);
    try {
      final restored = action == 'restore';
      await EmployeeRepository.setEmployeeActive(
        employeeId: employeeId,
        isActive: restored,
      );

      if (!mounted) return;
      setState(() {
        employee = Employee(
          employee.name,
          employee.position,
          employee.status,
          id: employee.id,
          phone: employee.phone,
          objectName: employee.objectName,
          dailyRate: employee.dailyRate,
          isActive: restored,
          comment: employee.comment,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Сотрудник возвращён в активные'
                : 'Сотрудник отмечен как уволенный',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка изменения статуса: $error')),
      );
    } finally {
      if (mounted) setState(() => isChangingStatus = false);
    }
  }
}
