import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../role_preview/role_preview_controller.dart';
import '../data/employee_professional_profile_repository.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeProfessionalPassportScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeProfessionalPassportScreen({super.key, required this.profile});

  @override
  State<EmployeeProfessionalPassportScreen> createState() =>
      _EmployeeProfessionalPassportScreenState();
}

class _EmployeeProfessionalPassportScreenState
    extends State<EmployeeProfessionalPassportScreen> {
  late Future<EmployeeProfessionalPassportData> passportFuture;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    passportFuture = loadPassport();
  }

  Future<EmployeeProfessionalPassportData> loadPassport() {
    if (widget.profile.isRolePreview) {
      return Future<EmployeeProfessionalPassportData>.value(
        EmployeeProfessionalPassportData.preview(widget.profile),
      );
    }
    return EmployeeProfessionalProfileRepository.fetch();
  }

  Future<void> refresh() async {
    final next = loadPassport();
    setState(() => passportFuture = next);
    await next;
  }

  Future<void> edit(EmployeeProfessionalPassportData data) async {
    if (widget.profile.isRolePreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('В режиме просмотра изменения не сохраняются'),
        ),
      );
      return;
    }
    final result = await Navigator.of(context)
        .push<EmployeeProfessionalProfile>(
          AppPageRoute<EmployeeProfessionalProfile>(
            builder: (_) =>
                _ProfessionalPassportEditPage(initial: data.professional),
          ),
        );
    if (result == null || !mounted) return;

    setState(() => saving = true);
    try {
      final saved = await EmployeeProfessionalProfileRepository.save(result);
      if (!mounted) return;
      setState(() => passportFuture = Future.value(saved));
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Паспорт специалиста обновлён')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> copyResume(EmployeeProfessionalPassportData data) async {
    await Clipboard.setData(ClipboardData(text: _resumeText(data)));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профессиональное резюме скопировано')),
    );
  }

  Future<void> exit() async {
    if (widget.profile.isRolePreview) {
      RolePreviewController.showAdmin();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    await UserRepository.signOut();
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
              message: 'Собираем паспорт специалиста',
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _PassportLoadError(
              message:
                  snapshot.error?.toString().replaceFirst('Exception: ', '') ??
                  'Не удалось загрузить паспорт специалиста',
              onRetry: refresh,
            );
          }

          final data = snapshot.data!;
          return AppPage(
            title: 'Паспорт специалиста',
            subtitle: 'Ваш подтверждённый профессиональный профиль',
            showBackButton: true,
            onRefresh: refresh,
            headerTrailing: saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : IconButton(
                    tooltip: 'Редактировать паспорт',
                    onPressed: () => edit(data),
                    icon: const Icon(Icons.edit_rounded),
                  ),
            child: _PassportBody(
              profile: widget.profile,
              data: data,
              onEdit: () => edit(data),
              onCopy: () => copyResume(data),
              onExit: exit,
            ),
          );
        },
      ),
    );
  }
}

class _PassportBody extends StatelessWidget {
  final AppUserProfile profile;
  final EmployeeProfessionalPassportData data;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onExit;

