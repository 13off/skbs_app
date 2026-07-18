import 'package:flutter/material.dart';

import '../../data/object_repository.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui_v2.dart';
import 'role_preview_controller.dart';

const Color _roleText = Color(0xFF1F2328);
const Color _roleMuted = Color(0xFF6B7075);
const Color _roleSoft = Color(0xFFF1F0EC);

class RolePreviewScreen extends StatefulWidget {
  const RolePreviewScreen({super.key});

  @override
  State<RolePreviewScreen> createState() => _RolePreviewScreenState();
}

class _RolePreviewScreenState extends State<RolePreviewScreen> {
  late final Future<List<String>> objectNamesFuture;

  @override
  void initState() {
    super.initState();
    objectNamesFuture = ObjectRepository.fetchObjectNames();
  }

  void selectAdmin() => RolePreviewController.showAdmin();

  void selectDeveloper() => RolePreviewController.showDeveloper();

  void selectLawyer() => RolePreviewController.showLawyer();

  void selectAccountant() => RolePreviewController.showAccountant();

  void selectHr() => RolePreviewController.showHr();

  Future<void> selectForeman(List<String> objectNames) async {
    if (objectNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте хотя бы один объект.')),
      );
      return;
    }

    final currentObject = RolePreviewController.state.value.objectName;
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F7F3),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите объект прораба',
                style: TextStyle(
                  color: _roleText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Интерфейс и данные будут показаны так, как их видит прораб выбранного объекта.',
                style: TextStyle(
                  color: _roleMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: objectNames.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final objectName = objectNames[index];
                    final selectedNow = objectName == currentObject;
                    return PremiumPressable(
                      onTap: () => Navigator.pop(context, objectName),
                      borderRadius: BorderRadius.circular(18),
                      child: PremiumWorkCard(
                        radius: 18,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _roleSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.apartment_rounded,
                                color: _roleText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                objectName,
                                style: const TextStyle(
                                  color: _roleText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(
                              selectedNow
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: selectedNow ? _roleText : _roleMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    RolePreviewController.showForeman(objectName: selected);
  }

  Widget roleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Opacity(
          opacity: onTap == null ? 0.58 : 1,
          child: PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? _roleText : _roleSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : _roleText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: _roleText,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _roleSoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: _roleMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _roleMuted,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? _roleText : _roleMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RolePreviewState>(
      valueListenable: RolePreviewController.state,
      builder: (context, preview, _) {
        return AppPage(
          title: 'Режим платформы',
          subtitle:
              'Реальная роль администратора не меняется. Меняется только интерфейс, который вы видите.',
          child: FutureBuilder<List<String>>(
            future: objectNamesFuture,
            builder: (context, snapshot) {
              final objectNames = snapshot.data ?? const <String>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  roleCard(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Руководитель',
                    subtitle: 'Обычная платформа администратора компании.',
                    selected: preview.isAdminMode,
                    onTap: selectAdmin,
                  ),
                  roleCard(
                    icon: Icons.developer_mode_rounded,
                    title: 'Разработчик',
                    subtitle:
                        'Системные настройки, ИИ-диспетчер, ограничения и контроль платформы.',
                    selected: preview.isDeveloperMode,
                    onTap: selectDeveloper,
                    badge: 'СИСТЕМА',
                  ),
                  roleCard(
                    icon: Icons.engineering_rounded,
                    title: 'Прораб',
                    subtitle:
                        preview.isForemanMode && preview.objectName.isNotEmpty
                        ? 'Сейчас выбран объект: ${preview.objectName}'
                        : 'Показать рабочую платформу прораба выбранного объекта.',
                    selected: preview.isForemanMode,
                    onTap: snapshot.connectionState == ConnectionState.waiting
                        ? null
                        : () => selectForeman(objectNames),
                  ),
                  roleCard(
                    icon: Icons.gavel_rounded,
                    title: 'Юрист',
                    subtitle:
                        'Документы, юридические вопросы, риски и недельные отчёты.',
                    selected: preview.isLawyerMode,
                    onTap: selectLawyer,
                  ),
                  roleCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Бухгалтер',
                    subtitle:
                        'Начисления, выплаты, остатки, чеки и финансовые отчёты.',
                    selected: preview.isAccountantMode,
                    onTap: selectAccountant,
                  ),
                  roleCard(
                    icon: Icons.person_search_rounded,
                    title: 'HR-менеджер',
                    subtitle:
                        'Заявки кандидатов, документы, выезды и оформление.',
                    selected: preview.isHrMode,
                    onTap: selectHr,
                  ),
                  const SizedBox(height: 8),
                  PremiumWorkCard(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: _roleMuted),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Все действия выполняются от имени вашего администратора. Роль в компании, приглашения и права доступа в базе не изменяются.',
                            style: TextStyle(
                              color: _roleMuted,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
