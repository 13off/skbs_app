part of '../home_screen.dart';

extension _HomeView on _HomeScreenState {
  Widget buildHomeView() {
    final today = AppState.today;
    return FutureBuilder<_HomeDashboardData>(
      future: dashboardFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _HomeDashboardData.empty;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Stack(
          children: [
            buildDashboard(
              context: context,
              today: today,
              employees: data.employees,
              workedEmployeeIds: data.workedEmployeeIds,
              tasks: data.tasks,
              finance: data.finance,
              isLoading: isLoading,
              hasError: snapshot.hasError,
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                top: false,
                left: false,
                child: buildAiAssistantButton(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeDashboardData {
  final List<Employee> employees;
  final Set<String> workedEmployeeIds;
  final List<TaskItemData> tasks;
  final FinanceSummaryData finance;

  const _HomeDashboardData({
    required this.employees,
    required this.workedEmployeeIds,
    required this.tasks,
    required this.finance,
  });

  static const empty = _HomeDashboardData(
    employees: <Employee>[],
    workedEmployeeIds: <String>{},
    tasks: <TaskItemData>[],
    finance: FinanceSummaryData.empty,
  );
}
