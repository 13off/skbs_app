import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../documents/data/document_workflow_repository.dart';
import '../../documents/models/document_onboarding.dart';
import '../../documents/presentation/document_workflow_screen.dart';
import 'app_tools_screen.dart';

class AppToolsSettingsEntry extends StatefulWidget {
  final AppUserProfile profile;

  const AppToolsSettingsEntry({super.key, required this.profile});

  @override
  State<AppToolsSettingsEntry> createState() => _AppToolsSettingsEntryState();
}

class _AppToolsSettingsEntryState extends State<AppToolsSettingsEntry> {
  late Future<_ToolsEntryState> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant AppToolsSettingsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.role != widget.profile.role) {
      future = _load();
    }
  }

  Future<_ToolsEntryState> _load() async {
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.hasEntry) {
      return _ToolsEntryState.hidden(access);
    }
    final installation = await DocumentWorkflowRepository.fetchInstallation(
      widget.profile.activeCompanyId,
    );
    return _ToolsEntryState(
      access: access,
      installation: installation,
    );
  }

  void _openTools() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => AppToolsScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ToolsEntryState>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final visible = data.access.canManage ||
            (data.installation?.isEnabled == true && data.access.canView);
        if (!visible) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ToolsSectionTitle(title: 'Инструменты'),
            _ToolNavigationCard(
              icon: Icons.widgets_outlined,
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

class ConnectedAppToolsSection extends StatefulWidget {
  final AppUserProfile profile;

  const ConnectedAppToolsSection({super.key, required this.profile});

  @override
  State<ConnectedAppToolsSection> createState() =>
      _ConnectedAppToolsSectionState();
}

class _ConnectedAppToolsSectionState extends State<ConnectedAppToolsSection> {
  late Future<_ToolsEntryState> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant ConnectedAppToolsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.role != widget.profile.role) {
      future = _load();
    }
  }

  Future<_ToolsEntryState> _load() async {
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.canView) return _ToolsEntryState.hidden(access);
    final installation = await DocumentWorkflowRepository.fetchInstallation(
      widget.profile.activeCompanyId,
    );
    return _ToolsEntryState(
      access: access,
      installation: installation,
    );
  }

  void _openEmployment() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => DocumentWorkflowScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ToolsEntryState>(
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
            _ToolNavigationCard(
              icon: Icons.badge_outlined,
              title: 'AppСтрой Трудоустройство',
              subtitle: 'Оформление, документы и кадровый архив',
              onTap: _openEmployment,
            ),
          ],
        );
      },
    );
  }
}

class _ToolNavigationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolNavigationCard({
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
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
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

class _ToolsEntryState {
  final DocumentWorkflowAccess access;
  final DocumentToolInstallation? installation;

  const _ToolsEntryState({required this.access, required this.installation});

  const _ToolsEntryState.hidden(this.access) : installation = null;
}
