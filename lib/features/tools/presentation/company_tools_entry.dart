import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../documents/data/document_workflow_repository.dart';
import '../../documents/models/document_onboarding.dart';
import '../data/company_tools_controller.dart';
import 'company_tools_screen.dart';

class CompanyToolsSettingsEntry extends StatefulWidget {
  final AppUserProfile profile;

  const CompanyToolsSettingsEntry({super.key, required this.profile});

  @override
  State<CompanyToolsSettingsEntry> createState() =>
      _CompanyToolsSettingsEntryState();
}

class _CompanyToolsSettingsEntryState extends State<CompanyToolsSettingsEntry> {
  late Future<_CompanyToolsEntryData> future;

  @override
  void initState() {
    super.initState();
    CompanyToolsController.revision.addListener(_handleChanged);
    future = _load();
  }

  @override
  void dispose() {
    CompanyToolsController.revision.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CompanyToolsSettingsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.role != widget.profile.role) {
      future = _load();
    }
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() => future = _load());
  }

  Future<_CompanyToolsEntryData> _load() async {
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.hasEntry) return _CompanyToolsEntryData.hidden(access);
    final installation = await DocumentWorkflowRepository.fetchInstallation(
      widget.profile.activeCompanyId,
    );
    return _CompanyToolsEntryData(
      access: access,
      installation: installation,
    );
  }

  void _openTools() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => CompanyToolsScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CompanyToolsEntryData>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final visible = data.access.canManage ||
            (data.access.canView && data.installation?.isEnabled == true);
        if (!visible) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ToolsSectionTitle(title: 'Инструменты'),
            _ToolEntryCard(
              icon: Icons.extension_rounded,
              title: 'Инструменты AppСтрой',
              subtitle: data.installation?.isEnabled == true
                  ? '1 подключённый инструмент'
                  : 'Каталог подключаемых модулей',
              onTap: _openTools,
            ),
          ],
        );
      },
    );
  }
}

class ConnectedCompanyToolsSection extends StatefulWidget {
  final AppUserProfile profile;

  const ConnectedCompanyToolsSection({super.key, required this.profile});

  @override
  State<ConnectedCompanyToolsSection> createState() =>
      _ConnectedCompanyToolsSectionState();
}

class _ConnectedCompanyToolsSectionState
    extends State<ConnectedCompanyToolsSection> {
  late Future<_CompanyToolsEntryData> future;

  @override
  void initState() {
    super.initState();
    CompanyToolsController.revision.addListener(_handleChanged);
    future = _load();
  }

  @override
  void dispose() {
    CompanyToolsController.revision.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConnectedCompanyToolsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.role != widget.profile.role) {
      future = _load();
    }
  }

  void _handleChanged() {
    if (!mounted) return;
    setState(() => future = _load());
  }

  Future<_CompanyToolsEntryData> _load() async {
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.canView) return _CompanyToolsEntryData.hidden(access);
    final installation = await DocumentWorkflowRepository.fetchInstallation(
      widget.profile.activeCompanyId,
    );
    return _CompanyToolsEntryData(
      access: access,
      installation: installation,
    );
  }

  void _openTool() {
    final accessFuture = DocumentWorkflowRepository.fetchAccess();
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => FutureBuilder<DocumentWorkflowAccess>(
          future: accessFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('AppСтрой Трудоустройство')),
                body: Center(
                  child: Text(
                    snapshot.error?.toString() ?? 'Не удалось открыть инструмент',
                  ),
                ),
              );
            }
            return DocumentToolWorkspaceScreen(
              profile: widget.profile,
              access: snapshot.requireData,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CompanyToolsEntryData>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null ||
            !data.access.canView ||
            data.installation?.isEnabled != true) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const _ToolsSectionTitle(title: 'Рабочие инструменты'),
            _ToolEntryCard(
              icon: Icons.badge_outlined,
              title: 'AppСтрой Трудоустройство',
              subtitle: 'Оформление, документы и кадровый архив',
              onTap: _openTool,
            ),
          ],
        );
      },
    );
  }
}

class _ToolEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolEntryCard({
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
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

class _ToolsSectionTitle extends StatelessWidget {
  final String title;

  const _ToolsSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CompanyToolsEntryData {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation? installation;

  const _CompanyToolsEntryData({
    required this.access,
    required this.installation,
  });

  const _CompanyToolsEntryData.hidden(this.access) : installation = null;
}
