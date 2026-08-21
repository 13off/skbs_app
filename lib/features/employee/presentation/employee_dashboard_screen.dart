import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/employee_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_cabinet_repository.dart';
import 'employee_actionable_tasks.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeDashboardScreen({super.key, required this.profile});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  late Future<EmployeeCabinetData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.objectName != widget.profile.objectName ||
        oldWidget.profile.isRolePreview != widget.profile.isRolePreview) {
      future = _load();
    }
  }

  Future<EmployeeCabinetData> _load() async {
    if (!widget.profile.isRolePreview) {
      return EmployeeCabinetRepository.fetch();
    }

    final employee = await _resolvePreviewEmployee();
    final now = DateTime.now();
    return EmployeeCabinetData(
      fullName: employee.name.trim().isEmpty
          ? 'Сотрудник'
          : employee.name.trim(),
      phone: employee.phone.trim(),
      profession: employee.positionTitle.trim(),
      currentObject: employee.objectName.trim(),
      objectNames: employee.objectName.trim().isEmpty
          ? const <String>[]
          : <String>[employee.objectName.trim()],
      dailyRate: employee.dailyRate,
      avatarPath: '',
      month: now.month,
      year: now.year,
      summary: const EmployeeCabinetSummary(
        shifts: 0,
        hours: 0,
        estimatedAccrued: 0,
        paidCurrentMonth: 0,
        plannedTasks: 0,
        completedTasks: 0,
        documents: 0,
      ),
      attendance: const <EmployeeCabinetAttendance>[],
      tasks: const <EmployeeCabinetTask>[],
      payments: const <EmployeeCabinetPayment>[],
      documents: const <EmployeeCabinetDocument>[],
    );
  }

  Future<Employee> _resolvePreviewEmployee() async {
    final employees = await EmployeeRepository.fetchEmployees(
      includeFired: false,
      forceRefresh: true,
    );
    final candidates = employees.where((employee) {
      return employee.isActive &&
          (employee.id ?? '').trim().isNotEmpty &&
          employee.objectName.trim().isNotEmpty;
    }).toList()..sort((left, right) => left.name.compareTo(right.name));

    if (candidates.isEmpty) {
      throw Exception('Нет активного сотрудника с назначенным объектом');
    }

    final preferredObject = widget.profile.objectName.trim().toLowerCase();
    if (preferredObject.isNotEmpty) {
      for (final employee in candidates) {
        if (employee.objectName.trim().toLowerCase() == preferredObject) {
          return employee;
        }
      }
    }
    return candidates.first;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => future = next);
    await next;
  }

  Future<void> _openTask(EmployeeCabinetTask task) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(builder: (_) => EmployeeTaskDetailsScreen(task: task)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'Главная',
            subtitle: 'Личный кабинет сотрудника',
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'Главная',
            subtitle: 'Не удалось загрузить кабинет',
            onRefresh: _refresh,
            child: PremiumWorkCard(
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    snapshot.error?.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ) ??
                        'Не удалось загрузить данные сотрудника',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final task = data.currentTask;
        final objectName = data.currentObject.trim();
        return AppPage(
          title: 'Главная',
          subtitle: objectName.isEmpty
              ? 'Личный кабинет сотрудника'
              : 'Объект: $objectName',
          onRefresh: _refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EmployeeIdentityCard(data: data),
              const SizedBox(height: 14),
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _IconTile(icon: Icons.construction_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task == null
                                ? 'На сегодня задач нет'
                                : 'Текущая задача',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (task != null) _StatusBadge(text: task.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (task == null)
                      Text(
                        'Новая задача появится здесь автоматически после назначения мастером.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else ...[
                      Text(
                        task.work.trim().isEmpty ? 'Рабочая задача' : task.work,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        <String>[
                          if (task.axes.trim().isNotEmpty) task.axes.trim(),
                          if (task.objectName.trim().isNotEmpty)
                            task.objectName.trim(),
                          if (task.date != null) _formatDate(task.date!),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      PremiumActionButton(
                        label: 'Открыть задачу',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => _openTask(task),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_month_rounded,
                      value: _formatDecimal(data.summary.shifts),
                      label: 'смен в месяце',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.verified_rounded,
                      value: '${data.summary.completedTasks}',
                      label: 'задач выполнено',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _IconTile(
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Этот месяц',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _ValueLine(
                      title: 'Предварительно начислено',
                      value: _formatMoney(data.summary.estimatedAccrued),
                    ),
                    _ValueLine(
                      title: 'Выплаты и авансы',
                      value: _formatMoney(data.summary.paidCurrentMonth),
                    ),
                    _ValueLine(
                      title: 'Задач в работе',
                      value: '${data.summary.plannedTasks}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeIdentityCard extends StatelessWidget {
  final EmployeeCabinetData data;

  const _EmployeeIdentityCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data.fullName.trim().isEmpty
        ? 'Сотрудник'
        : data.fullName.trim();
    final profession = data.profession.trim().isEmpty
        ? 'Должность не указана'
        : data.profession.trim();
    final details = <String>[
      profession,
      if (data.phone.trim().isNotEmpty) data.phone.trim(),
    ];

    return PremiumWorkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _InitialsAvatar(name: name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  details.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppAdaptivePalette.textMuted,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;

  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Text(
        initials.isEmpty ? 'С' : initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppAdaptivePalette.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;

  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppAdaptivePalette.textPrimary),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final completed = text == 'Выполнено';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: completed
            ? AppAdaptivePalette.success.withValues(alpha: 0.13)
            : AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.trim().isEmpty ? 'Запланировано' : text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: completed
              ? AppAdaptivePalette.success
              : AppAdaptivePalette.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppAdaptivePalette.textMuted),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  final String title;
  final String value;

  const _ValueLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatMoney(double value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final chunks = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, digits.length);
    chunks.insert(0, digits.substring(start, end));
  }
  return '${rounded < 0 ? '-' : ''}${chunks.join(' ')} ₽';
}
