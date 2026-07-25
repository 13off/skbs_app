import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../role_preview/role_preview_controller.dart';
import '../data/employee_cabinet_repository.dart';

class EmployeeMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeMainScreen({super.key, required this.profile});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int currentIndex = 0;
  late Future<EmployeeCabinetData> cabinetFuture;

  static const destinations = <NavigationDestination>[
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
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
      label: 'Деньги',
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
    cabinetFuture = loadCabinet();
  }

  Future<EmployeeCabinetData> loadCabinet() {
    if (widget.profile.isRolePreview) {
      return Future<EmployeeCabinetData>.value(
        EmployeeCabinetData.preview(widget.profile),
      );
    }
    return EmployeeCabinetRepository.fetch();
  }

  Future<void> refresh() async {
    final next = loadCabinet();
    setState(() => cabinetFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: FutureBuilder<EmployeeCabinetData>(
        future: cabinetFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _EmployeeLoading();
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
          final pages = <Widget>[
            _EmployeeHome(data: data, onRefresh: refresh),
            _EmployeeTasks(data: data, onRefresh: refresh),
            _EmployeeMoney(data: data, onRefresh: refresh),
            _EmployeeDocuments(data: data, onRefresh: refresh),
            _EmployeeProfile(
              profile: widget.profile,
              data: data,
              onRefresh: refresh,
            ),
          ];
          return IndexedStack(index: currentIndex, children: pages);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
      ),
    );
  }
}

