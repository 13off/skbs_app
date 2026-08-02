import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import 'document_workflow_screen.dart';

class DocumentWorkflowSettingsEntry extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentWorkflowSettingsEntry({
    super.key,
    required this.profile,
  });

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
        oldWidget.profile.roleCode != widget.profile.roleCode) {
      accessFuture = DocumentWorkflowRepository.fetchAccess();
    }
  }

  void open() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => DocumentWorkflowScreen(profile: widget.profile),
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
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: open,
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
                      Icons.folder_special_outlined,
                      color: scheme.onSurfaceVariant,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Документооборот',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text('Оформление, шаблоны и кадровый архив'),
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
      },
    );
  }
}