  const _PassportBody({
    required this.profile,
    required this.data,
    required this.onEdit,
    required this.onCopy,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final professional = data.professional;
    final verified = data.verified;
    final achievements = _achievements(data);
    final completion = _completion(professional);
    final professionLine = <String>[
      if (verified.profession.isNotEmpty) verified.profession,
      if (professional.grade.isNotEmpty) professional.grade,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  Icons.engineering_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
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
                professionLine.isEmpty ? 'Специалист AppСтрой' : professionLine,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const _VerifiedBadge(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Профиль заполнен на ${completion.round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(onPressed: onEdit, child: const Text('Дополнить')),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: completion / 100,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PassportStats(verified: verified),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.workspace_premium_rounded,
                title: 'Подтверждено работой',
                subtitle:
                    'Эти показатели берутся из AppСтрой и не редактируются вручную',
              ),
              const SizedBox(height: 18),
              _VerifiedLine(
                icon: Icons.apartment_rounded,
                label: 'Объекты',
                value: verified.objectNames.isEmpty
                    ? 'Пока нет подтверждённых объектов'
                    : verified.objectNames.join(', '),
              ),
              _VerifiedLine(
                icon: Icons.event_available_rounded,
                label: 'Первая подтверждённая смена',
                value: verified.firstWorkDate == null
                    ? 'Пока нет данных'
                    : DateFormat(
                        'd MMMM y',
                        'ru_RU',
                      ).format(verified.firstWorkDate!),
              ),
              _VerifiedLine(
                icon: Icons.description_rounded,
                label: 'Рабочие документы',
                value: '${verified.documents} подтверждено в кабинете',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.person_pin_rounded,
                title: 'О специалисте',
                subtitle: 'Опыт и профессиональное описание',
              ),
              const SizedBox(height: 16),
              if (professional.about.isEmpty &&
                  professional.experienceYears <= 0 &&
                  professional.grade.isEmpty)
                _EmptyPassportSection(
                  text:
                      'Добавьте разряд, опыт и пару предложений о своей работе.',
                  onPressed: onEdit,
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
                if (professional.about.isNotEmpty) const SizedBox(height: 16),
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
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.handyman_rounded,
                title: 'Навыки',
                subtitle: 'Что вы умеете делать на объекте',
              ),
              const SizedBox(height: 16),
              if (professional.skills.isEmpty)
                _EmptyPassportSection(
                  text:
                      'Укажите основные работы и технологии, которыми владеете.',
                  onPressed: onEdit,
                )
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
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.travel_explore_rounded,
                title: 'Готовность к работе',
                subtitle: 'География, вахта и профессиональные предложения',
              ),
              const SizedBox(height: 16),
              _PreferenceLine(
                icon: Icons.location_city_rounded,
                label: 'Города',
                value: professional.preferredCities.isEmpty
                    ? 'Не указаны'
                    : professional.preferredCities.join(', '),
              ),
              _PreferenceLine(
                icon: Icons.luggage_rounded,
                label: 'Вахта',
                value: professional.readyForRotation
                    ? 'Готов к вахтовой работе'
                    : 'Не указана готовность',
              ),
              _PreferenceLine(
                icon: Icons.work_outline_rounded,
                label: 'Предложения',
                value: professional.openToOffers
                    ? 'Открыт к предложениям'
                    : 'Не ищет предложения',
              ),
              _PreferenceLine(
                icon: Icons.payments_outlined,
                label: 'Желаемая ставка',
                value: professional.desiredDailyRate == null
                    ? 'Не указана'
                    : '${_formatMoney(professional.desiredDailyRate!)} за смену',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.emoji_events_rounded,
                title: 'Достижения',
                subtitle: 'Автоматически открываются по подтверждённой работе',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: achievements
                    .map((achievement) => _AchievementCard(data: achievement))
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.ios_share_rounded,
                title: 'Профессиональное резюме',
                subtitle: 'Можно отправить прорабу, работодателю или знакомому',
              ),
              const SizedBox(height: 14),
              Text(
                'В копию попадут профессия, навыки, опыт и подтверждённые результаты. Телефон, выплаты и внутренние комментарии не включаются.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              PremiumActionButton(
                label: 'Скопировать резюме',
                icon: Icons.copy_all_rounded,
                onPressed: onCopy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.shield_outlined,
                title: 'Аккаунт сотрудника',
                subtitle: 'Эти данные видны только вам и вашей компании',
              ),
              const SizedBox(height: 12),
              _AccountLine(
                icon: Icons.phone_outlined,
                label: 'Телефон для входа',
                value: profile.phone.trim().isEmpty
                    ? 'Не указан'
                    : profile.phone.trim(),
              ),
              _AccountLine(
                icon: Icons.location_on_outlined,
                label: 'Текущий объект',
                value: verified.currentObject.isEmpty
                    ? 'Не назначен'
                    : verified.currentObject,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onExit,
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
      ],
    );
  }
}

class _PassportStats extends StatelessWidget {
  final EmployeeProfessionalVerified verified;

