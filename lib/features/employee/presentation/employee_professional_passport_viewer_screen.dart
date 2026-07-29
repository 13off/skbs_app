import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_professional_profile_repository.dart';

class EmployeeProfessionalPassportViewerScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeProfessionalPassportViewerScreen({
    super.key,
    required this.employee,
  });

  @override
  State<EmployeeProfessionalPassportViewerScreen> createState() =>
      _EmployeeProfessionalPassportViewerScreenState();
}

class _EmployeeProfessionalPassportViewerScreenState
    extends State<EmployeeProfessionalPassportViewerScreen> {
  late Future<EmployeeProfessionalPassportData> passportFuture;

  @override
  void initState() {
    super.initState();
    passportFuture = loadPassport();
  }

  Future<EmployeeProfessionalPassportData> loadPassport() {
    return EmployeeProfessionalProfileRepository.fetchForEmployee(
      employeeId: widget.employee.id ?? '',
    );
  }

  Future<void> refresh() async {
    final next = loadPassport();
    setState(() => passportFuture = next);
    await next;
  }

  Future<void> copyResume(EmployeeProfessionalPassportData data) async {
    await Clipboard.setData(ClipboardData(text: _resumeText(data)));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профессиональное резюме скопировано')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: FutureBuilder<EmployeeProfessionalPassportData>(
        future: passportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const PremiumLoadingScreen(
              message: 'Загружаем реальные данные сотрудника',
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _PassportViewerError(
              message: snapshot.error
                      ?.toString()
                      .replaceFirst('Exception: ', '') ??
                  'Не удалось загрузить паспорт специалиста',
              onRetry: refresh,
            );
          }

          final data = snapshot.data!;
          return AppPage(
            title: data.verified.fullName.isEmpty
                ? widget.employee.name
                : data.verified.fullName,
            subtitle: 'Паспорт специалиста · реальные данные AppСтрой',
            showBackButton: true,
            onRefresh: refresh,
            child: _RealPassportBody(
              data: data,
              onCopy: () => copyResume(data),
            ),
          );
        },
      ),
    );
  }
}

class _RealPassportBody extends StatelessWidget {
  final EmployeeProfessionalPassportData data;
  final VoidCallback onCopy;

