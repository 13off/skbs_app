import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/template_documents_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../archive/presentation/archive_management_screen_v3.dart';
import '../../documents/data/document_workflow_repository.dart';
import '../../documents/models/document_onboarding.dart';
import '../../documents/presentation/document_generation_screen.dart';
import '../../documents/presentation/document_package_management_screen.dart';
import '../../documents/presentation/document_workflow_screen.dart';
import 'document_tool_feature_gate.dart';

class CompanyToolsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const CompanyToolsScreen({super.key, required this.profile});

  @override
  State<CompanyToolsScreen> createState() => _CompanyToolsScreenState();
}

class _CompanyToolsScreenState extends State<CompanyToolsScreen> {
  late Future<_ToolsData> future;
  bool changing = false;

  String get companyId => widget.profile.activeCompanyId.trim();

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_ToolsData> _load() async {
    if (companyId.isEmpty) {
      throw StateError('Сначала выберите активную компанию');
    }
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      DocumentWorkflowRepository.fetchAccess(),
      DocumentWorkflowRepository.fetchInstallation(companyId),
    ]);
    return _ToolsData(
      access: values[0] as DocumentWorkflowAccess,
      installation: values[1] as DocumentToolInstallation,
    );
  }

  Future<void> _refresh() async {
    setState(() => future = _load());
    await future;
  }

  Future<void> _setEnabled(_ToolsData data, bool enabled) async {
    if (changing || !data.access.canManage) return;
    if (!enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Отключить инструмент?'),
          content: const Text(
            'Оформления, шаблоны, документы и архивы сохранятся. '
            'Рабочие функции снова появятся после включения.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отключить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => changing = true);
    try {
      await DocumentWorkflowRepository.setInstallation(
        companyId: companyId,
        isEnabled: enabled,
        settings: data.installation.settings,
      );
      DocumentToolAvailability.notifyChanged();
      await _refresh();
      _message(
        enabled
            ? '«AppСтрой Трудоустройство» включён'
            : 'Инструмент отключён. Все данные сохранены',
      );
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  void _openWorkspace(_ToolsData data) {
    if (!data.installation.isEnabled || !data.access.canView) return;
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => DocumentToolWorkspaceScreen(
          profile: widget.profile,
          access: data.access,
        ),
      ),
    );
  }

  void _showInfo(_ToolsData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ToolInfoSheet(
        enabled: data.installation.isEnabled,
        canManage: data.access.canManage,
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Инструменты',
      onRefresh: _refresh,
      child: FutureBuilder<_ToolsData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _ErrorCard(
              message: _cleanError(snapshot.error),
              onRetry: _refresh,
            );
          }
          final data = snapshot.requireData;
          if (!data.access.hasEntry) {
            return const PremiumWorkCard(
              radius: 24,
              child: Text('Для вашей роли нет доступных инструментов.'),
            );
          }

          return _EmploymentToolCard(
            access: data.access,
            installation: data.installation,
            changing: changing,
            onOpen: () => _openWorkspace(data),
            onInfo: () => _showInfo(data),
            onEnable: () => _setEnabled(data, true),
            onDisable: () => _setEnabled(data, false),
          );
        },
      ),
    );
  }
}

class DocumentToolWorkspaceScreen extends StatelessWidget {
  final AppUserProfile profile;
  final DocumentWorkflowAccess access;

  const DocumentToolWorkspaceScreen({
    super.key,
    required this.profile,
    required this.access,
  });

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AppСтрой Трудоустройство',
      subtitle: 'Рабочий инструмент',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Разделы',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (access.canView)
            _ToolActionCard(
              icon: Icons.fact_check_outlined,
              title: 'Оформления',
              onTap: () =>
                  _open(context, DocumentWorkflowScreen(profile: profile)),
            ),
          if (access.canEdit)
            _ToolActionCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Генератор документов',
              onTap: () =>
                  _open(context, DocumentGenerationScreen(profile: profile)),
            ),
          if (access.canManagePackages)
            _ToolActionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Пакеты документов',
              onTap: () => _open(
                context,
                DocumentPackageManagementScreen(profile: profile),
              ),
            ),
          if (access.canViewTemplates)
            _ToolActionCard(
              icon: Icons.description_outlined,
              title: 'Шаблоны',
              onTap: () =>
                  _open(context, TemplateDocumentsScreen(profile: profile)),
            ),
          if (access.canViewAudit)
            _ToolActionCard(
              icon: Icons.archive_outlined,
              title: 'Архив',
              onTap: () =>
                  _open(context, ArchiveManagementScreenV3(profile: profile)),
            ),
        ],
      ),
    );
  }
}

class DocumentToolAppShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const DocumentToolAppShortcut({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 168,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ToolLogo(size: 62),
              const SizedBox(height: 12),
              Text(
                'AppСтрой\nТрудоустройство',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmploymentToolCard extends StatelessWidget {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation installation;
  final bool changing;
  final VoidCallback onOpen;
  final VoidCallback onInfo;
  final VoidCallback onEnable;
  final VoidCallback onDisable;

  const _EmploymentToolCard({
    required this.access,
    required this.installation,
    required this.changing,
    required this.onOpen,
    required this.onInfo,
    required this.onEnable,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = installation.isEnabled;
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          const _ToolLogo(size: 52),
          const SizedBox(width: 13),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled && access.canView && !changing ? onOpen : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'AppСтрой Трудоустройство',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Подробно об инструменте',
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 58,
            height: 48,
            child: changing
                ? const Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : Switch.adaptive(
                    value: enabled,
                    onChanged: access.canManage
                        ? (value) {
                            if (value) {
                              onEnable();
                            } else {
                              onDisable();
                            }
                          }
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToolInfoSheet extends StatelessWidget {
  final bool enabled;
  final bool canManage;

  const _ToolInfoSheet({
    required this.enabled,
    required this.canManage,
  });

  static const capabilities = <_Capability>[
    _Capability(
      icon: Icons.document_scanner_outlined,
      title: 'Документы кандидата',
      text:
          'Собирает паспорт, регистрацию, СНИЛС, ИНН, полис и фото в одном оформлении без повторного копирования файлов.',
    ),
    _Capability(
      icon: Icons.fact_check_outlined,
      title: 'Распознавание и проверка',
      text:
          'Создаёт черновик распознанных данных. HR проверяет каждое значение и только после этого подтверждает сведения.',
    ),
    _Capability(
      icon: Icons.badge_outlined,
      title: 'Карточка сотрудника',
      text:
          'Создаёт нового сотрудника или связывает оформление с существующим, защищая компанию от дублей.',
    ),
    _Capability(
      icon: Icons.inventory_2_outlined,
      title: 'Пакеты и условия',
      text:
          'Позволяет выбрать должность, объект, условия вознаграждения и утверждённый комплект документов.',
    ),
    _Capability(
      icon: Icons.auto_awesome_outlined,
      title: 'Генерация DOCX',
      text:
          'Заполняет утверждённые версии шаблонов компании и сохраняет созданный документ внутри того же оформления.',
    ),
    _Capability(
      icon: Icons.draw_outlined,
      title: 'Подписание',
      text:
          'Ведёт документ через печать, подпись и загрузку подписанной версии, не смешивая исходники и финальные файлы.',
    ),
    _Capability(
      icon: Icons.archive_outlined,
      title: 'Закрытый архив',
      text:
          'Хранит версии, финальные сканы и историю действий с разграничением доступа по ролям компании.',
    ),
    _Capability(
      icon: Icons.rule_outlined,
      title: 'Контроль завершения',
      text:
          'Не даёт закрыть оформление, пока не выполнены обязательные проверки, подписи, сканы и архивные требования.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.96,
        widthFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Material(
            color: scheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Row(
                    children: [
                      const _ToolLogo(size: 54),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Text(
                          'AppСтрой Трудоустройство',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ToolHero(enabled: enabled, canManage: canManage),
                        const SizedBox(height: 28),
                        const _SectionTitle(
                          title: 'Что умеет инструмент',
                          description:
                              'Полный путь сотрудника: от файлов кандидата до проверенного архива.',
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 820
                                ? 4
                                : constraints.maxWidth >= 560
                                    ? 2
                                    : 1;
                            final width = columns == 1
                                ? constraints.maxWidth
                                : (constraints.maxWidth -
                                        (columns - 1) * 12) /
                                    columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final item in capabilities)
                                  SizedBox(
                                    width: width,
                                    child: _CapabilityCard(item: item),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        const _SectionTitle(
                          title: 'Кто и за что отвечает',
                          description:
                              'Каждый сотрудник видит только доступные ему действия.',
                        ),
                        const SizedBox(height: 14),
                        const _RoleFlow(),
                        const SizedBox(height: 30),
                        const _SectionTitle(
                          title: 'Как работать с инструментом',
                          description:
                              'Пройдите весь сценарий. Внутри каждого шага показано, что нажать, что проверить и какой результат должен получиться.',
                        ),
                        const SizedBox(height: 14),
                        const _WorkflowGuide(),
                        const SizedBox(height: 30),
                        const _ArchiveRuleCard(),
                      ],
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

class _ToolHero extends StatelessWidget {
  final bool enabled;
  final bool canManage;

  const _ToolHero({
    required this.enabled,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Кадровое оформление как управляемый процесс',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Инструмент объединяет документы кандидата, проверку персональных данных, создание карточки сотрудника, выбор условий и пакета, генерацию DOCX, печать, подписание, финальные сканы и защищённый архив. Этапы связаны между собой, поэтому оформление не теряется между чатами, папками и разными сотрудниками.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeatureChip(
                icon: Icons.people_alt_outlined,
                label: 'Кандидат и сотрудник',
              ),
              _FeatureChip(
                icon: Icons.description_outlined,
                label: 'Шаблоны и версии',
              ),
              _FeatureChip(
                icon: Icons.verified_user_outlined,
                label: 'Права и аудит',
              ),
              _FeatureChip(
                icon: Icons.folder_copy_outlined,
                label: 'Единый архив',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                enabled
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_outline_rounded,
                color: enabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  enabled
                      ? 'Инструмент подключён для компании'
                      : 'Инструмент пока не подключён',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (!canManage)
                Text(
                  'Управляет администратор',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String description;

  const _SectionTitle({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final _Capability item;

  const _CapabilityCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 176),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(item.icon, color: scheme.primary),
          ),
          const SizedBox(height: 13),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.text,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleFlow extends StatelessWidget {
  const _RoleFlow();

  static const roles = <_RoleInfo>[
    _RoleInfo(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Владелец / администратор',
      text:
          'Подключает инструмент, настраивает права, шаблоны и пакеты документов.',
    ),
    _RoleInfo(
      icon: Icons.person_search_outlined,
      title: 'HR',
      text:
          'Загружает исходники, проверяет данные, создаёт карточку и ведёт оформление по этапам.',
    ),
    _RoleInfo(
      icon: Icons.gavel_outlined,
      title: 'Юрист / ответственный',
      text:
          'Контролирует утверждённые шаблоны, формулировки, подписанные версии и обязательные проверки.',
    ),
    _RoleInfo(
      icon: Icons.manage_search_outlined,
      title: 'Руководитель',
      text:
          'Видит статус, блокирующие причины, историю действий и готовность сотрудника.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < roles.length; index++) ...[
                  Expanded(child: _RoleTile(info: roles[index])),
                  if (index != roles.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < roles.length; index++) ...[
                _RoleTile(info: roles[index]),
                if (index != roles.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final _RoleInfo info;

  const _RoleTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(info.icon, color: scheme.primary),
          const SizedBox(height: 10),
          Text(
            info.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            info.text,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowGuide extends StatefulWidget {
  const _WorkflowGuide();

  @override
  State<_WorkflowGuide> createState() => _WorkflowGuideState();
}

class _WorkflowGuideState extends State<_WorkflowGuide> {
  final PageController controller = PageController();
  int page = 0;

  static const steps = <_GuideStep>[
    _GuideStep(
      icon: Icons.toggle_on_outlined,
      eyebrow: 'Шаг 1 из 8',
      title: 'Подключите инструмент',
      description:
          'Владелец или администратор открывает «Инструменты» и включает тумблер. Модуль появляется в профиле компании как отдельное приложение.',
      result:
          'HR и другие роли получают только разрешённые им разделы. Отключение позже не удалит документы и историю.',
      previewRows: ['Тумблер включён', 'Права ролей загружены', 'Модуль в профиле'],
    ),
    _GuideStep(
      icon: Icons.upload_file_outlined,
      eyebrow: 'Шаг 2 из 8',
      title: 'Загрузите исходные документы',
      description:
          'Создайте оформление из кандидата или существующего сотрудника. Добавьте паспорт, регистрацию, СНИЛС, ИНН, полис, фото и другие необходимые файлы.',
      result:
          'Все исходники связаны с одним оформлением. Файлы кандидата можно использовать без создания лишних копий.',
      previewRows: ['Паспорт и регистрация', 'СНИЛС, ИНН, полис', 'Фото сотрудника'],
    ),
    _GuideStep(
      icon: Icons.document_scanner_outlined,
      eyebrow: 'Шаг 3 из 8',
      title: 'Проверьте распознанные данные',
      description:
          'Система подготавливает черновик полей. HR сверяет ФИО, даты, паспорт, адреса и номера документов с оригиналами и исправляет неточности.',
      result:
          'В дальнейшие документы попадают только подтверждённые человеком данные, а не непроверенный результат распознавания.',
      previewRows: ['ФИО подтверждено', 'Паспорт проверен', 'Адрес исправлен'],
    ),
    _GuideStep(
      icon: Icons.badge_outlined,
      eyebrow: 'Шаг 4 из 8',
      title: 'Создайте карточку и выберите условия',
      description:
          'Создайте нового сотрудника либо привяжите существующего. Укажите должность, объект, дату начала, вознаграждение и нужный пакет документов.',
      result:
          'Оформление связано с единственной карточкой сотрудника и содержит полный набор условий для генерации.',
      previewRows: ['Карточка сотрудника', 'Объект и должность', 'Пакет документов'],
    ),
    _GuideStep(
      icon: Icons.auto_awesome_outlined,
      eyebrow: 'Шаг 5 из 8',
      title: 'Сгенерируйте документы',
      description:
          'Выберите утверждённую DOCX-версию шаблона. Инструмент подставит проверенные данные, сохранит связь с версией шаблона и загрузит результат в оформление.',
      result:
          'Получается редактируемый DOCX без изменения исходного шаблона. При необходимости можно загрузить готовый файл вручную.',
      previewRows: ['Шаблон утверждён', 'Поля заполнены', 'DOCX сохранён'],
    ),
    _GuideStep(
      icon: Icons.print_outlined,
      eyebrow: 'Шаг 6 из 8',
      title: 'Распечатайте и подпишите',
      description:
          'Передайте документ на печать, зафиксируйте этап подписания и загрузите подписанную версию отдельным файлом.',
      result:
          'Исходник, сгенерированная версия и подписанный документ не смешиваются. Для каждого файла сохраняется назначение и версия.',
      previewRows: ['Отправлено на печать', 'Подпись получена', 'Версия загружена'],
    ),
    _GuideStep(
      icon: Icons.scanner_outlined,
      eyebrow: 'Шаг 7 из 8',
      title: 'Добавьте финальные сканы',
      description:
          'Загрузите читаемые финальные сканы и проверьте их. Общий архив формируется по правилам компании, а соглашения, билеты и удостоверения остаются отдельными файлами.',
      result:
          'Архив содержит только принятые документы, а спорные или нечитаемые файлы можно отклонить с причиной.',
      previewRows: ['Сканы загружены', 'Качество проверено', 'Архив собран'],
    ),
    _GuideStep(
      icon: Icons.verified_outlined,
      eyebrow: 'Шаг 8 из 8',
      title: 'Завершите оформление',
      description:
          'Инструмент проверит обязательные этапы: карточку, пакет, HR-проверку, генерацию, подписанный документ и финальный скан.',
      result:
          'После устранения всех блокирующих причин оформление закрывается, а документы, версии и журнал действий остаются в защищённом архиве.',
      previewRows: ['Блокеров нет', 'Оформление завершено', 'Аудит сохранён'],
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _goTo(int value) {
    if (value < 0 || value >= steps.length) return;
    controller.animateToPage(
      value,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return Column(
            children: [
              SizedBox(
                height: wide ? 390 : 650,
                child: PageView.builder(
                  controller: controller,
                  itemCount: steps.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (context, index) => _GuideStepCard(
                    step: steps[index],
                    wide: wide,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Предыдущий шаг',
                    onPressed: page == 0 ? null : () => _goTo(page - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < steps.length; index++)
                          GestureDetector(
                            onTap: () => _goTo(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              width: page == index ? 26 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: page == index
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Следующий шаг',
                    onPressed: page == steps.length - 1
                        ? null
                        : () => _goTo(page + 1),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final _GuideStep step;
  final bool wide;

  const _GuideStepCard({
    required this.step,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _AnimatedWorkflowPreview(step: step);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 22 : 4,
        wide ? 12 : 18,
        4,
        4,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.eyebrow,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    step.result,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: preview),
          Expanded(child: content),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 235, child: preview),
        Expanded(child: content),
      ],
    );
  }
}

class _AnimatedWorkflowPreview extends StatefulWidget {
  final _GuideStep step;

  const _AnimatedWorkflowPreview({required this.step});

  @override
  State<_AnimatedWorkflowPreview> createState() =>
      _AnimatedWorkflowPreviewState();
}

class _AnimatedWorkflowPreviewState extends State<_AnimatedWorkflowPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: 0.94 + animation.value * 0.08,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(
                      alpha: 0.10 + animation.value * 0.08,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    widget.step.icon,
                    color: scheme.primary,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              for (var index = 0;
                  index < widget.step.previewRows.length;
                  index++)
                _AnimatedPreviewRow(
                  label: widget.step.previewRows[index],
                  index: index,
                  progress: animation.value,
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: 0.18 + animation.value * 0.76,
                  minHeight: 7,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedPreviewRow extends StatelessWidget {
  final String label;
  final int index;
  final double progress;

  const _AnimatedPreviewRow({
    required this.label,
    required this.index,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shifted = ((progress + index * 0.20) % 1.0);
    final emphasis = 0.55 + (1 - (shifted - 0.5).abs() * 2) * 0.45;
    return Transform.translate(
      offset: Offset((1 - emphasis) * 8, 0),
      child: Opacity(
        opacity: emphasis,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveRuleCard extends StatelessWidget {
  const _ArchiveRuleCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.folder_special_outlined,
            color: scheme.onTertiaryContainer,
            size: 30,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Правило общего кадрового архива',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'В общий Word/PDF входят только паспорт, регистрация, СНИЛС, ИНН, полис и фото. Соглашения, билеты, удостоверения и остальные документы хранятся отдельно и не смешиваются с основным комплектом.',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    height: 1.45,
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

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ToolActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
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
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolLogo extends StatelessWidget {
  final double size;

  const _ToolLogo({this.size = 58});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.badge_outlined,
        color: scheme.onPrimaryContainer,
        size: size * 0.52,
      ),
    );
  }
}

class _Capability {
  final IconData icon;
  final String title;
  final String text;

  const _Capability({
    required this.icon,
    required this.title,
    required this.text,
  });
}

class _RoleInfo {
  final IconData icon;
  final String title;
  final String text;

  const _RoleInfo({
    required this.icon,
    required this.title,
    required this.text,
  });
}

class _GuideStep {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String result;
  final List<String> previewRows;

  const _GuideStep({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.result,
    required this.previewRows,
  });
}

class _ToolsData {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation installation;

  const _ToolsData({required this.access, required this.installation});
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Не удалось загрузить инструменты',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

String _cleanError(Object? value) {
  return (value?.toString() ?? 'Неизвестная ошибка')
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}
