import 'package:flutter/material.dart';

import '../../../features/documents/data/document_template_repository.dart';
import '../../../features/documents/models/document_template.dart';
import '../../../models/app_user_profile.dart';
import '../models/ai_assistant_result.dart';
import 'ai_document_draft_screen.dart';

class AiDocumentTemplateScreen extends StatefulWidget {
  final AppUserProfile profile;
  final AiAssistantAction action;

  const AiDocumentTemplateScreen({
    super.key,
    required this.profile,
    required this.action,
  });

  @override
  State<AiDocumentTemplateScreen> createState() =>
      _AiDocumentTemplateScreenState();
}

class _AiDocumentTemplateScreenState extends State<AiDocumentTemplateScreen> {
  DocumentTemplateVersion? sourceVersion;
  bool loadingSource = true;

  @override
  void initState() {
    super.initState();
    loadSource();
  }

  String? get templateCode {
    return switch (widget.action.text('document_kind')) {
      'job_application' => 'employment_application',
      'salary_transfer_application' => 'salary_transfer_application',
      'personal_data_consent' => 'personal_data_consent',
      'employment_contract' => 'employment_contract',
      _ => null,
    };
  }

  Future<void> loadSource() async {
    final code = templateCode;
    if (code == null) {
      setState(() => loadingSource = false);
      return;
    }
    try {
      final templates = await DocumentTemplateRepository.fetchTemplates(
        companyId: widget.profile.activeCompanyId,
      );
      DocumentTemplateVersion? version;
      for (final template in templates) {
        if (template.code == code && template.isActive) {
          version = template.currentVersion;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        sourceVersion = version;
        loadingSource = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingSource = false);
    }
  }

  Future<void> openSource() async {
    final version = sourceVersion;
    if (version == null) return;
    try {
      await DocumentTemplateRepository.downloadVersion(version);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть исходник: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AiDocumentDraftScreen(profile: widget.profile, action: widget.action),
        if (loadingSource || sourceVersion != null)
          Positioned(
            right: 14,
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 3,
              borderRadius: BorderRadius.circular(999),
              child: loadingSource
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: openSource,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Исходная форма'),
                    ),
            ),
          ),
      ],
    );
  }
}
