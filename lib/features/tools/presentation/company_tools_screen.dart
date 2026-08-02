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
            'Оформления, шаблоны, документы и архивы не удалятся. '
            'Инструмент просто перестанет быть доступен пользователям '
            'до повторного подключения.',
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
      selectedTab = enabled
          ? _CompanyToolsTab.connected
          : _CompanyToolsTab.catalog;
      await _refresh();
      _message(
        enabled
            ? '«AppСтрой Трудоустройство» подключён'
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

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _connectedView(_ToolsData data) {
    if (!data.installation.isEnabled) {
      return PremiumWorkCard(
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Подключённых инструментов пока нет',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              data.access.canManage
                  ? 'Откройте каталог и подключите нужный модуль компании.'
                  : 'Инструменты подключаются владельцем или администратором компании.',
              style: const TextStyle(height: 1.4),
            ),
            if (data.access.canManage) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  setState(() => selectedTab = _CompanyToolsTab.catalog);
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Открыть каталог'),
              ),
            ],
          ],
        ),
      );
    }

    return _EmploymentToolCard(
      access: data.access,
      installation: data.installation,
      changing: changing,
      showManagement: false,
      onOpen: () => _openWorkspace(data),
      onEnable: () => _setEnabled(data, true),
      onDisable: () => _setEnabled(data, false),
    );
  }

  Widget _catalogView(_ToolsData data) {
    return _EmploymentToolCard(
      access: data.access,
      installation: data.installation,
      changing: changing,
      showManagement: true,
      onOpen: () => _openWorkspace(data),
      onEnable: () => _setEnabled(data, true),
      onDisable: () => _setEnabled(data, false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Инструменты AppСтрой',
      subtitle: 'Подключаемые рабочие модули компании',
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
              child: Text(
                'Для вашей роли пока нет доступных инструментов компании.',
                style: TextStyle(height: 1.45),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumWorkCard(
                radius: 24,
                child: Text(
                  'Инструменты устанавливаются отдельно и не меняют основную '
                  'логику AppСтрой. Подключение действует для всей компании, '
                  'а доступ к разделам определяется ролью пользователя.',
                  style: TextStyle(height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 14),
              PremiumWorkCard(
                radius: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.access.canManage
                            ? 'Владелец или администратор подключает инструмент '
                                  'один раз для компании. После подключения HR, '
                                  'юрист и другие роли используют только те '
                                  'разделы, на которые им выданы права.'
                            : 'Здесь отображаются подключённые компанией '
                                  'инструменты и только разрешённые вашей роли '
                                  'рабочие разделы.',
                        style: const TextStyle(height: 1.45),
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
      subtitle: 'Оформление и кадровый документооборот',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumWorkCard(
            radius: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ToolLogo(),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Подключённый инструмент',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Единый процесс: документы кандидата, проверка HR, '
                        'карточка сотрудника, договоры, подписи и архив.',
                        style: TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Разделы инструмента',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (access.canView)
            _ToolActionCard(
              icon: Icons.fact_check_outlined,
              title: 'Оформления',
              subtitle: 'Кандидаты и сотрудники: 13 этапов до архива',
              onTap: () =>
                  _open(context, DocumentWorkflowScreen(profile: profile)),
            ),
          if (access.canEdit)
            _ToolActionCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Генератор документов',
              subtitle: 'DOCX по утверждённым версиям шаблонов',
              onTap: () =>
                  _open(context, DocumentGenerationScreen(profile: profile)),
            ),
          if (access.canManagePackages)
            _ToolActionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Пакеты документов',
              subtitle: 'Наборы для ГПХ, приёма и изменения условий',
              onTap: () => _open(
                context,
                DocumentPackageManagementScreen(profile: profile),
              ),
            ),
          if (access.canViewTemplates)
            _ToolActionCard(
              icon: Icons.description_outlined,
              title: 'Шаблоны',
              subtitle: 'Утверждённые версии и защищённые поля',
              onTap: () =>
                  _open(context, TemplateDocumentsScreen(profile: profile)),
            ),
          if (access.canViewAudit)
            _ToolActionCard(
              icon: Icons.archive_outlined,
              title: 'Архив',
              subtitle: 'Документы сотрудников, версии и история',
              onTap: () =>
                  _open(context, ArchiveManagementScreenV3(profile: profile)),
            ),
        ],
      ),
    );
  }
}

class _EmploymentToolCard extends StatelessWidget {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation installation;
  final bool changing;
  final bool showManagement;
  final VoidCallback onOpen;
  final VoidCallback onEnable;
  final VoidCallback onDisable;

  const _EmploymentToolCard({
    required this.access,
    required this.installation,
    required this.changing,
    required this.showManagement,
    required this.onOpen,
    required this.onEnable,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = installation.isEnabled;
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ToolLogo(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AppСтрой Трудоустройство',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Оформление и кадровый документооборот',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Chip(
                      avatar: Icon(
                        enabled
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(enabled ? 'Подключён' : 'Доступен'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Распознавание документов, карточка сотрудника, оформление по ГПХ '
            'или трудовому договору, генерация DOCX, подписание, финальные '
            'сканы и защищённый кадровый архив.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('HR')),
              Chip(label: Text('Юрист')),
              Chip(label: Text('Документы')),
              Chip(label: Text('Архив')),
            ],
          ),
          const SizedBox(height: 16),
          if (changing)
            const Center(child: CircularProgressIndicator())
          else if (enabled) ...[
            FilledButton.icon(
              onPressed: access.canView ? onOpen : null,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Открыть инструмент'),
            ),
            if (showManagement && access.canManage)
              TextButton(
                onPressed: onDisable,
                child: const Text('Отключить для компании'),
              ),
          ] else if (showManagement && access.canManage)
            FilledButton.icon(
              onPressed: onEnable,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Подключить инструмент'),
            )
          else
            const Text(
              'Ожидает подключения владельцем или администратором компании.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

class _ToolActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle),
                  ],
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
  const _ToolLogo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Icon(
        Icons.badge_outlined,
        color: scheme.onPrimaryContainer,
        size: 30,
      ),
    );
  }
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