class _EmployeeLoading extends StatelessWidget {
  const _EmployeeLoading();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmployeeLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _EmployeeLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _EmployeeCard(
              child: Column(
                children: [
                  const _CardIcon(icon: Icons.cloud_off_rounded, size: 62),
                  const SizedBox(height: 18),
                  Text(
                    'Кабинет не загрузился',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
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
          ),
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            Text(
              'Привет, $firstName',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              data.currentObject.isEmpty
                  ? 'Твой рабочий кабинет'
                  : 'Объект: ${data.currentObject}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 22),
            _EmployeeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _CardIcon(icon: Icons.construction_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Задача на сегодня',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: AppAdaptivePalette.textPrimary,
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
                          color: AppAdaptivePalette.textPrimary,
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
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      'После назначения здесь появятся описание, срок и рабочие действия.',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        task == null ? 'Нет активной задачи' : 'Начать работу',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SmallStatCard(
                    icon: Icons.calendar_month_rounded,
                    value: _formatDecimal(data.summary.shifts),
                    label: 'смен в месяце',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallStatCard(
                    icon: Icons.verified_rounded,
                    value: '${data.summary.completedTasks}',
                    label: 'задач выполнено',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EmployeeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _CardIcon(
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Деньги за месяц',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _SectionHeader(
              title: 'Мои задачи',
              subtitle:
                  '${data.summary.plannedTasks} в работе · ${data.summary.completedTasks} выполнено',
            ),
            const SizedBox(height: 18),
            if (data.tasks.isEmpty)
              const _EmptyEmployeeSection(
                icon: Icons.task_alt_rounded,
                title: 'Задач пока нет',
                text: 'Назначенные мастером задачи появятся здесь автоматически.',
              )
            else
              for (final task in data.tasks) ...[
                _EmployeeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.work.isEmpty ? 'Рабочая задача' : task.work,
                              style: const TextStyle(
                                fontSize: 16,
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
                        _DetailLine(
                          icon: Icons.grid_4x4_rounded,
                          text: task.axes,
                        ),
                      if (task.objectName.isNotEmpty)
                        _DetailLine(
                          icon: Icons.apartment_rounded,
                          text: task.objectName,
                        ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeMoney extends StatelessWidget {
  final EmployeeCabinetData data;
  final Future<void> Function() onRefresh;

  const _EmployeeMoney({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final remainder =
        data.summary.estimatedAccrued - data.summary.paidCurrentMonth;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _SectionHeader(
              title: 'Мои деньги',
              subtitle: '${_monthTitle(data.month)} ${data.year}',
            ),
            const SizedBox(height: 18),
            _EmployeeCard(
              child: Column(
                children: [
                  _MoneyLine(
                    title: 'Предварительно начислено',
                    value: _formatMoney(data.summary.estimatedAccrued),
                  ),
                  _MoneyLine(
                    title: 'Получено с учётом штрафов',
                    value: _formatMoney(data.summary.paidCurrentMonth),
                  ),
                  Divider(color: AppAdaptivePalette.border),
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
              'История выплат',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            if (data.payments.isEmpty)
              const _EmptyEmployeeSection(
                icon: Icons.receipt_long_outlined,
                title: 'Выплат пока нет',
                text: 'Авансы, выплаты и удержания появятся после внесения бухгалтером.',
              )
            else
              for (final payment in data.payments) ...[
                _EmployeeCard(
                  child: Row(
                    children: [
                      _CardIcon(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              <String>[
                                if (payment.date != null)
                                  _formatDate(payment.date!),
                                if (payment.comment.isNotEmpty) payment.comment,
                              ].join(' · '),
                              style: TextStyle(
                                color: AppAdaptivePalette.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${payment.isFine ? '−' : '+'}${_formatMoney(payment.amount)}',
                        style: TextStyle(
                          color: payment.isFine
                              ? AppAdaptivePalette.danger
                              : AppAdaptivePalette.success,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            Text(
              'Начисление предварительное: окончательный расчёт подтверждает бухгалтерия.',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _SectionHeader(
              title: 'Мои документы',
              subtitle: '${data.summary.documents} документов в кабинете',
            ),
            const SizedBox(height: 18),
            if (data.documents.isEmpty)
              const _EmptyEmployeeSection(
                icon: Icons.folder_copy_rounded,
                title: 'Документы пока не добавлены',
                text: 'Подготовленные кадровые и рабочие документы появятся здесь.',
              )
            else
              for (final document in data.documents) ...[
                _EmployeeCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const _CardIcon(icon: Icons.description_outlined),
                    title: Text(
                      document.title.isEmpty ? 'Документ' : document.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${_documentTypeTitle(document.type)} · ${_documentStatusTitle(document.status)}',
                    ),
                    trailing: const Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 6),
            Text(
              'На первом этапе документы доступны для просмотра статуса. Безопасное скачивание добавим отдельным шагом.',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _SectionHeader(
              title: 'Мой профиль',
              subtitle: 'Личные и рабочие данные',
            ),
            const SizedBox(height: 18),
            _EmployeeCard(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppAdaptivePalette.accentSoft,
                    child: Icon(
                      Icons.person_rounded,
                      size: 38,
                      color: AppAdaptivePalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.fullName.trim().isEmpty ? 'Сотрудник' : data.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (data.profession.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      data.profession,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
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
            _EmployeeCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const _CardIcon(icon: Icons.groups_2_outlined),
                title: const Text(
                  'Сообщество AppСтрой',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text(
                  'Скоро: рейтинг, портфолио, вакансии и работодатели',
                ),
                trailing: const Icon(Icons.lock_clock_outlined),
                onTap: () {},
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyEmployeeSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyEmployeeSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _EmployeeCard(
      child: Column(
        children: [
          _CardIcon(icon: icon, size: 62),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppAdaptivePalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppAdaptivePalette.textMuted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Widget child;

  const _EmployeeCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppAdaptivePalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _CardIcon({required this.icon, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        icon,
        color: AppAdaptivePalette.textPrimary,
        size: size * 0.52,
      ),
    );
  }
}

class _SmallStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SmallStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return _EmployeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppAdaptivePalette.textMuted),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppAdaptivePalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: strong
                    ? AppAdaptivePalette.textPrimary
                    : AppAdaptivePalette.textMuted,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: strong ? 17 : 15,
              fontWeight: FontWeight.w900,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: completed
            ? AppAdaptivePalette.success.withValues(alpha: 0.15)
            : AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.isEmpty ? 'Запланировано' : text,
        style: TextStyle(
          color: completed
              ? AppAdaptivePalette.success
              : AppAdaptivePalette.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w600,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMoney(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return '${negative ? '−' : ''}${buffer.toString()} ₽';
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

String _monthTitle(int month) {
  const titles = <String>[
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
  if (month < 1 || month > 12) return 'Текущий месяц';
  return titles[month - 1];
}

String _documentStatusTitle(String status) {
  return switch (status) {
    'ready_to_print' => 'Готов к печати',
    'printed' => 'Распечатан',
    'signed' => 'Подписан',
    'prepared' => 'Подготовлен',
    'review' => 'На проверке',
    'awaiting_signature' => 'Ожидает подписи',
    'needs_correction' => 'Нужно исправить',
    'archive' => 'В архиве',
    _ => status.isEmpty ? 'Статус не указан' : status,
  };
}

String _documentTypeTitle(String type) {
  return switch (type) {
    'employment_application' => 'Заявление на работу',
    'salary_transfer_application' => 'Перечисление зарплаты',
    'personal_data_consent' => 'Согласие на обработку данных',
    'employment_contract' => 'Трудовой договор',
    _ => type.isEmpty ? 'Рабочий документ' : type,
  };
}
