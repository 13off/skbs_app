part of '../employee_details_screen.dart';

extension _EmployeeDetailsView on _EmployeeDetailsScreenState {
  Widget buildEmployeeDetailsView() {
    final isAdmin = widget.profile.isAdmin;
    final toolsScreen = CompanyToolsScreen(profile: widget.profile);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(employee.name),
      ),
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
              subtitle: 'Реальный опыт, смены, задачи, объекты и навыки',
              onTap: openProfessionalPassport,
            ),
          ],
          buildActionTile(
            icon: Icons.donut_large_rounded,
            title: 'Личный вклад',
            subtitle: 'Доля в завершённых задачах, сводка и история',
            onTap: openContribution,
          ),
          buildActionTile(
            icon: Icons.calendar_month_outlined,
            title: 'Индивидуальный табель',
            subtitle: 'Смены, начислено, выплаты и Excel',
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
                      subtitle:
                          'Паспорт, СНИЛС, ИНН, адреса и кадровые документы',
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
                      subtitle: 'Фото, PDF, Word, Excel и другие файлы',
                      onTap: openDocuments,
                    ),
                  ),
                ],
              ),
            ),
          buildActionTile(
            icon: Icons.payments_outlined,
            title: 'Выплаты',
            subtitle: 'История выплат, авансов и штрафов',
            onTap: openPayments,
          ),
          buildActionTile(
            icon: Icons.comment_outlined,
            title: 'Комментарии',
            subtitle: 'Несколько заметок по сотруднику',
            onTap: openComments,
          ),
        ],
      ),
    );
  }
}
