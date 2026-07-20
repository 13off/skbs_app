part of '../employee_details_screen.dart';

extension _EmployeeDetailsView on _EmployeeDetailsScreenState {
  Widget buildEmployeeDetailsView() {
    final isAdmin = widget.profile.isAdmin;

    return Scaffold(
      appBar: AppBar(title: Text(employee.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
        children: [
          buildHeader(),
          const SizedBox(height: 30),
          buildActionTile(
            icon: Icons.calendar_month_outlined,
            title: 'Индивидуальный табель',
            subtitle: 'Смены, начислено, выплаты и Excel',
            onTap: openTimesheet,
          ),
          if (isAdmin)
            buildActionTile(
              icon: Icons.lock_person_outlined,
              title: 'Личные данные',
              subtitle: 'Паспорт, СНИЛС, ИНН, адреса и кадровые документы',
              onTap: openPrivateData,
            ),
          if (isAdmin)
            buildActionTile(
              icon: Icons.folder_outlined,
              title: 'Документы',
              subtitle: 'Фото, PDF, Word, Excel и другие файлы',
              onTap: openDocuments,
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
