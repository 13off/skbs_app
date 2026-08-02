import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../documents/data/document_workflow_repository.dart';
import '../../documents/models/document_onboarding.dart';
import '../../documents/presentation/document_workflow_screen.dart';

class AppToolsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const AppToolsScreen({super.key, required this.profile});

  @override
  State<AppToolsScreen> createState() => _AppToolsScreenState();
}

class _AppToolsScreenState extends State<AppToolsScreen> {
  late Future<_ToolsWorkspace> future;
  _ToolsTab selectedTab = _ToolsTab.connected;
  bool changingInstallation = false;

  String get companyId => widget.profile.activeCompanyId.trim();

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_ToolsWorkspace> load() async {
    if (companyId.isEmpty) throw StateError('Компания не выбрана');
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.hasEntry) {
      throw StateError('Для вашей роли нет доступных инструментов');
    }
    final installation = await DocumentWorkflowRepository.fetchInstallation(
      companyId,
    );
    if (!installation.isEnabled && access.canManage) {
      selectedTab = _ToolsTab.catalog;
    }
    return _ToolsWorkspace(access: access, installation: installation);
  }

  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  Future<void> setEmploymentEnabled(
    _ToolsWorkspace workspace,
    bool enabled,
  ) async {
    if (changingInstallation || !workspace.access.canManage) return;
    setState(() => changingInstallation = true);
    try {
      await DocumentWorkflowRepository.setInstallation(
        companyId: companyId,
        isEnabled: enabled,
        settings: workspace.installation.settings,
      );
      selectedTab = enabled ? _ToolsTab.connected : _ToolsTab.catalog;
      await refresh();
      _message(
        enabled
            ? 'Инструмент «AppСтрой Трудоустройство» подключён'
            : 'Инструмент отключён. Данные и архив сохранены',
      );
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => changingInstallation = false);
    }
  }

  void openEmploymentTool() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => DocumentWorkflowScreen(profile: widget.profile),
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Инструменты AppСтрой',
      subtitle: 'Подключаемые рабочие модули компании',
      onRefresh: refresh,
      child: FutureBuilder<_ToolsWorkspace>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _ToolsError(
              message: _cleanError(snapshot.error),
              onRetry: refresh,
            );
          }

          final workspace = snapshot.requireData;
          final canOpen =
              workspace.installation.isEnabled && workspace.access.canView;
          final showCatalog = workspace.access.canManage;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumWorkCard(
                radius: 24,
                child: Text(
                  'Инструменты устанавливаются отдельно и не меняют основную '
                  'логику AppСтрой. Подключение действует для всей компании, '
                  'а доступ сотрудников определяется их ролью и разрешениями.',
                  style: TextStyle(height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              if (showCatalog)
                SegmentedButton<_ToolsTab>(
                  segments: const [
                    ButtonSegment<_ToolsTab>(
                      value: _ToolsTab.connected,
                      icon: Icon(Icons.widgets_outlined),
                      label: Text('Подключённые'),
                    ),
                    ButtonSegment<_ToolsTab>(
                      value: _ToolsTab.catalog,
                      icon: Icon(Icons.storefront_outlined),
                      label: Text('Каталог'),
                    ),
                  ],
                  selected: <_ToolsTab>{selectedTab},
                  onSelectionChanged: (selection) {
                    setState(() => selectedTab = selection.first);
                  },
                ),
              if (showCatalog) const SizedBox(height: 16),
              if (!showCatalog || selectedTab == _ToolsTab.connected)
                _connectedView(workspace, canOpen)
              else
                _catalogView(workspace),
            ],
          );
        },
      ),
    );
  }

  Widget _connectedView(_ToolsWorkspace workspace, bool canOpen) {
    if (!workspace.installation.isEnabled) {
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
            const Text(
              'Откройте каталог и подключите нужный рабочий модуль компании.',
            ),
            if (workspace.access.canManage) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () =>
                    setState(() => selectedTab = _ToolsTab.catalog),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Открыть каталог'),
              ),
            ],
          ],
        ),
      );
    }

    return _EmploymentToolCard(
      connected: true,
      canOpen: canOpen,
      canManage: false,
      busy: changingInstallation,
      onOpen: canOpen ? openEmploymentTool : null,
      onToggle: null,
    );
  }

  Widget _catalogView(_ToolsWorkspace workspace) {
    return _EmploymentToolCard(
      connected: workspace.installation.isEnabled,
      canOpen: workspace.installation.isEnabled && workspace.access.canView,
      canManage: workspace.access.canManage,
      busy: changingInstallation,
      onOpen: workspace.installation.isEnabled && workspace.access.canView
          ? openEmploymentTool
          : null,
      onToggle: workspace.access.canManage
          ? (enabled) => setEmploymentEnabled(workspace, enabled)
          : null,
    );
  }
}

class _EmploymentToolCard extends StatelessWidget {
  final bool connected;
  final bool canOpen;
  final bool canManage;
  final bool busy;
  final VoidCallback? onOpen;
  final ValueChanged<bool>? onToggle;

  const _EmploymentToolCard({
    required this.connected,
    required this.canOpen,
    required this.canManage,
    required this.busy,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AppСтрой Трудоустройство',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      connected ? 'Подключён компании' : 'Доступен в каталоге',
                      style: TextStyle(
                        color: connected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Распознавание документов кандидата, создание карточки сотрудника, '
            'оформление по ГПХ или трудовому договору, генерация DOCX, '
            'подписание и защищённый кадровый архив.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('HR')),
              Chip(label: Text('Юрист')),
              Chip(label: Text('Документы')),
              Chip(label: Text('Архив')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (connected && canOpen)
                FilledButton.icon(
                  onPressed: busy ? null : onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Открыть инструмент'),
                )
              else if (connected)
                Expanded(
                  child: Text(
                    'Инструмент подключён, но вашей роли не выдано право '
                    'использования.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (canManage) ...[
                if (connected && canOpen) const Spacer(),
                if (!connected)
                  FilledButton.icon(
                    onPressed: busy ? null : () => onToggle?.call(true),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Подключить'),
                  )
                else
                  TextButton(
                    onPressed: busy ? null : () => onToggle?.call(false),
                    child: const Text('Отключить'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ToolsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _ToolsWorkspace {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation installation;

  const _ToolsWorkspace({required this.access, required this.installation});
}

enum _ToolsTab { connected, catalog }

String _cleanError(Object? value) {
  return (value?.toString() ?? 'Неизвестная ошибка')
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}