  const _RealPassportBody({required this.data, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final professional = data.professional;
    final verified = data.verified;
    final professionLine = <String>[
      if (verified.profession.isNotEmpty) verified.profession,
      if (professional.grade.isNotEmpty) professional.grade,
    ].join(' · ');
    final achievements = _achievements(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.engineering_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                verified.fullName.isEmpty ? 'Сотрудник' : verified.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                professionLine.isEmpty ? 'Профессия не указана' : professionLine,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              const _VerifiedBadge(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StatsGrid(verified: verified),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.workspace_premium_rounded,
          title: 'Подтверждено работой',
          subtitle: 'Показатели рассчитаны по рабочим данным AppСтрой',
          children: [
            _DataLine(
              icon: Icons.apartment_rounded,
              label: 'Объекты',
              value: verified.objectNames.isEmpty
                  ? 'Подтверждённых объектов пока нет'
                  : verified.objectNames.join(', '),
            ),
            _DataLine(
              icon: Icons.event_available_rounded,
              label: 'Первая подтверждённая смена',
              value: verified.firstWorkDate == null
                  ? 'Пока нет данных'
                  : DateFormat('d MMMM y', 'ru_RU')
                      .format(verified.firstWorkDate!),
            ),
            _DataLine(
              icon: Icons.location_on_rounded,
              label: 'Текущий объект',
              value: verified.currentObject.isEmpty
                  ? 'Не назначен'
                  : verified.currentObject,
            ),
            _DataLine(
              icon: Icons.description_rounded,
              label: 'Рабочие документы',
              value: '${verified.documents} подтверждено',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.person_pin_rounded,
          title: 'О специалисте',
          subtitle: 'Заполняется самим сотрудником',
          children: [
            if (professional.about.isEmpty &&
                professional.experienceYears <= 0 &&
                professional.grade.isEmpty)
              const _EmptyText(
                'Сотрудник пока не заполнил опыт, разряд и описание.',
              )
            else ...[
              if (professional.about.isNotEmpty)
                Text(
                  professional.about,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              if (professional.about.isNotEmpty) const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (professional.grade.isNotEmpty)
                    _InfoChip(
                      icon: Icons.military_tech_rounded,
                      text: professional.grade,
                    ),
                  if (professional.experienceYears > 0)
                    _InfoChip(
                      icon: Icons.history_rounded,
                      text:
                          '${_formatDecimal(professional.experienceYears)} года опыта',
                    ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.handyman_rounded,
          title: 'Навыки',
          subtitle: 'Профессиональные навыки сотрудника',
          children: [
            if (professional.skills.isEmpty)
              const _EmptyText('Сотрудник пока не указал навыки.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: professional.skills
                    .map(
                      (skill) => Chip(
                        avatar: const Icon(Icons.check_rounded, size: 17),
                        label: Text(
                          skill,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.travel_explore_rounded,
          title: 'Готовность к работе',
          subtitle: 'Данные, которые указал сотрудник',
          children: [
            _DataLine(
              icon: Icons.location_city_rounded,
              label: 'Города',
              value: professional.preferredCities.isEmpty
                  ? 'Не указаны'
                  : professional.preferredCities.join(', '),
            ),
            _DataLine(
              icon: Icons.luggage_rounded,
              label: 'Вахта',
              value: professional.readyForRotation
                  ? 'Готов к вахтовой работе'
                  : 'Не указана готовность',
            ),
            _DataLine(
              icon: Icons.work_outline_rounded,
              label: 'Предложения',
              value: professional.openToOffers
                  ? 'Открыт к предложениям'
                  : 'Не ищет предложения',
            ),
            _DataLine(
              icon: Icons.payments_outlined,
              label: 'Желаемая ставка',
              value: professional.desiredDailyRate == null
                  ? 'Не указана'
                  : '${_formatMoney(professional.desiredDailyRate!)} за смену',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.emoji_events_rounded,
          title: 'Достижения',
          subtitle: 'Открываются только по подтверждённой работе',
          children: [
            if (achievements.isEmpty)
              const _EmptyText('Подтверждённых достижений пока нет.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: achievements
                    .map((item) => _AchievementCard(item: item))
                    .toList(growable: false),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          icon: Icons.ios_share_rounded,
          title: 'Профессиональное резюме',
          subtitle: 'Без телефона, выплат и внутренних комментариев',
          children: [
            PremiumActionButton(
              label: 'Скопировать резюме',
              icon: Icons.copy_all_rounded,
              onPressed: onCopy,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final EmployeeProfessionalVerified verified;

  const _StatsGrid({required this.verified});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(
              width: width,
              icon: Icons.event_available_rounded,
              value: _formatDecimal(verified.totalShifts),
              label: 'смен',
            ),
            _StatCard(
              width: width,
              icon: Icons.schedule_rounded,
              value: _formatDecimal(verified.totalHours),
              label: 'часов',
            ),
            _StatCard(
              width: width,
              icon: Icons.task_alt_rounded,
              value: '${verified.completedTasks}',
              label: 'задач',
            ),
            _StatCard(
              width: width,
              icon: Icons.description_rounded,
              value: '${verified.documents}',
              label: 'документов',
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: PremiumWorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 23),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ...children,
        ],
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DataLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
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

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 7),
          Text(
            'Подтверждено AppСтрой',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _Achievement {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Achievement({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _AchievementCard extends StatelessWidget {
  final _Achievement item;

  const _AchievementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 24),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            item.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PassportViewerError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _PassportViewerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Паспорт специалиста',
      subtitle: 'Не удалось получить реальные данные',
      showBackButton: true,
      child: PremiumWorkCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            PremiumActionButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

List<_Achievement> _achievements(EmployeeProfessionalPassportData data) {
  final verified = data.verified;
  final result = <_Achievement>[];
  if (verified.totalShifts >= 1) {
    result.add(
      const _Achievement(
        icon: Icons.flag_rounded,
        title: 'Первая смена',
        subtitle: 'Есть подтверждённая работа',
      ),
    );
  }
  if (verified.totalShifts >= 50) {
    result.add(
      const _Achievement(
        icon: Icons.workspace_premium_rounded,
        title: '50 смен',
        subtitle: 'Стабильный опыт на объектах',
      ),
    );
  }
  if (verified.totalShifts >= 100) {
    result.add(
      const _Achievement(
        icon: Icons.military_tech_rounded,
        title: '100 смен',
        subtitle: 'Большой подтверждённый опыт',
      ),
    );
  }
  if (verified.objectNames.length >= 2) {
    result.add(
      const _Achievement(
        icon: Icons.apartment_rounded,
        title: 'Разные объекты',
        subtitle: 'Работа подтверждена на нескольких объектах',
      ),
    );
  }
  if (verified.completedTasks >= 1) {
    result.add(
      const _Achievement(
        icon: Icons.task_alt_rounded,
        title: 'Задачи выполнены',
        subtitle: 'Есть завершённые задачи',
      ),
    );
  }
  if (verified.documents >= 1) {
    result.add(
      const _Achievement(
        icon: Icons.verified_user_rounded,
        title: 'Документы',
        subtitle: 'Есть подтверждённые рабочие документы',
      ),
    );
  }
  return result;
}

String _resumeText(EmployeeProfessionalPassportData data) {
  final professional = data.professional;
  final verified = data.verified;
  final lines = <String>[
    verified.fullName,
    if (verified.profession.isNotEmpty) verified.profession,
    if (professional.grade.isNotEmpty) professional.grade,
    if (professional.experienceYears > 0)
      'Опыт: ${_formatDecimal(professional.experienceYears)} года',
    if (professional.about.isNotEmpty) professional.about,
    if (professional.skills.isNotEmpty)
      'Навыки: ${professional.skills.join(', ')}',
    if (professional.preferredCities.isNotEmpty)
      'Готов работать: ${professional.preferredCities.join(', ')}',
    if (professional.readyForRotation) 'Готов к вахтовой работе',
    if (professional.openToOffers) 'Открыт к предложениям',
    '',
    'Подтверждено в AppСтрой:',
    'Смены: ${_formatDecimal(verified.totalShifts)}',
    'Часы: ${_formatDecimal(verified.totalHours)}',
    'Выполненные задачи: ${verified.completedTasks}',
    if (verified.objectNames.isNotEmpty)
      'Объекты: ${verified.objectNames.join(', ')}',
  ];
  return lines.where((line) => line.trim().isNotEmpty || line.isEmpty).join('\n');
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatMoney(int value) {
  return '${NumberFormat.decimalPattern('ru_RU').format(value)} ₽';
}
