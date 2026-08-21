import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../documents/data/document_workflow_repository.dart';
import '../../documents/models/document_onboarding.dart';
import '../../documents/presentation/document_generation_screen.dart';
import '../../documents/presentation/document_package_management_screen.dart';
import '../../documents/presentation/document_tool_templates_screen.dart';
import '../../documents/presentation/document_workflow_screen.dart';
import 'document_tool_feature_gate.dart';
import '../../../navigation/app_page_route.dart';

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
            'Оформления, шаблоны и документы сохранятся. '
            'Общий архив AppСтрой также не изменится. Рабочие функции '
            'снова появятся после включения.',
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
      AppPageRoute<void>(
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
    Navigator.of(
      context,
    ).push<void>(AppPageRoute<void>(builder: (_) => screen));
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
              icon: Icons.edit_document,
              title: 'Шаблоны',
              onTap: () =>
                  _open(context, DocumentToolTemplatesScreen(profile: profile)),
            ),
          const SizedBox(height: 8),
          PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(16),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.archive_outlined, size: 22),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'После завершения оформления финальные документы '
                    'автоматически доступны в общем архиве AppСтрой. '
                    'Отдельный второй архив внутри инструмента не создаётся.',
                    style: TextStyle(height: 1.4),
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

class DocumentToolAppShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const DocumentToolAppShortcut({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(26);
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: radius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 174),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _EmploymentToolIcon(size: 72),
                    SizedBox(height: 13),
                    Text(
                      'AppСтрой\nТрудоустройство',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          const _EmploymentToolIcon(size: 54),
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
                        ? (value) => value ? onEnable() : onDisable()
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

  const _ToolInfoSheet({required this.enabled, required this.canManage});

  static const capabilities = <_Capability>[
    _Capability(
      Icons.document_scanner_outlined,
      'Исходные документы',
      'Собирает документы кандидата в одном процессе без повторного копирования.',
    ),
    _Capability(
      Icons.fact_check_outlined,
      'Проверка данных',
      'HR вручную проверяет распознанные поля до генерации кадровых форм.',
    ),
    _Capability(
      Icons.edit_document,
      'Онлайн-редактор',
      'Юрист меняет текст DOCX внутри AppСтрой. Системные поля защищены замком.',
    ),
    _Capability(
      Icons.auto_awesome_outlined,
      'Генерация DOCX',
      'Заполняет утверждённую версию шаблона проверенными данными сотрудника.',
    ),
    _Capability(
      Icons.draw_outlined,
      'Подписание',
      'Разделяет исходник, созданный документ, подписанную версию и финальный скан.',
    ),
    _Capability(
      Icons.archive_outlined,
      'Общий архив',
      'Передаёт итоговые документы в существующий архив AppСтрой, не создавая дубль.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: .96,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
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
                  padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
                  child: Row(
                    children: [
                      const _EmploymentToolIcon(size: 56),
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
                        const SizedBox(height: 26),
                        const Text(
                          'Что умеет инструмент',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 720 ? 3 : 1;
                            final width = columns == 1
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 3;
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
                        const SizedBox(height: 28),
                        const Text(
                          'Как работать',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Пошаговый путь от подключения до завершённого оформления.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        const _WorkflowGuide(),
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

  const _ToolHero({required this.enabled, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Полное кадровое оформление в одном процессе',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Инструмент связывает кандидата, документы, проверку данных, '
            'карточку сотрудника, условия, шаблоны, генерацию, подпись и '
            'финальные сканы. Результат хранится в общем архиве AppСтрой.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(
                enabled
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_outline,
                color: enabled ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  enabled ? 'Инструмент подключён' : 'Инструмент отключён',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (!canManage)
                const Text(
                  'Управляет администратор',
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
        ],
      ),
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
      constraints: const BoxConstraints(minHeight: 158),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: scheme.primary, size: 28),
          const SizedBox(height: 11),
          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
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
      Icons.toggle_on_outlined,
      '1 из 8',
      'Подключите инструмент',
      'Администратор включает тумблер для компании.',
      'Модуль появляется у разрешённых ролей.',
    ),
    _GuideStep(
      Icons.person_add_alt_1_outlined,
      '2 из 8',
      'Создайте оформление',
      'Выберите кандидата CRM или существующего сотрудника.',
      'Файлы и данные связываются с одним процессом.',
    ),
    _GuideStep(
      Icons.upload_file_outlined,
      '3 из 8',
      'Загрузите исходники',
      'Добавьте паспорт, регистрацию, СНИЛС, ИНН, полис и фото.',
      'Исходные документы остаются отдельными файлами.',
    ),
    _GuideStep(
      Icons.fact_check_outlined,
      '4 из 8',
      'Проверьте данные',
      'HR сверяет распознанные значения с оригиналами.',
      'В шаблоны попадут только подтверждённые сведения.',
    ),
    _GuideStep(
      Icons.edit_document,
      '5 из 8',
      'Настройте шаблоны',
      'Юрист редактирует DOCX онлайн и утверждает новую версию.',
      'Системные поля и исходник защищены.',
    ),
    _GuideStep(
      Icons.auto_awesome_outlined,
      '6 из 8',
      'Сгенерируйте документы',
      'Выберите пакет и заполните формы проверенными данными.',
      'Созданный DOCX связан с версией шаблона.',
    ),
    _GuideStep(
      Icons.draw_outlined,
      '7 из 8',
      'Подпишите и загрузите сканы',
      'Зафиксируйте печать, подпись и проверку финальных сканов.',
      'Каждый тип файла хранится отдельно.',
    ),
    _GuideStep(
      Icons.verified_outlined,
      '8 из 8',
      'Завершите оформление',
      'Устраните блокирующие причины и закройте процесс.',
      'Документы доступны в общем архиве AppСтрой.',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 360,
            child: PageView.builder(
              controller: controller,
              itemCount: steps.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) => _GuideCard(step: steps[index]),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < steps.length; index++)
                GestureDetector(
                  onTap: () => controller.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: page == index ? 25 : 8,
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
        ],
      ),
    );
  }
}

class _GuideCard extends StatefulWidget {
  final _GuideStep step;

  const _GuideCard({required this.step});

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: .94 + animation.value * .08,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Icon(
                    widget.step.icon,
                    size: 36,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                widget.step.number,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.step.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                widget.step.action,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: scheme.primary,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.step.result,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
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

class _EmploymentToolIcon extends StatelessWidget {
  final double size;

  const _EmploymentToolIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * .27),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.description_rounded,
            color: scheme.onPrimaryContainer,
            size: size * .48,
          ),
          Positioned(
            right: size * .10,
            bottom: size * .10,
            child: Container(
              width: size * .30,
              height: size * .30,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primaryContainer, width: 2),
              ),
              child: Icon(
                Icons.person_add_alt_1_rounded,
                color: scheme.onPrimary,
                size: size * .17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Capability {
  final IconData icon;
  final String title;
  final String text;

  const _Capability(this.icon, this.title, this.text);
}

class _GuideStep {
  final IconData icon;
  final String number;
  final String title;
  final String action;
  final String result;

  const _GuideStep(
    this.icon,
    this.number,
    this.title,
    this.action,
    this.result,
  );
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
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
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
