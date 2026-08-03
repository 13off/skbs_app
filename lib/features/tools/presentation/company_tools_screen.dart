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
  _CompanyToolsTab selectedTab = _CompanyToolsTab.connected;
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
    final access = values[0] as DocumentWorkflowAccess;
    final installation = values[1] as DocumentToolInstallation;
    if (!installation.isEnabled && access.canManage) {
      selectedTab = _CompanyToolsTab.catalog;
    }
    return _ToolsData(access: access, installation: installation);
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
      selectedTab = enabled
          ? _CompanyToolsTab.connected
          : _CompanyToolsTab.catalog;
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
      showDragHandle: true,
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

  Widget _connectedView(_ToolsData data) {
    if (!data.installation.isEnabled) {
      return PremiumWorkCard(
        radius: 24,
        child: Row(
          children: [
            const Icon(Icons.extension_off_outlined),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Подключённых инструментов нет',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (data.access.canManage)
              TextButton(
                onPressed: () {
                  setState(() => selectedTab = _CompanyToolsTab.catalog);
                },
                child: const Text('Каталог'),
              ),
          ],
        ),
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
  }

  Widget _catalogView(_ToolsData data) {
    return _EmploymentToolCard(
      access: data.access,
      installation: data.installation,
      changing: changing,
      onOpen: () => _openWorkspace(data),
      onInfo: () => _showInfo(data),
      onEnable: () => _setEnabled(data, true),
      onDisable: () => _setEnabled(data, false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Инструменты AppСтрой',
      subtitle: 'Подключение и управление',
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.access.canManage)
                SegmentedButton<_CompanyToolsTab>(
                  segments: const [
                    ButtonSegment<_CompanyToolsTab>(
                      value: _CompanyToolsTab.connected,
                      icon: Icon(Icons.widgets_outlined),
                      label: Text('Подключённые'),
                    ),
                    ButtonSegment<_CompanyToolsTab>(
                      value: _CompanyToolsTab.catalog,
                      icon: Icon(Icons.storefront_outlined),
                      label: Text('Каталог'),
                    ),
                  ],
                  selected: <_CompanyToolsTab>{selectedTab},
                  onSelectionChanged: (selection) {
                    setState(() => selectedTab = selection.first);
                  },
                ),
              if (data.access.canManage) const SizedBox(height: 16),
              if (!data.access.canManage ||
                  selectedTab == _CompanyToolsTab.connected)
                _connectedView(data)
              else
                _catalogView(data),
            ],
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
            tooltip: 'Об инструменте',
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

class _ToolInfoSheet extends StatefulWidget {
  final bool enabled;
  final bool canManage;

  const _ToolInfoSheet({required this.enabled, required this.canManage});

  @override
  State<_ToolInfoSheet> createState() => _ToolInfoSheetState();
}

class _ToolInfoSheetState extends State<_ToolInfoSheet> {
  final PageController controller = PageController();
  int page = 0;

  static const steps = <_InfoStep>[
    _InfoStep(
      icon: Icons.extension_rounded,
      title: 'Подключите',
      text: 'Владелец или администратор включает инструмент для всей компании.',
    ),
    _InfoStep(
      icon: Icons.apps_rounded,
      title: 'Откройте в профиле',
      text: 'После подключения инструмент появляется в профиле как отдельное приложение.',
    ),
    _InfoStep(
      icon: Icons.fact_check_outlined,
      title: 'Оформляйте сотрудников',
      text: 'HR и юрист работают с документами, шаблонами, подписями и архивом по своим правам.',
    ),
    _InfoStep(
      icon: Icons.lock_outline_rounded,
      title: 'Отключайте безопасно',
      text: 'Отключение закрывает функции, но не удаляет документы, версии и историю.',
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _ToolLogo(size: 54),
                const SizedBox(width: 13),
                const Expanded(
                  child: Text(
                    'AppСтрой Трудоустройство',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Распознавание документов, оформление по ГПХ или трудовому договору, генерация DOCX, подписание и защищённый архив.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              child: PageView.builder(
                controller: controller,
                itemCount: steps.length,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(step.icon, size: 44),
                          const SizedBox(height: 13),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            step.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < steps.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: page == index ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: page == index
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  widget.enabled
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: widget.enabled ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.enabled ? 'Сейчас включён' : 'Сейчас отключён',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (!widget.canManage)
                  const Text(
                    'Управляет администратор',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
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

class _InfoStep {
  final IconData icon;
  final String title;
  final String text;

  const _InfoStep({
    required this.icon,
    required this.title,
    required this.text,
  });
}

enum _CompanyToolsTab { connected, catalog }

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
