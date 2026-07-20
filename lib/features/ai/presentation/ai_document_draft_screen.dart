import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/employee_private_data_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../features/company/data/company_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../models/employee_private_data.dart';
import '../../../widgets/premium_ui.dart';
import '../documents/ai_document_download_service.dart';
import '../documents/ai_document_draft.dart';
import '../models/ai_assistant_result.dart';

class AiDocumentDraftScreen extends StatefulWidget {
  final AppUserProfile profile;
  final AiAssistantAction action;

  const AiDocumentDraftScreen({
    super.key,
    required this.profile,
    required this.action,
  });

  @override
  State<AiDocumentDraftScreen> createState() =>
      _AiDocumentDraftScreenState();
}

class _AiDocumentDraftScreenState extends State<AiDocumentDraftScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  bool loading = true;
  bool downloaded = false;
  String fileBaseName = 'document';
  String? errorText;
  List<String> missingFields = const <String>[];

  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> loadDraft() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      String companyName = '';
      try {
        final company = await CompanyRepository.fetchCompany(
          widget.profile.activeCompanyId,
        );
        companyName = company.name;
      } catch (_) {
        // Название можно дописать вручную в предпросмотре.
      }

      Employee? employee;
      final employeeId = widget.action.text('employee_id');
      final employeeName = widget.action.text('employee_name');
      final objectName = widget.action.text('object_name');
      final employees = await EmployeeRepository.fetchEmployees(
        objectName: objectName.isEmpty ? null : objectName,
        includeFired: true,
      );
      if (employeeId.isNotEmpty) {
        for (final item in employees) {
          if (item.id == employeeId) {
            employee = item;
            break;
          }
        }
      }
      if (employee == null && employeeName.isNotEmpty) {
        final normalizedName = employeeName.trim().toLowerCase();
        final matches = employees.where((item) {
          return item.name.trim().toLowerCase() == normalizedName;
        }).toList(growable: false);
        if (matches.length == 1) employee = matches.single;
      }

      EmployeePrivateData? privateData;
      final resolvedEmployeeId = employee?.id?.trim() ?? '';
      if ((widget.profile.isAdmin || widget.profile.isHr) &&
          resolvedEmployeeId.isNotEmpty) {
        try {
          privateData = await EmployeePrivateDataRepository.fetchByEmployeeId(
            resolvedEmployeeId,
          );
        } catch (_) {
          // RLS остаётся источником истины; недоступные поля будут плейсхолдерами.
        }
      }

      final draft = AiDocumentDraftBuilder.build(
        action: widget.action,
        companyName: companyName,
        employee: employee,
        privateData: privateData,
      );
      if (!mounted) return;
      setState(() {
        titleController.text = draft.title;
        bodyController.text = draft.body;
        fileBaseName = draft.fileBaseName;
        missingFields = draft.missingFields;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Не удалось подготовить документ: $error';
      });
    }
  }

  Future<void> copyText() async {
    await Clipboard.setData(ClipboardData(text: bodyController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Текст скопирован')));
  }

  void downloadWord() {
    final body = bodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ пустой')),
      );
      return;
    }

    AiDocumentDownloadService.downloadWordCompatible(
      title: titleController.text.trim(),
      body: body,
      fileBaseName: fileBaseName,
    );
    setState(() => downloaded = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Word-файл скачан')),
    );
  }

  Widget buildMissingFields() {
    if (missingFields.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7C68E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Нужно заполнить вручную',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          for (final field in missingFields) Text('• $field'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Черновик документа')),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : errorText != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              errorText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: loadDraft,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                      children: [
                        const Text(
                          'Проверь документ перед скачиванием',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ИИ определил тип и контекст. Подписи, отправка и сохранение в карточку сотрудника не выполняются автоматически.',
                          style: TextStyle(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        buildMissingFields(),
                        if (missingFields.isNotEmpty) const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Название документа',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: bodyController,
                          minLines: 18,
                          maxLines: null,
                          decoration: InputDecoration(
                            labelText: 'Текст документа',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: copyText,
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('Копировать текст'),
                            ),
                            FilledButton.icon(
                              onPressed: downloadWord,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Скачать Word'),
                            ),
                            if (downloaded)
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context, true),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Готово'),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
