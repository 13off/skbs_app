part of '../employees_screen.dart';

extension _EmployeesView on _EmployeesScreenState {
  Widget buildEmployeesView() {
    final visible = visibleEmployees();
    final active = visible.where((employee) => employee.isActive).toList();
    final fired = visible.where((employee) => !employee.isActive).toList();
    final leading = <Widget>[
      header(),
      const SizedBox(height: 14),
      search(),
      const SizedBox(height: 16),
    ];

    Widget? state;
    if (loading && employees.isEmpty) {
      state = const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null && employees.isEmpty) {
      state = emptyEmployeesState(
        'Ошибка загрузки сотрудников: $error',
        errorState: true,
      );
    } else if (employees.isEmpty) {
      state = emptyEmployeesState('Сотрудников пока нет');
    } else if (visible.isEmpty) {
      state = emptyEmployeesState('Сотрудники не найдены');
    }

    final sectionCount = state != null
        ? 1
        : 1 + active.length + (fired.isEmpty ? 0 : 1 + fired.length);

    return RepaintBoundary(
      child: PremiumWorkBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView.builder(
                key: PageStorageKey(
                  'employees-${widget.selectedObjectName ?? 'all'}',
                ),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                cacheExtent: 700,
                itemCount: leading.length + sectionCount,
                itemBuilder: (context, index) {
                  if (index < leading.length) return leading[index];
                  if (state != null) return state;

                  var rowIndex = index - leading.length;
                  if (rowIndex == 0) {
                    return sectionHeader('Активные', active.length);
                  }
                  rowIndex -= 1;
                  if (rowIndex < active.length) {
                    return RepaintBoundary(
                      child: employeeCard(active[rowIndex]),
                    );
                  }
                  rowIndex -= active.length;
                  if (rowIndex == 0) {
                    return sectionHeader(
                      'Уволенные',
                      fired.length,
                      fired: true,
                    );
                  }
                  rowIndex -= 1;
                  return RepaintBoundary(child: employeeCard(fired[rowIndex]));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
