import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';

class EmployeeMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeMainScreen({super.key, required this.profile});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int currentIndex = 0;

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
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _EmployeeHome(profile: widget.profile),
      const _EmptyEmployeeSection(
        icon: Icons.task_alt_rounded,
        title: 'Мои задачи',
        text:
            'Здесь появятся текущие задачи, фото начала работы и отправка результата мастеру.',
      ),
      const _EmptyEmployeeSection(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Мои деньги',
        text:
            'Здесь сотрудник увидит смены, начисления, авансы и историю выплат.',
      ),
      const _EmptyEmployeeSection(
        icon: Icons.folder_copy_rounded,
        title: 'Мои документы',
        text:
            'Здесь будут трудовые документы, удостоверения, билеты и файлы сотрудника.',
      ),
      _EmployeeProfile(profile: widget.profile),
    ];

    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: IndexedStack(index: currentIndex, children: pages),
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

class _EmployeeHome extends StatelessWidget {
  final AppUserProfile profile;

  const _EmployeeHome({required this.profile});

  @override
  Widget build(BuildContext context) {
    final firstName = profile.fullName.trim().split(RegExp(r'\s+')).firstOrNull;
    final greetingName = firstName == null || firstName.isEmpty
        ? 'сотрудник'
        : firstName;
    final objectName = profile.objectName.trim();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: [
          Text(
            'Привет, $greetingName',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppAdaptivePalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            objectName.isEmpty ? 'Твой рабочий кабинет' : 'Объект: $objectName',
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
                    _CardIcon(icon: Icons.construction_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Задача на сегодня',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppAdaptivePalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Пока задача не назначена',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'После назначения здесь появятся описание, срок и кнопка начала работы.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppAdaptivePalette.textMuted,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Начать работу'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _SmallStatCard(
                  icon: Icons.calendar_month_rounded,
                  value: '0',
                  label: 'смен в месяце',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SmallStatCard(
                  icon: Icons.verified_rounded,
                  value: '0',
                  label: 'задач принято',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _EmployeeCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _CardIcon(icon: Icons.notifications_none_rounded),
              title: Text(
                'Важные уведомления',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('Новых уведомлений пока нет'),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeProfile extends StatelessWidget {
  final AppUserProfile profile;

  const _EmployeeProfile({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: [
          Text(
            'Мой профиль',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppAdaptivePalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
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
                  profile.fullName.trim().isEmpty
                      ? 'Сотрудник'
                      : profile.fullName.trim(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (profile.profession.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    profile.profession.trim(),
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
                  value: profile.phone.trim().isEmpty
                      ? 'Не указан'
                      : profile.phone.trim(),
                ),
                _ProfileLine(
                  icon: Icons.location_on_outlined,
                  label: 'Объект',
                  value: profile.objectName.trim().isEmpty
                      ? 'Не назначен'
                      : profile.objectName.trim(),
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
              onPressed: UserRepository.signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Выйти из аккаунта'),
            ),
          ),
        ],
      ),
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
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _EmployeeCard(
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
            ),
          ),
        ),
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
          Icon(icon, size: 21, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
