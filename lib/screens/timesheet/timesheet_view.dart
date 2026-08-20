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
            final employeeItems = buildGroupedEmployeeItems(visibleEmployees);
            final floatingBottom = AppUi.floatingActionBottom(context);
            final listBottom = AppUi.floatingActionListBottomPadding(context);

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

            return Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Builder(
                        builder: (context) {
                          final leading = <Widget>[
                            buildPageHeader(),
                            const SizedBox(height: 18),
                            buildDatePanel(),
                            const SizedBox(height: 16),
                            buildWorkedSummaryPanel(
                              visibleEmployees: visibleEmployees,
                            ),
                            const SizedBox(height: 16),
                            buildSearch(),
                            const SizedBox(height: 12),
                            buildGroupFilter(allEmployees),
                            const SizedBox(height: 16),
                            buildQuickActions(visibleEmployees),
                            const SizedBox(height: 18),
                            if (isAttendanceLoading || isGroupsLoading || isSaving)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: LinearProgressIndicator(),
                              ),
                            if (errorText != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            if (visibleEmployees.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                child: Center(
                                  child: Text(
                                    'Сотрудники не найдены',
                                    style: TextStyle(
                                      color: AppAdaptivePalette.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ];

                          return ListView.builder(
                            // Flutter 3.44 deprecates this field before exposing its replacement.
                            // ignore: deprecated_member_use
                            cacheExtent: 700,
                            padding: EdgeInsets.fromLTRB(
                              18,
                              18,
                              18,
                              listBottom,
                            ),
                            itemCount: leading.length + employeeItems.length,
                            itemBuilder: (context, index) {
                              if (index < leading.length) return leading[index];
                              return employeeItems[index - leading.length];
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: floatingBottom,
                  child: Center(
                    child: SizedBox(
                      key: const ValueKey('timesheet-floating-save'),
                      width: 340,
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
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Отчет по табелю — $objectTitle'),
      ),
      body: PeriodTimesheetScreen(selectedObjectName: selectedObjectName),
    );
  }
}
