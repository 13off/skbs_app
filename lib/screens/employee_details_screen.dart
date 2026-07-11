import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;

import '../data/employee_archive_repository.dart';
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
  bool isCopyingEmployee = false;
  bool isArchivingEmployee = false;

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
      CupertinoPageRoute(
        builder: (_) => EditEmployeeScreen(employee: employee),
      ),
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
      CupertinoPageRoute(
        builder: (_) => EmployeeTimesheetScreen(employee: employee),
      ),
    );
  }

  Future<void> openDocuments() async {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => EmployeeDocumentsScreen(employee: employee),
      ),
    );
  }

  Future<void> openPrivateData() async {
    Navigator.push(
      context,
      CupertinoPageRoute(
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
      CupertinoPageRoute(
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
      CupertinoPageRoute(
        builder: (_) => PaymentHistoryScreen(employee: employee),
      ),
    );
  }

  Future<void> openComments() async {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => EmployeeCommentsScreen(employee: employee),
      ),
    );
  }

  Future<String?> pickTargetObject(List<String> objectNames) async {
    final currentObjectName = employee.objectName.trim();

    final objects = objectNames
        .map((objectName) => objectName.trim())
        .where((objectName) => objectName.isNotEmpty)
        .where((objectName) => objectName != currentObjectName)
        .toSet()
        .toList();

    objects.sort();

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
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.grey.shade200),
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
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      employee.name,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: objects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final objectName = objects[index];

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.pop(context, objectName);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.apartment_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    objectName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
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

      setState(() {
        isCopyingEmployee = true;
      });

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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка копирования: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isCopyingEmployee = false;
        });
      }
    }
  }

  Future<void> archiveCurrentEmployee() async {
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty || isArchivingEmployee) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Архивировать сотрудника?'),
        content: Text(
          '${employee.name} исчезнет из рабочего списка. Табель, выплаты, документы и личные данные сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('В архив'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isArchivingEmployee = true);
    try {
      await EmployeeArchiveRepository.archiveEmployee(employeeId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка архивирования: $error')));
    } finally {
      if (mounted) setState(() => isArchivingEmployee = false);
    }
  }

  Future<void> toggleFiredStatus() async {
    final employeeId = employee.id?.trim() ?? '';

    if (employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не найден ID сотрудника')));
      return;
    }

    final willFire = employee.isActive;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willFire ? 'Уволить сотрудника?' : 'Вернуть сотрудника?'),
        content: Text(
          willFire
              ? '${employee.name} будет перенесён в раздел «Уволенные». При необходимости его можно сразу убрать в архив.'
              : '${employee.name} снова появится в активных сотрудниках.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          if (willFire && widget.profile.isAdmin)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'archive'),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Уволить и архивировать'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, willFire ? 'fire' : 'restore'),
            child: Text(willFire ? 'Уволить' : 'Вернуть'),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'archive') {
      setState(() => isArchivingEmployee = true);
      try {
        await EmployeeArchiveRepository.archiveEmployee(employeeId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка архивирования: $error')));
      } finally {
        if (mounted) setState(() => isArchivingEmployee = false);
      }
      return;
    }

    setState(() => isChangingStatus = true);
    try {
      final restored = action == 'restore';
      await EmployeeRepository.setEmployeeActive(
        employeeId: employeeId,
        isActive: restored,
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
          isActive: restored,
          comment: employee.comment,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Сотрудник возвращён в активные'
                : 'Сотрудник отмечен как уволенный',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка изменения статуса: $error')),
      );
    } finally {
      if (mounted) setState(() => isChangingStatus = false);
    }
  }

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minVerticalPadding: 14,
        leading: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: isLoading ? null : onTap,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;

        final avatarBlock = Column(
          children: [
            CircleAvatar(
              radius: isMobile ? 58 : 66,
              backgroundColor: isFired
                  ? Colors.grey.shade300
                  : const Color(0xFFF2F3F5),
              child: Text(
                firstLetter(employee.name),
                style: TextStyle(
                  fontSize: isMobile ? 42 : 48,
                  fontWeight: FontWeight.w500,
                  color: isFired
                      ? Colors.grey.shade700
                      : const Color(0xFF6B7075),
                ),
              ),
            ),
            const SizedBox(height: 12),
            buildStatusBadge(),
          ],
        );

        final actionButtons = Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            _roundHeaderButton(
              tooltip: 'Редактировать',
              icon: Icons.edit_outlined,
              onPressed: isChangingStatus || isCopyingEmployee
                  ? null
                  : openEditEmployee,
            ),
            if (widget.profile.isAdmin)
              _roundHeaderButton(
                tooltip: 'Скопировать в другой объект',
                icon: Icons.content_copy_outlined,
                onPressed: isChangingStatus || isCopyingEmployee
                    ? null
                    : copyEmployeeToOtherObject,
                child: isCopyingEmployee
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            _roundHeaderButton(
              tooltip: 'Добавить выплату',
              icon: Icons.add_card_outlined,
              onPressed: isChangingStatus || isCopyingEmployee
                  ? null
                  : openAddPayment,
            ),
            _roundHeaderButton(
              tooltip: isFired ? 'Вернуть в активные' : 'Уволить',
              icon: isFired ? Icons.undo : Icons.person_off_outlined,
              onPressed:
                  isChangingStatus || isCopyingEmployee || isArchivingEmployee
                  ? null
                  : toggleFiredStatus,
              child: isChangingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (widget.profile.isAdmin && isFired)
              _roundHeaderButton(
                tooltip: 'Архивировать',
                icon: Icons.archive_outlined,
                onPressed:
                    isChangingStatus || isCopyingEmployee || isArchivingEmployee
                    ? null
                    : archiveCurrentEmployee,
                child: isArchivingEmployee
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
          ],
        );

        final infoBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.name,
              maxLines: isMobile ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontSize: isMobile ? 28 : 32,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: isFired ? Colors.grey.shade700 : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
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
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatarBlock,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: actionButtons,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    infoBlock,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatarBlock,
                    const SizedBox(width: 24),
                    Expanded(child: infoBlock),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  Widget _roundHeaderButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: child ?? Icon(icon, color: const Color(0xFF8F9499)),
            ),
          ),
        ),
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
