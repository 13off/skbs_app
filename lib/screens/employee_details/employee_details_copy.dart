part of '../employee_details_screen.dart';

extension _EmployeeDetailsCopy on _EmployeeDetailsScreenState {
  Future<String?> pickTargetObject(List<String> objectNames) async {
    final currentObjectName = employee.objectName.trim();
    final objects = objectNames
        .map((objectName) => objectName.trim())
        .where((objectName) => objectName.isNotEmpty)
        .where((objectName) => objectName != currentObjectName)
        .toSet()
        .toList()
      ..sort();

    if (objects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет другого объекта для копирования')),
      );
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppAdaptivePalette.surfaceElevated,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppAdaptivePalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4CCC2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Скопировать в объект',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      employee.name,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: objects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final objectName = objects[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(sheetContext, objectName),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppAdaptivePalette.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppAdaptivePalette.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.apartment_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    objectName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> copyEmployeeToOtherObject() async {
    if (!widget.profile.isAdmin) return;

    final employeeId = employee.id;
    if (employeeId == null || employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не найден ID сотрудника')));
      return;
    }
    if (isCopyingEmployee) return;

    try {
      final objectNames = await EmployeeRepository.fetchObjectNames(
        forceRefresh: true,
      );
      if (!mounted) return;

      final targetObjectName = await pickTargetObject(objectNames);
      if (!mounted || targetObjectName == null) return;

      setState(() => isCopyingEmployee = true);
      final copiedEmployee = await EmployeeRepository.copyEmployeeToObject(
        employee: employee,
        targetObjectName: targetObjectName,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Сотрудник скопирован в объект: ${copiedEmployee.objectName}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка копирования: $error')),
      );
    } finally {
      if (mounted) setState(() => isCopyingEmployee = false);
    }
  }
}
