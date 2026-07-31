import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/settings_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/employee_task_cabinet_repository.dart';
import 'employee_simple_work_screen.dart';

class EmployeeIdentityProfileScreen extends StatefulWidget {
  final AppUserProfile profile;
  final ValueNotifier<String> selectedEmployeeId;
  final ValueListenable<String> selectedEmployeeName;

  const EmployeeIdentityProfileScreen({
    super.key,
    required this.profile,
    required this.selectedEmployeeId,
    required this.selectedEmployeeName,
  });

  @override
  State<EmployeeIdentityProfileScreen> createState() =>
      _EmployeeIdentityProfileScreenState();
}

class _EmployeeIdentityProfileScreenState
    extends State<EmployeeIdentityProfileScreen> {
  late Future<EmployeeTaskCabinetData> future;

  @override
  void initState() {
    super.initState();
    widget.selectedEmployeeId.addListener(handleEmployeeChanged);
    future = load();
  }

  @override
  void dispose() {
    widget.selectedEmployeeId.removeListener(handleEmployeeChanged);
    super.dispose();
  }

  void handleEmployeeChanged() {
    if (!mounted) return;
    setState(() => future = load());
  }

  Future<EmployeeTaskCabinetData> load() {
    return EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.selectedEmployeeId.value,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void open(Widget screen) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
    );
  }

  String initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'С';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: scheme.onSurfaceVariant, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.trim().isEmpty ? 'Не указано' : value.trim(),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget content(EmployeeTaskCabinetData data) {
    final identity = data.profile;
    final scheme = Theme.of(context).colorScheme;
    final settingsProfile = widget.profile.copyWith(
      fullName: identity.fullName,
      phone: identity.phone,
      profession: identity.profession,
      objectName: identity.currentObject,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          radius: 28,
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF73777C), Color(0xFF34373B)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  initials(identity.fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity.fullName,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Сотрудник · просмотр руководителя',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'ФИО берётся из выбранной рабочей карточки.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        infoTile(
          icon: Icons.badge_outlined,
          title: 'ФИО',
          value: identity.fullName,
        ),
        infoTile(
          icon: Icons.phone_outlined,
          title: 'Номер телефона',
          value: identity.phone,
        ),
        infoTile(
          icon: Icons.work_outline_rounded,
          title: 'Профессия',
          value: identity.profession,
        ),
        infoTile(
          icon: Icons.location_on_outlined,
          title: 'Объект',
          value: identity.currentObject,
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => open(
            EmployeeWorkTaskHistoryScreen(
              profile: settingsProfile,
              selectedEmployeeId: widget.selectedEmployeeId,
            ),
          ),
          child: PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.history_rounded),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'История задач',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4),
                      Text('Задачи и результаты работы по выбранным датам'),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeTaskCabinetData>(
      future: future,
      builder: (context, snapshot) {
        final fallbackName = widget.selectedEmployeeName.value.trim();
        return AppPage(
          title: 'Профиль',
          subtitle: fallbackName.isEmpty
              ? 'Личные и рабочие данные'
              : fallbackName,
          suppressAutomaticBackButton: true,
          headerTrailing: IconButton.filledTonal(
            tooltip: 'Настройки',
            onPressed: snapshot.data == null
                ? null
                : () {
                    final identity = snapshot.data!.profile;
                    open(
                      SettingsScreen(
                        profile: widget.profile.copyWith(
                          fullName: identity.fullName,
                          phone: identity.phone,
                          profession: identity.profession,
                          objectName: identity.currentObject,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.settings_outlined),
          ),
          onRefresh: refresh,
          child: snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData
              ? const SizedBox(
                  height: 360,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              : snapshot.hasError || snapshot.data == null
                  ? PremiumWorkCard(
                      child: Text(
                        snapshot.error
                                ?.toString()
                                .replaceFirst('Exception: ', '')
                                .trim()
                                .isNotEmpty ==
                            true
                            ? snapshot.error
                                .toString()
                                .replaceFirst('Exception: ', '')
                                .trim()
                            : 'Не удалось загрузить профиль сотрудника',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  : content(snapshot.data!),
        );
      },
    );
  }
}
