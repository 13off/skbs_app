part of '../timesheet_screen.dart';

extension _TimesheetView on _TimesheetScreenState {
  Widget buildTimesheetView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumWorkBackdrop(
        child: FutureBuilder<List<Employee>>(
          future: employeesFuture,
          builder: (context, employeesSnapshot) {
            final allEmployees = employeesSnapshot.data ?? <Employee>[];
            final visibleEmployees = filterEmployees(allEmployees);

            if (employeesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (employeesSnapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка загрузки сотрудников: ${employeesSnapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                        children: [
                          buildPageHeader(),
                          const SizedBox(height: 14),
                          buildDatePanel(),
                          const SizedBox(height: 14),
                          buildWorkedSummaryPanel(
                            visibleEmployees: visibleEmployees,
                          ),
                          const SizedBox(height: 14),
                          buildSearch(),
                          const SizedBox(height: 14),
                          buildQuickActions(visibleEmployees),
                          const SizedBox(height: 16),
                          if (isAttendanceLoading || isSaving)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: LinearProgressIndicator(),
                            ),
                          if (errorText != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                errorText!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (visibleEmployees.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  'Сотрудники не найдены',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...visibleEmployees.map(
                              (employee) => RepaintBoundary(
                                child: buildEmployeeRow(employee),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: PremiumActionButton(
                          label: hasUnsavedChanges
                              ? 'Сохранить изменения'
                              : 'Сохранить табель',
                          icon: Icons.save_outlined,
                          isLoading: isSaving,
                          onPressed:
                              allEmployees.isEmpty ||
                                  isAttendanceLoading ||
                                  isSaving
                              ? null
                              : () => saveTimesheet(allEmployees),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimesheetReportRoute extends StatelessWidget {
  final String? selectedObjectName;

  const _TimesheetReportRoute({required this.selectedObjectName});

  String get objectTitle {
    final objectName = selectedObjectName?.trim();
    if (objectName == null || objectName.isEmpty) return 'Все объекты';
    return objectName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчет по табелю — $objectTitle')),
      body: PeriodTimesheetScreen(selectedObjectName: selectedObjectName),
    );
  }
}
