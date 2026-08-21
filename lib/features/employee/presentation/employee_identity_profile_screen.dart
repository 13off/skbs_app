import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/settings_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/employee_task_cabinet_repository.dart';
import 'employee_simple_work_screen.dart';
import '../../../navigation/app_page_route.dart';

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
    Navigator.of(
      context,
    ).push<void>(AppPageRoute<void>(builder: (_) => screen));
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
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.20),
                  scheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: scheme.primary, size: 23),
          ),
          const SizedBox(width: 15),
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
                const SizedBox(height: 4),
                Text(
                  value.trim().isEmpty ? 'Не указано' : value.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
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

    // ФИО берётся из выбранной рабочей карточки.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          radius: 32,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4AABF2), Color(0xFF135A94)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.34),
                        blurRadius: 34,
                        spreadRadius: -10,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.16),
                        blurRadius: 12,
                        spreadRadius: -6,
                        offset: const Offset(-5, -6),
                      ),
                    ],
                  ),
                  child: Text(
                    initials(identity.fullName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      identity.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textWidthBasis: TextWidthBasis.parent,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 24,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.55,
                      ),
                    ),
                  ),
                ),
              ),
              if (identity.profession.trim().isNotEmpty) ...[
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    identity.profession.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 720;
            final tileWidth = twoColumns
                ? (constraints.maxWidth - 14) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: infoTile(
                    icon: Icons.badge_outlined,
                    title: 'ФИО',
                    value: identity.fullName,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: infoTile(
                    icon: Icons.phone_outlined,
                    title: 'Телефон',
                    value: identity.phone,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: infoTile(
                    icon: Icons.work_outline_rounded,
                    title: 'Профессия',
                    value: identity.profession,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: infoTile(
                    icon: Icons.location_on_outlined,
                    title: 'Объект',
                    value: identity.currentObject,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => open(
              EmployeeWorkTaskHistoryScreen(
                profile: settingsProfile,
                selectedEmployeeId: widget.selectedEmployeeId,
              ),
            ),
            child: PremiumWorkCard(
              radius: 28,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      color: scheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'История задач',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 18,
                  ),
                ],
              ),
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
          subtitle: fallbackName.isEmpty ? null : fallbackName,
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
            icon: const Icon(Icons.settings_rounded, size: 27),
          ),
          onRefresh: refresh,
          child:
              snapshot.connectionState == ConnectionState.waiting &&
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
