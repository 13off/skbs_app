import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../role_preview/role_preview_controller.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../data/employee_cabinet_repository.dart';

class EmployeeMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeMainScreen({super.key, required this.profile});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  static const int pageCount = 5;

  late DateTime selectedMonth;
  late final PersistentTabController tabs;
  late final ValueNotifier<Future<EmployeeCabinetData>> cabinetFuture;

  static const items = <ProfessionalBottomNavigationItem>[
    ProfessionalBottomNavigationItem(
      label: 'Главная',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'Задачи',
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'Табель',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'Документы',
      icon: Icons.folder_copy_outlined,
      selectedIcon: Icons.folder_copy_rounded,
    ),
    ProfessionalBottomNavigationItem(
      label: 'Профиль',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  static const onboardingDestinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Главная',
    ),
    NavigationDestination(
      icon: Icon(Icons.task_alt_outlined),
      selectedIcon: Icon(Icons.task_alt_rounded),
      label: 'Задачи',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Табель',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_copy_outlined),
      selectedIcon: Icon(Icons.folder_copy_rounded),
      label: 'Документы',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Профиль',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    tabs = PersistentTabController(pageCount: pageCount);
    cabinetFuture = ValueNotifier<Future<EmployeeCabinetData>>(loadCabinet());
  }

  @override
  void dispose() {
    cabinetFuture.dispose();
    tabs.dispose();
    super.dispose();
  }

  Future<EmployeeCabinetData> loadCabinet() {
    if (widget.profile.isRolePreview) {
      return Future<EmployeeCabinetData>.value(
        EmployeeCabinetData.preview(
          widget.profile,
          year: selectedMonth.year,
          month: selectedMonth.month,
        ),
      );
    }
    return EmployeeCabinetRepository.fetch(
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
  }

  Future<void> refresh() async {
    final next = loadCabinet();
    cabinetFuture.value = next;
    await next;
  }

  Future<void> changeMonth(int delta) async {
    final nextMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + delta,
      1,
    );
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    if (nextMonth.isAfter(currentMonth)) return;

    selectedMonth = nextMonth;
    await refresh();
  }

  Widget rootPage(BuildContext context, int index) {
    return ValueListenableBuilder<Future<EmployeeCabinetData>>(
      valueListenable: cabinetFuture,
      builder: (context, future, _) {
        return FutureBuilder<EmployeeCabinetData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const PremiumLoadingScreen(
                message: 'Загружаем личный кабинет',
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _EmployeeLoadError(
                message: snapshot.error
                        ?.toString()
                        .replaceFirst('Exception: ', '') ??
                    'Не удалось загрузить личный кабинет',
                onRetry: refresh,
              );
            }

            final data = snapshot.data!;
            final now = DateTime.now();
            final canMoveForward = data.year < now.year ||
                (data.year == now.year && data.month < now.month);

            return switch (index) {
              0 => _EmployeeHome(data: data, onRefresh: refresh),
              1 => _EmployeeTasks(data: data, onRefresh: refresh),
              2 => _EmployeeTimesheet(
                  data: data,
                  onRefresh: refresh,
                  onPreviousMonth: () => changeMonth(-1),
                  onNextMonth: canMoveForward ? () => changeMonth(1) : null,
                ),
              3 => _EmployeeDocuments(data: data, onRefresh: refresh),
              4 => _EmployeeProfile(
                  profile: widget.profile,
                  data: data,
                  onRefresh: refresh,
                ),
              _ => const SizedBox.shrink(),
            };
          },
        );
      },
    );
  }

  Widget onboardingNavigationMarker(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomInset + 10,
      height: 60,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: AnimatedBuilder(
              animation: tabs,
              builder: (context, _) {
                return NavigationBar(
                  height: 60,
                  selectedIndex: tabs.currentIndex,
                  destinations: onboardingDestinations,
                  onDestinationSelected: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PersistentTabShell(
          controller: tabs,
          navigationStorageKey: 'employee',
          returnToFirstTabOnBack: true,
          items: items,
          tabBuilder: rootPage,
        ),
        onboardingNavigationMarker(context),
      ],
    );
  }
}

