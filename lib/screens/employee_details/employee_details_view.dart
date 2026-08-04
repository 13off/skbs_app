part of '../employee_details_screen.dart';

extension _EmployeeDetailsView on _EmployeeDetailsScreenState {
  Widget buildEmployeeDetailsView() {
    final isAdmin = widget.profile.isAdmin;
    final toolsScreen = CompanyToolsScreen(profile: widget.profile);

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(employee.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
        children: [
          buildHeader(),
          const SizedBox(height: 30),
          if (isAdmin) ...[
            buildEmployeeAccessTile(),
            const SizedBox(height: 8),
            buildActionTile(
              icon: Icons.badge_outlined,
              title: 'Паспорт специалиста',
              onTap: openProfessionalPassport,
            ),
          ],
          buildActionTile(
            icon: Icons.donut_large_rounded,
            title: 'Личный вклад',
            onTap: openContribution,
          ),
          buildActionTile(
            icon: Icons.calendar_month_outlined,
            title: 'Индивидуальный табель',
            onTap: openTimesheet,
          ),
          if (isAdmin)
            DocumentToolAvailabilityBuilder(
              companyId: widget.profile.activeCompanyId,
              builder: (context, enabled, loading) => Column(
                children: [
                  DocumentToolFeatureLock(
                    enabled: enabled,
                    loading: loading,
                    toolsScreen: toolsScreen,
                    child: buildActionTile(
                      icon: Icons.lock_person_outlined,
                      title: 'Личные данные',
                      onTap: openPrivateData,
                    ),
                  ),
                  DocumentToolFeatureLock(
                    enabled: enabled,
                    loading: loading,
                    toolsScreen: toolsScreen,
                    child: buildActionTile(
                      icon: Icons.folder_outlined,
                      title: 'Документы',
                      onTap: openDocuments,
                    ),
                  ),
                ],
              ),
            ),
          buildActionTile(
            icon: Icons.payments_outlined,
            title: 'Выплаты',
            onTap: openPayments,
          ),
          buildActionTile(
            icon: Icons.comment_outlined,
            title: 'Комментарии',
            onTap: openComments,
          ),
        ],
      ),
    );
  }
}
