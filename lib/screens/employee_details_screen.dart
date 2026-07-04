import 'package:flutter/material.dart';

import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import 'add_payment_screen.dart';
import 'edit_employee_screen.dart';
import 'employee_comments_screen.dart';
import 'employee_documents_screen.dart';
import 'employee_private_data_screen.dart';
import 'employee_timesheet_screen.dart';
import 'payment_history_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final AppUserProfile profile;
  final Employee employee;

  const EmployeeDetailsScreen({
    super.key,
    required this.profile,
    required this.employee,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  late Employee employee;
  bool isChangingStatus = false;

  @override
  void initState() {
    super.initState();

    employee = widget.employee;
  }

  String firstLetter(String text) {
    final clean = text.trim();

    if (clean.isEmpty) return '?';

    return clean.characters.first;
  }

  String formatMoney(int value) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$text ₽';
  }

  Future<void> openEditEmployee() async {
    final updatedEmployee = await Navigator.push<Employee>(
      context,
      MaterialPageRoute(builder: (_) => EditEmployeeScreen(employee: employee)),
    );

    if (updatedEmployee == null) return;

    setState(() {
      employee = updatedEmployee;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Сотрудник обновлён')));
  }

  Future<void> openTimesheet() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeTimesheetScreen(employee: employee),
      ),
    );
  }

  Future<void> openDocuments() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeDocumentsScreen(employee: employee),
      ),
    );
  }

  Future<void> openPrivateData() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeePrivateDataScreen(employee: employee),
      ),
    );
  }

  String monthName(int month) {
    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    if (month < 1 || month > 12) return 'Месяц';

    return monthNames[month - 1];
  }

  Future<void> openAddPayment() async {
    final employeeId = employee.id;

    if (employeeId == null || employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('У сотрудника нет ID')));
      return;
    }

    final now = DateTime.now();

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPaymentScreen(
          periodYear: now.year,
          periodMonth: now.month,
          periodTitle: '${monthName(now.month)} ${now.year}',
          initialEmployeeId: employeeId,
        ),
      ),
    );

    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Выплата сохранена')));
  }

  Future<void> openPayments() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(employee: employee),
      ),
    );
  }

  Future<void> openComments() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeCommentsScreen(employee: employee),
      ),
    );
  }

  Future<void> toggleFiredStatus() async {
    final employeeId = employee.id;

    if (employeeId == null || employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не найден ID сотрудника')));
      return;
    }

    final willFire = employee.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(willFire ? 'Отметить уволенным?' : 'Вернуть сотрудника?'),
          content: Text(
            willFire
                ? '${employee.name} будет перенесён вниз списка в раздел «Уволенные».'
                : '${employee.name} снова появится в активных сотрудниках.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text(willFire ? 'Уволен' : 'Вернуть'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      isChangingStatus = true;
    });

    try {
      await EmployeeRepository.setEmployeeActive(
        employeeId: employeeId,
        isActive: !willFire,
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
          isActive: !willFire,
          comment: employee.comment,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            willFire
                ? 'Сотрудник отмечен как уволенный'
                : 'Сотрудник возвращён в активные',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка изменения статуса: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isChangingStatus = false;
        });
      }
    }
  }

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFEEE7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final cleanValue = value.trim();

    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(icon),
        title: Text(title),
        subtitle: cleanValue.isEmpty
            ? null
            : Text(
                cleanValue,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget buildStatusBadge() {
    final isFired = !employee.isActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isFired ? Colors.grey.shade300 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        isFired ? 'Уволен' : 'Активный',
        style: TextStyle(
          color: isFired ? Colors.grey.shade800 : Colors.green.shade800,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildHeader() {
    final isFired = !employee.isActive;
    final comment = employee.comment.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor: isFired
                    ? Colors.grey.shade300
                    : const Color(0xFFFFD5C4),
                child: Text(
                  firstLetter(employee.name),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w500,
                    color: isFired
                        ? Colors.grey.shade700
                        : const Color(0xFF8B3F16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              buildStatusBadge(),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        employee.name,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: isFired
                              ? Colors.grey.shade700
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Редактировать',
                      onPressed: isChangingStatus ? null : openEditEmployee,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Добавить выплату',
                      onPressed: isChangingStatus ? null : openAddPayment,
                      icon: const Icon(Icons.add_card_outlined),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: isFired ? 'Вернуть в активные' : 'Уволить',
                      onPressed: isChangingStatus ? null : toggleFiredStatus,
                      icon: isChangingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isFired ? Icons.undo : Icons.person_off_outlined,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                buildHeaderInfoLine(
                  icon: Icons.badge_outlined,
                  title: 'Должность',
                  value: employee.position,
                ),
                buildHeaderInfoLine(
                  icon: Icons.apartment_outlined,
                  title: 'Объект',
                  value: employee.objectName,
                ),
                buildHeaderInfoLine(
                  icon: Icons.phone_outlined,
                  title: 'Телефон',
                  value: employee.phone.isEmpty ? 'Не указан' : employee.phone,
                ),
                buildHeaderInfoLine(
                  icon: Icons.payments_outlined,
                  title: 'Ставка',
                  value: formatMoney(employee.dailyRate),
                ),
                buildHeaderInfoLine(
                  icon: Icons.notes_outlined,
                  title: 'Комментарий',
                  value: comment.isEmpty ? 'Нет комментария' : comment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeaderInfoLine({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          if (widget.profile.isAdmin)
            buildActionTile(
              icon: Icons.lock_person_outlined,
              title: 'Личные данные',
              subtitle: 'Паспорт, СНИЛС, ИНН, адреса и кадровые документы',
              onTap: openPrivateData,
            ),
          if (widget.profile.isAdmin)
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