class _EmployeeLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _EmployeeLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppPage(
      title: 'Личный кабинет',
      subtitle: 'Не удалось загрузить данные',
      child: PremiumWorkCard(
        child: Column(
          children: [
            _IconTile(icon: Icons.cloud_off_rounded, size: 62),
            const SizedBox(height: 18),
            Text(
              'Кабинет не загрузился',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeHome extends StatelessWidget {
  final EmployeeCabinetData data;
  final Future<void> Function() onRefresh;

  const _EmployeeHome({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final words = data.fullName.trim().split(RegExp(r'\s+'));
    final firstName = words.isEmpty || words.first.isEmpty
        ? 'сотрудник'
        : words.first;
    final task = data.currentTask;
    final subtitle = data.currentObject.isEmpty
        ? 'Личный рабочий кабинет'
        : 'Объект: ${data.currentObject}';

    return AppPage(
      title: 'Главная',
      subtitle: subtitle,
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            child: Row(
              children: [
                const _IconTile(icon: Icons.engineering_rounded, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Привет, $firstName',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.profession.isEmpty
                            ? 'Сотрудник AppСтрой'
                            : data.profession,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                        'Задача на сегодня',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (task != null) _StatusBadge(text: task.status),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  task?.work.trim().isNotEmpty == true
                      ? task!.work
                      : 'Пока задача не назначена',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (task != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    <String>[
                      if (task.axes.isNotEmpty) task.axes,
                      if (task.objectName.isNotEmpty) task.objectName,
                      if (task.date != null) _formatDate(task.date!),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'После назначения здесь появятся описание, срок и рабочие действия.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                ],
                const SizedBox(height: 18),
                PremiumActionButton(
                  label: task == null ? 'Нет активной задачи' : 'Начать работу',
                  icon: Icons.play_arrow_rounded,
                  onPressed: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _TwoStatRow(
            left: _StatCard(
              icon: Icons.calendar_month_rounded,
              value: _formatDecimal(data.summary.shifts),
              label: 'смен в месяце',
            ),
            right: _StatCard(
              icon: Icons.verified_rounded,
              value: '${data.summary.completedTasks}',
              label: 'задач выполнено',
            ),
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
                        'Расчёт за ${_monthTitle(data.month).toLowerCase()}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MoneyLine(
                  title: 'Предварительно начислено',
                  value: _formatMoney(data.summary.estimatedAccrued),
                ),
                _MoneyLine(
                  title: 'Выплаты и авансы',
                  value: _formatMoney(data.summary.paidCurrentMonth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTasks extends StatelessWidget {
  final EmployeeCabinetData data;
  final Future<void> Function() onRefresh;

  const _EmployeeTasks({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Задачи',
      subtitle:
          '${data.summary.plannedTasks} в работе · ${data.summary.completedTasks} выполнено',
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.tasks.isEmpty)
            const _EmptySection(
              icon: Icons.task_alt_rounded,
              title: 'Задач пока нет',
              text: 'Назначенные мастером задачи появятся здесь автоматически.',
            )
          else
            for (var index = 0; index < data.tasks.length; index++) ...[
              _TaskCard(task: data.tasks[index]),
              if (index != data.tasks.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final EmployeeCabinetTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconTile(icon: Icons.assignment_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.work.isEmpty ? 'Рабочая задача' : task.work,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(text: task.status),
            ],
          ),
          const SizedBox(height: 10),
          if (task.axes.isNotEmpty)
            _DetailLine(icon: Icons.grid_4x4_rounded, text: task.axes),
          if (task.objectName.isNotEmpty)
            _DetailLine(icon: Icons.apartment_rounded, text: task.objectName),
          if (task.date != null)
            _DetailLine(
              icon: Icons.calendar_today_outlined,
              text: _formatDate(task.date!),
            ),
          if (task.photoRequirementsEnforced)
            const _DetailLine(
              icon: Icons.photo_camera_outlined,
              text: 'Для задачи нужны фотографии',
            ),
          if (task.notDoneComment.isNotEmpty)
            _DetailLine(
              icon: Icons.info_outline_rounded,
              text: task.notDoneComment,
            ),
        ],
      ),
    );
  }
}

class _EmployeeTimesheet extends StatelessWidget {
  final EmployeeCabinetData data;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onPreviousMonth;
  final Future<void> Function()? onNextMonth;

  const _EmployeeTimesheet({
    required this.data,
    required this.onRefresh,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(data.year, data.month + 1, 0).day;
    final leadingCells = DateTime(data.year, data.month, 1).weekday - 1;
    final usedCells = leadingCells + daysInMonth;
    final trailingCells = (7 - usedCells % 7) % 7;
    final itemCount = usedCells + trailingCells;
    final remainder =
        data.summary.estimatedAccrued - data.summary.paidCurrentMonth;
    final payments = data.paymentsForMonth;

    return AppPage(
      title: 'Табель',
      subtitle: 'Нажми на день, чтобы увидеть подробности',
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Предыдущий месяц',
                      onPressed: onPreviousMonth,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_monthTitle(data.month)} ${data.year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующий месяц',
                      onPressed: onNextMonth,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final weekday in const <String>[
                      'Пн',
                      'Вт',
                      'Ср',
                      'Чт',
                      'Пт',
                      'Сб',
                      'Вс',
                    ])
                      Expanded(
                        child: Center(
                          child: Text(
                            weekday,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: itemCount,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - leadingCells + 1;
                    if (day < 1 || day > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final records = data.attendanceForDay(day);
                    return _TimesheetDayCell(
                      year: data.year,
                      month: data.month,
                      day: day,
                      records: records,
                      onTap: () => _showDayDetails(
                        context,
                        year: data.year,
                        month: data.month,
                        day: day,
                        records: records,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _CalendarLegend(
                      icon: Icons.check_circle_rounded,
                      label: 'Работал',
                      kind: _DayKind.worked,
                    ),
                    _CalendarLegend(
                      icon: Icons.cancel_rounded,
                      label: 'Неявка',
                      kind: _DayKind.noShow,
                    ),
                    _CalendarLegend(
                      icon: Icons.remove_circle_outline_rounded,
                      label: 'Нет записи',
                      kind: _DayKind.empty,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _TwoStatRow(
            left: _StatCard(
              icon: Icons.event_available_rounded,
              value: _formatDecimal(data.summary.shifts),
              label: 'смен',
            ),
            right: _StatCard(
              icon: Icons.schedule_rounded,
              value: _formatDecimal(data.summary.hours),
              label: 'часов',
            ),
          ),
          const SizedBox(height: 14),
          PremiumWorkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _IconTile(icon: Icons.payments_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Расчёт за месяц',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MoneyLine(
                  title: 'Предварительно начислено',
                  value: _formatMoney(data.summary.estimatedAccrued),
                ),
                _MoneyLine(
                  title: 'Получено с учётом удержаний',
                  value: _formatMoney(data.summary.paidCurrentMonth),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _MoneyLine(
                  title: 'Предварительный остаток',
                  value: _formatMoney(remainder),
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Выплаты за период',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (payments.isEmpty)
            const _EmptySection(
              icon: Icons.receipt_long_outlined,
              title: 'Выплат за этот месяц нет',
              text:
                  'Авансы, выплаты и удержания появятся после внесения бухгалтером.',
            )
          else
            for (var index = 0; index < payments.length; index++) ...[
              _PaymentCard(payment: payments[index]),
              if (index != payments.length - 1) const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          Text(
            'Начисление предварительное. Окончательный расчёт подтверждает бухгалтерия.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDayDetails(
    BuildContext context, {
    required int year,
    required int month,
    required int day,
    required List<EmployeeCabinetAttendance> records,
  }) async {
    final totalShifts = records.fold<double>(
      0,
      (total, record) => total + record.shifts,
    );
    final totalHours = records.fold<double>(
      0,
      (total, record) => total + record.hours,
    );
    final totalAmount = records.fold<double>(
      0,
      (total, record) => total + record.estimatedAmount,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: PremiumWorkCard(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(DateTime(year, month, day)),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const _EmptySection(
                      icon: Icons.event_busy_outlined,
                      title: 'Записи в табеле нет',
                      text:
                          'Если смена была, обратись к мастеру или руководителю для проверки.',
                    )
                  else ...[
                    for (final record in records) ...[
                      _AttendanceRecordCard(record: record),
                      const SizedBox(height: 10),
                    ],
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    _MoneyLine(
                      title: 'Всего смен',
                      value: _formatDecimal(totalShifts),
                    ),
                    _MoneyLine(
                      title: 'Всего часов',
                      value: _formatDecimal(totalHours),
                    ),
                    _MoneyLine(
                      title: 'Предварительно за день',
                      value: _formatMoney(totalAmount),
                      strong: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final EmployeeCabinetPayment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final color = payment.isFine
        ? AppAdaptivePalette.danger
        : AppAdaptivePalette.success;
    return PremiumWorkCard(
      child: Row(
        children: [
          _IconTile(
            icon: payment.isFine
                ? Icons.remove_circle_outline_rounded
                : Icons.payments_outlined,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.isFine ? 'Удержание' : 'Выплата',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[
                    if (payment.date != null) _formatDate(payment.date!),
                    if (payment.comment.isNotEmpty) payment.comment,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${payment.isFine ? '−' : '+'}${_formatMoney(payment.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRecordCard extends StatelessWidget {
  final EmployeeCabinetAttendance record;

  const _AttendanceRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final kind = _kindForRecords(<EmployeeCabinetAttendance>[record]);
    final color = _dayColor(kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _attendanceStatusTitle(record.status),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (record.objectName.isNotEmpty)
            _DetailLine(
              icon: Icons.apartment_rounded,
              text: record.objectName,
            ),
          _DetailLine(
            icon: Icons.event_available_rounded,
            text: '${_formatDecimal(record.shifts)} смен',
          ),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text: '${_formatDecimal(record.hours)} часов',
          ),
          if (record.estimatedAmount != 0)
            _DetailLine(
              icon: Icons.payments_outlined,
              text: 'Предварительно ${_formatMoney(record.estimatedAmount)}',
            ),
        ],
      ),
    );
  }
}

class _EmployeeDocuments extends StatelessWidget {
  final EmployeeCabinetData data;
  final Future<void> Function() onRefresh;

  const _EmployeeDocuments({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Документы',
      subtitle: '${data.summary.documents} документов в кабинете',
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.documents.isEmpty)
            const _EmptySection(
              icon: Icons.folder_copy_rounded,
              title: 'Документы пока не добавлены',
              text:
                  'Подготовленные кадровые и рабочие документы появятся здесь.',
            )
          else
            for (var index = 0; index < data.documents.length; index++) ...[
              PremiumWorkCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const _IconTile(
                    icon: Icons.description_outlined,
                  ),
                  title: Text(
                    data.documents[index].title.isEmpty
                        ? 'Документ'
                        : data.documents[index].title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${_documentTypeTitle(data.documents[index].type)} · '
                    '${_documentStatusTitle(data.documents[index].status)}',
                  ),
                  trailing: const Icon(Icons.lock_outline_rounded),
                ),
              ),
              if (index != data.documents.length - 1)
                const SizedBox(height: 12),
            ],
          const SizedBox(height: 12),
          Text(
            'Документы доступны для просмотра статуса. Защищённое скачивание будет подключено отдельно.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeProfile extends StatelessWidget {
  final AppUserProfile profile;
  final EmployeeCabinetData data;
  final Future<void> Function() onRefresh;

  const _EmployeeProfile({
    required this.profile,
    required this.data,
    required this.onRefresh,
  });

  Future<void> exit() async {
    if (profile.isRolePreview) {
      RolePreviewController.showAdmin();
      return;
    }
    await UserRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Профиль',
      subtitle: 'Личные и рабочие данные',
      onRefresh: onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            child: Column(
              children: [
                const _IconTile(icon: Icons.person_rounded, size: 76),
                const SizedBox(height: 14),
                Text(
                  data.fullName.trim().isEmpty ? 'Сотрудник' : data.fullName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (data.profession.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    data.profession,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                const SizedBox(height: 20),
                _ProfileLine(
                  icon: Icons.phone_outlined,
                  label: 'Телефон',
                  value: data.phone.isEmpty ? 'Не указан' : data.phone,
                ),
                _ProfileLine(
                  icon: Icons.location_on_outlined,
                  label: 'Объект',
                  value: data.currentObject.isEmpty
                      ? 'Не назначен'
                      : data.currentObject,
                ),
                _ProfileLine(
                  icon: Icons.payments_outlined,
                  label: 'Ставка',
                  value: data.dailyRate <= 0
                      ? 'Не указана'
                      : '${_formatMoney(data.dailyRate)} в смену',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const PremiumWorkCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _IconTile(icon: Icons.groups_2_outlined),
              title: Text(
                'Сообщество AppСтрой',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Скоро: профиль, портфолио, вакансии и работодатели',
              ),
              trailing: Icon(Icons.lock_clock_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: exit,
              icon: Icon(
                profile.isRolePreview
                    ? Icons.admin_panel_settings_outlined
                    : Icons.logout_rounded,
              ),
              label: Text(
                profile.isRolePreview
                    ? 'Вернуться к руководителю'
                    : 'Выйти из аккаунта',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoStatRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TwoStatRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
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
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          _IconTile(icon: icon, size: 58),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;

  const _IconTile({required this.icon, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  final String title;
  final String value;
  final bool strong;

  const _MoneyLine({
    required this.title,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: strong ? 17 : 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final completed = text == 'Выполнено';
    final color = completed
        ? AppAdaptivePalette.success
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text.isEmpty ? 'В работе' : text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _DayKind { worked, noShow, empty }

class _TimesheetDayCell extends StatelessWidget {
  final int year;
  final int month;
  final int day;
  final List<EmployeeCabinetAttendance> records;
  final VoidCallback onTap;

  const _TimesheetDayCell({
    required this.year,
    required this.month,
    required this.day,
    required this.records,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kind = _kindForRecords(records);
    final totalShifts = records.fold<double>(
      0,
      (total, record) => total + record.shifts,
    );
    final totalHours = records.fold<double>(
      0,
      (total, record) => total + record.hours,
    );
    final now = DateTime.now();
    final isToday = now.year == year && now.month == month && now.day == day;
    final color = _dayColor(kind);
    final marker = switch (kind) {
      _DayKind.worked => totalShifts > 0
          ? _formatDecimal(totalShifts)
          : '${_formatDecimal(totalHours)}ч',
      _DayKind.noShow => 'Н',
      _DayKind.empty => '',
    };
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: kind == _DayKind.empty
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: isToday ? 2 : 1,
              color: isToday
                  ? scheme.primary
                  : kind == _DayKind.empty
                      ? scheme.outlineVariant
                      : color.withValues(alpha: 0.42),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
            child: Column(
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Icon(
                  switch (kind) {
                    _DayKind.worked => Icons.check_circle_rounded,
                    _DayKind.noShow => Icons.cancel_rounded,
                    _DayKind.empty => Icons.remove_rounded,
                  },
                  size: 15,
                  color: kind == _DayKind.empty
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                      : color,
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 13,
                  child: Text(
                    marker,
                    maxLines: 1,
                    style: TextStyle(
                      color: kind == _DayKind.empty
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
                          : color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final IconData icon;
  final String label;
  final _DayKind kind;

  const _CalendarLegend({
    required this.icon,
    required this.label,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = kind == _DayKind.empty ? muted : _dayColor(kind);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

_DayKind _kindForRecords(List<EmployeeCabinetAttendance> records) {
  if (records.any((record) => record.isWorked)) return _DayKind.worked;
  if (records.any((record) => record.isNoShow)) return _DayKind.noShow;
  return _DayKind.empty;
}

Color _dayColor(_DayKind kind) {
  return switch (kind) {
    _DayKind.worked => AppAdaptivePalette.success,
    _DayKind.noShow => AppAdaptivePalette.danger,
    _DayKind.empty => AppAdaptivePalette.textMuted,
  };
}

String _formatMoney(num value) {
  final rounded = value.round().toString();
  final formatted = rounded.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '$formatted ₽';
}

String _formatDecimal(num value) {
  final doubleValue = value.toDouble();
  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toInt().toString();
  }
  return doubleValue.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String _monthTitle(int month) {
  const months = <String>[
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
  if (month < 1 || month > months.length) return 'Месяц';
  return months[month - 1];
}

String _attendanceStatusTitle(String value) {
  return switch (value) {
    'worked' => 'Работал',
    'no_show' => 'Неявка',
    _ => value.trim().isEmpty ? 'Запись в табеле' : value,
  };
}

String _documentTypeTitle(String value) {
  return switch (value) {
    'employment_contract' => 'Трудовой договор',
    'employment_application' => 'Заявление на работу',
    'salary_application' => 'Заявление на перечисление зарплаты',
    'personal_data_consent' => 'Согласие на обработку данных',
    _ => value.trim().isEmpty ? 'Документ' : value,
  };
}

String _documentStatusTitle(String value) {
  return switch (value) {
    'ready' => 'Готов',
    'signed' => 'Подписан',
    'draft' => 'Черновик',
    'pending' => 'Ожидает',
    _ => value.trim().isEmpty ? 'Добавлен' : value,
  };
}
