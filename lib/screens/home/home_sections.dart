part of '../home_screen.dart';

extension _HomeSections on _HomeScreenState {
  Widget buildObjectSelector(BuildContext context) {
    if (!widget.profile.isAdmin) {
      return _ObjectSelectorShell(
        icon: Icons.lock_outline,
        title: objectTitle,
        onTap: null,
      );
    }

    return FutureBuilder<List<String>>(
      future: objectNamesFuture,
      builder: (context, snapshot) {
        final objects = snapshot.data ?? const <String>[];
        return _ObjectSelectorShell(
          icon: Icons.apartment_outlined,
          title: objectTitle,
          onTap: () => showObjectPicker(context, objects),
        );
      },
    );
  }

  Widget buildHeader(BuildContext context, DateTime today) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Главная',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            NotificationBell(selectedObjectName: widget.selectedObjectName),
          ],
        ),
        const SizedBox(height: 8),
        PremiumWorkCard(
          radius: 18,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: _muted,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Сегодня, ${dateText(today)}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              buildObjectSelector(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildDashboard({
    required BuildContext context,
    required DateTime today,
    required List<Employee> employees,
    required Set<String> workedEmployeeIds,
    required List<TaskItemData> tasks,
    required FinanceSummaryData finance,
    required bool isLoading,
    required bool hasError,
  }) {
    final employeeById = <String, Employee>{};
    final activeEmployeeNames = <String>{};

    for (final employee in employees) {
      final id = employee.id?.trim();
      if (id != null && id.isNotEmpty) employeeById[id] = employee;
      activeEmployeeNames.add(normalizeName(employee.name));
    }

    final workedEmployeeNames = <String>{};
    for (final employeeId in workedEmployeeIds) {
      final employee = employeeById[employeeId];
      if (employee != null) {
        workedEmployeeNames.add(normalizeName(employee.name));
      }
    }

    final totalEmployees = activeEmployeeNames.length;
    final workedEmployees = workedEmployeeNames.length;
    final totalTasks = tasks.length;
    final doneTasks = tasks.where((task) => task.status == 'Выполнено').length;
    final employeesProgress = totalEmployees == 0
        ? 0.0
        : workedEmployees / totalEmployees;
    final tasksProgress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

    return PremiumWorkBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeader(context, today),
                    if (hasError) ...[
                      const SizedBox(height: 14),
                      const _SystemMessage(
                        icon: Icons.error_outline,
                        title: 'Есть ошибка загрузки',
                        text:
                            'Часть данных не подтянулась. Обнови страницу или проверь интернет.',
                      ),
                    ],
                    const SizedBox(height: 18),
                    MilestoneHomeSection(
                      profile: widget.profile,
                      selectedObjectName: widget.selectedObjectName,
                    ),
                    const SizedBox(height: 18),
                    _DashboardMetricCard(
                      icon: Icons.person_outline,
                      title: 'Сотрудники на объекте',
                      value: isLoading ? '...' : workedEmployees.toString(),
                      secondaryValue: isLoading ? '...' : 'из $totalEmployees',
                      progress: employeesProgress,
                      footerTitle: 'На объекте',
                      footerValue: isLoading
                          ? '...'
                          : workedEmployees.toString(),
                      footerColor: _success,
                    ),
                    const SizedBox(height: 14),
                    _DashboardMetricCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Выполненные задачи',
                      value: isLoading ? '...' : doneTasks.toString(),
                      secondaryValue: isLoading ? '...' : 'из $totalTasks',
                      progress: tasksProgress,
                      footerTitle: 'За сегодня',
                      footerValue: isLoading ? '...' : doneTasks.toString(),
                      footerColor: _accent,
                    ),
                    if (widget.profile.isAdmin) ...[
                      const SizedBox(height: 14),
                      _FinanceSummaryCard(
                        title: 'Выплаты ${financePeriod.title()}',
                        objectTitle: objectTitle,
                        finance: isLoading ? FinanceSummaryData.empty : finance,
                        isLoading: isLoading,
                        onPeriodTap: () => showFinancePeriodPicker(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
