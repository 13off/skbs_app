import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import 'document_generation_screen.dart';
import 'document_workflow_screen.dart';

class DocumentWorkflowSettingsEntry extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentWorkflowSettingsEntry({super.key, required this.profile});

  @override
  State<DocumentWorkflowSettingsEntry> createState() =>
      _DocumentWorkflowSettingsEntryState();
}

class _DocumentWorkflowSettingsEntryState
    extends State<DocumentWorkflowSettingsEntry> {
  late Future<DocumentWorkflowAccess> accessFuture;

  @override
  void initState() {
    super.initState();
    accessFuture = DocumentWorkflowRepository.fetchAccess();
  }

  @override
  void didUpdateWidget(covariant DocumentWorkflowSettingsEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.roleTitle != widget.profile.roleTitle) {
      accessFuture = DocumentWorkflowRepository.fetchAccess();
    }
  }

  void openWorkflow() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => DocumentWorkflowScreen(profile: widget.profile),
      ),
    );
  }

  void openGenerator() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => DocumentGenerationScreen(profile: widget.profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentWorkflowAccess>(
      future: accessFuture,
      builder: (context, snapshot) {
        final access = snapshot.data;
        if (access == null || !access.hasEntry) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            _SettingsCard(
              icon: Icons.folder_special_outlined,
              title: 'Документооборот',
              subtitle: 'Оформление, шаблоны и кадровый архив',
              onTap: openWorkflow,
            ),
            if (access.canView && access.canEdit)
              _SettingsCard(
                icon: Icons.auto_awesome_outlined,
                title: 'Генератор документов',
                subtitle: 'Сформировать DOCX по утверждённому шаблону',
                onTap: openGenerator,
              ),
          ],
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
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
                child: Icon(
                  icon,
                  color: scheme.onSurfaceVariant,
                  size: 21,
                ),
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
                    Text(subtitle),
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