  const _PassportStats({required this.verified});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final items = <Widget>[
          _PassportStat(
            icon: Icons.calendar_month_rounded,
            value: _formatDecimal(verified.totalShifts),
            label: 'смен',
          ),
          _PassportStat(
            icon: Icons.schedule_rounded,
            value: _formatDecimal(verified.totalHours),
            label: 'часов',
          ),
          _PassportStat(
            icon: Icons.task_alt_rounded,
            value: '${verified.completedTasks}',
            label: 'задач',
          ),
          _PassportStat(
            icon: Icons.apartment_rounded,
            value: '${verified.objectNames.length}',
            label: 'объектов',
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((item) => SizedBox(width: width, child: item))
              .toList(growable: false),
        );
      },
    );
  }
}

class _PassportStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _PassportStat({
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
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
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

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final color = AppAdaptivePalette.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 18, color: color),
          const SizedBox(width: 7),
          Text(
            'Подтверждено AppСтрой',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerifiedLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _VerifiedLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.verified_rounded,
            size: 17,
            color: AppAdaptivePalette.success,
          ),
        ],
      ),
    );
  }
}

class _PreferenceLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreferenceLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AccountLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _VerifiedLine(icon: icon, label: label, value: value);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyPassportSection extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _EmptyPassportSection({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _AchievementData {
  final IconData icon;
  final String title;
  final String text;

  const _AchievementData({
    required this.icon,
    required this.title,
    required this.text,
  });
}

class _AchievementCard extends StatelessWidget {
  final _AchievementData data;

  const _AchievementCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 250),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  data.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

class _PassportLoadError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _PassportLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Паспорт специалиста',
      subtitle: 'Не удалось загрузить данные',
      showBackButton: true,
      child: PremiumWorkCard(
        child: Column(
          children: [
            const Icon(Icons.badge_outlined, size: 58),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalPassportEditPage extends StatefulWidget {
  final EmployeeProfessionalProfile initial;

  const _ProfessionalPassportEditPage({required this.initial});

  @override
  State<_ProfessionalPassportEditPage> createState() =>
      _ProfessionalPassportEditPageState();
}

class _ProfessionalPassportEditPageState
    extends State<_ProfessionalPassportEditPage> {
  late final TextEditingController gradeController;
  late final TextEditingController experienceController;
  late final TextEditingController skillsController;
  late final TextEditingController aboutController;
  late final TextEditingController citiesController;
  late final TextEditingController rateController;
  late bool readyForRotation;
  late bool openToOffers;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    gradeController = TextEditingController(text: initial.grade);
    experienceController = TextEditingController(
      text: initial.experienceYears <= 0
          ? ''
          : _formatDecimal(initial.experienceYears),
    );
    skillsController = TextEditingController(text: initial.skills.join(', '));
    aboutController = TextEditingController(text: initial.about);
    citiesController = TextEditingController(
      text: initial.preferredCities.join(', '),
    );
    rateController = TextEditingController(
      text: initial.desiredDailyRate?.toString() ?? '',
    );
    readyForRotation = initial.readyForRotation;
    openToOffers = initial.openToOffers;
  }

  @override
  void dispose() {
    gradeController.dispose();
    experienceController.dispose();
    skillsController.dispose();
    aboutController.dispose();
    citiesController.dispose();
    rateController.dispose();
    super.dispose();
  }

  List<String> parseList(String value, int limit) {
    final result = <String>[];
    final seen = <String>{};
    for (final part in value.split(RegExp(r'[,;\n]'))) {
      final clean = part.replaceAll(RegExp(r'\s+'), ' ').trim();
      final key = clean.toLowerCase();
      if (clean.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(clean);
      if (result.length >= limit) break;
    }
    return result;
  }

  void save() {
    final experience =
        double.tryParse(
          experienceController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    final rawRate = rateController.text.replaceAll(RegExp(r'\D'), '');
    final desiredRate = rawRate.isEmpty ? null : int.tryParse(rawRate);
    if (experience < 0 || experience > 70) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опыт должен быть от 0 до 70 лет')),
      );
      return;
    }
    if (desiredRate != null && desiredRate > 10000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проверьте желаемую ставку')),
      );
      return;
    }

    Navigator.of(context).pop(
      EmployeeProfessionalProfile(
        grade: gradeController.text.trim(),
        experienceYears: experience,
        skills: parseList(skillsController.text, 20),
        about: aboutController.text.trim(),
        preferredCities: parseList(citiesController.text, 12),
        readyForRotation: readyForRotation,
        openToOffers: openToOffers,
        desiredDailyRate: desiredRate,
        updatedAt: widget.initial.updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: AppPage(
        title: 'Редактировать паспорт',
        subtitle: 'Личные профессиональные данные',
        showBackButton: true,
        headerTrailing: IconButton(
          tooltip: 'Сохранить',
          onPressed: save,
          icon: const Icon(Icons.check_rounded),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PremiumWorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.person_pin_rounded,
                    title: 'Квалификация',
                    subtitle: 'Разряд, опыт и описание работы',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: gradeController,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Разряд или уровень',
                      hintText: 'Например: 5 разряд',
                      prefixIcon: Icon(Icons.military_tech_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: experienceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Опыт работы, лет',
                      hintText: 'Например: 4,5',
                      prefixIcon: Icon(Icons.history_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aboutController,
                    maxLength: 800,
                    minLines: 4,
                    maxLines: 7,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'О себе и своей работе',
                      hintText:
                          'Какие работы выполняете, за что отвечаете, что для вас важно на объекте',
                      alignLabelWithHint: true,
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
                  const _SectionTitle(
                    icon: Icons.handyman_rounded,
                    title: 'Навыки',
                    subtitle: 'До 20 навыков через запятую',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: skillsController,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Профессиональные навыки',
                      hintText:
                          'Армирование, опалубка, бетонирование, чтение чертежей',
                      alignLabelWithHint: true,
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
                  const _SectionTitle(
                    icon: Icons.travel_explore_rounded,
                    title: 'Условия работы',
                    subtitle: 'Где и в каком формате готовы работать',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: citiesController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Города и регионы',
                      hintText: 'Мурманск, Москва, Норильск',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Желаемая ставка за смену',
                      hintText: '6000',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: '₽',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Готов к вахте',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Показывает готовность к длительной работе на другом объекте',
                    ),
                    value: readyForRotation,
                    onChanged: (value) {
                      setState(() => readyForRotation = value);
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Открыт к предложениям',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Пока это только личная настройка: профиль не публикуется автоматически',
                    ),
                    value: openToOffers,
                    onChanged: (value) {
                      setState(() => openToOffers = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Сохранить паспорт'),
            ),
          ],
        ),
      ),
    );
  }
}

double _completion(EmployeeProfessionalProfile profile) {
  var completed = 0;
  const total = 6;
  if (profile.grade.isNotEmpty) completed++;
  if (profile.experienceYears > 0) completed++;
  if (profile.about.isNotEmpty) completed++;
  if (profile.skills.isNotEmpty) completed++;
  if (profile.preferredCities.isNotEmpty || profile.readyForRotation)
    completed++;
  if (profile.desiredDailyRate != null || profile.openToOffers) completed++;
  return completed / total * 100;
}

List<_AchievementData> _achievements(EmployeeProfessionalPassportData data) {
  final verified = data.verified;
  final professional = data.professional;
  final result = <_AchievementData>[];

  if (verified.totalShifts >= 1) {
    result.add(
      const _AchievementData(
        icon: Icons.flag_rounded,
        title: 'Первая смена',
        text: 'Начало подтверждённой истории',
      ),
    );
  }
  if (verified.totalShifts >= 50) {
    result.add(
      const _AchievementData(
        icon: Icons.calendar_month_rounded,
        title: '50 смен',
        text: 'Стабильная работа на объектах',
      ),
    );
  }
  if (verified.totalShifts >= 100) {
    result.add(
      const _AchievementData(
        icon: Icons.workspace_premium_rounded,
        title: '100 смен',
        text: 'Серьёзный подтверждённый опыт',
      ),
    );
  }
  if (verified.completedTasks >= 10) {
    result.add(
      const _AchievementData(
        icon: Icons.task_alt_rounded,
        title: '10 задач',
        text: 'Результат подтверждён работой',
      ),
    );
  }
  if (verified.objectNames.length >= 2) {
    result.add(
      const _AchievementData(
        icon: Icons.apartment_rounded,
        title: 'Несколько объектов',
        text: 'Опыт в разных командах и условиях',
      ),
    );
  }
  if (verified.documents > 0) {
    result.add(
      const _AchievementData(
        icon: Icons.verified_user_rounded,
        title: 'Документы в порядке',
        text: 'Есть подтверждённые документы',
      ),
    );
  }
  if (professional.grade.isNotEmpty) {
    result.add(
      _AchievementData(
        icon: Icons.military_tech_rounded,
        title: professional.grade,
        text: 'Квалификация указана в паспорте',
      ),
    );
  }
  if (result.isEmpty) {
    result.add(
      const _AchievementData(
        icon: Icons.rocket_launch_rounded,
        title: 'Начало пути',
        text: 'Достижения появятся вместе с работой',
      ),
    );
  }
  return result;
}

String _resumeText(EmployeeProfessionalPassportData data) {
  final professional = data.professional;
  final verified = data.verified;
  final lines = <String>[
    'ПАСПОРТ СПЕЦИАЛИСТА APPСТРОЙ',
    '',
    verified.fullName.isEmpty ? 'Сотрудник' : verified.fullName,
    <String>[
      if (verified.profession.isNotEmpty) verified.profession,
      if (professional.grade.isNotEmpty) professional.grade,
    ].join(' · '),
    if (professional.experienceYears > 0)
      'Опыт: ${_formatDecimal(professional.experienceYears)} года',
    if (professional.about.isNotEmpty) '',
    if (professional.about.isNotEmpty) professional.about,
    if (professional.skills.isNotEmpty) '',
    if (professional.skills.isNotEmpty)
      'Навыки: ${professional.skills.join(', ')}',
    '',
    'Подтверждено в AppСтрой:',
    '• ${_formatDecimal(verified.totalShifts)} смен',
    '• ${verified.completedTasks} выполненных задач',
    '• ${verified.objectNames.length} объектов',
    '• ${verified.documents} рабочих документов',
    if (verified.objectNames.isNotEmpty)
      'Объекты: ${verified.objectNames.join(', ')}',
    if (professional.preferredCities.isNotEmpty) '',
    if (professional.preferredCities.isNotEmpty)
      'Готов работать: ${professional.preferredCities.join(', ')}',
    if (professional.readyForRotation) 'Готов к вахтовой работе',
    if (professional.openToOffers) 'Открыт к профессиональным предложениям',
    if (professional.openToOffers && professional.desiredDailyRate != null)
      'Желаемая ставка: ${_formatMoney(professional.desiredDailyRate!)} за смену',
  ];
  return lines.where((line) => line.isNotEmpty || lines.isNotEmpty).join('\n');
}

String _formatMoney(num value) {
  return '${NumberFormat('#,##0', 'ru_RU').format(value).replaceAll(',', ' ')} ₽';
}

String _formatDecimal(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
