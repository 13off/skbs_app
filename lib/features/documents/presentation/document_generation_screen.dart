import 'package:flutter/material.dart';

import '../../../features/company/data/company_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/template_documents_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_generation_service.dart';
import '../data/document_template_repository.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import '../models/document_template.dart';
import 'document_onboarding_screen.dart';
import '../../../navigation/app_page_route.dart';

class DocumentGenerationScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentGenerationScreen({super.key, required this.profile});

  @override
  State<DocumentGenerationScreen> createState() =>
      _DocumentGenerationScreenState();
}

class _DocumentGenerationScreenState extends State<DocumentGenerationScreen> {
  late Future<_GenerationWorkspace> future;
  final Set<String> generatingIds = <String>{};

  String get companyId => widget.profile.activeCompanyId;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_GenerationWorkspace> _load() async {
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.canView || !access.canEdit) {
      throw StateError('Нет права формировать кадровые документы');
    }

    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      DocumentWorkflowRepository.fetchOnboardings(companyId: companyId),
      DocumentTemplateRepository.fetchTemplates(companyId: companyId),
      DocumentWorkflowRepository.fetchPackageTemplateLinks(
        companyId: companyId,
      ),
      DocumentWorkflowRepository.fetchEmployees(companyId),
      CompanyRepository.fetchCompany(companyId),
    ]);

    return _GenerationWorkspace(
      access: access,
      onboardings: (values[0] as List<EmployeeOnboardingRecord>)
          .where(
            (item) =>
                !item.isCompleted &&
                item.status != 'cancelled' &&
                item.employeeId != null &&
                item.packageId != null,
          )
          .toList(growable: false),
      templates: values[1] as List<DocumentTemplateRecord>,
      packageLinks: values[2] as List<DocumentPackageTemplateLink>,
      employees: values[3] as List<DocumentEmployeeOption>,
      companyName: (values[4] as dynamic).name?.toString() ?? '',
    );
  }

  Future<void> _refresh() async {
    setState(() => future = _load());
    await future;
  }

  List<DocumentTemplateRecord> _templatesFor(
    _GenerationWorkspace data,
    EmployeeOnboardingRecord process,
  ) {
    final packageId = process.packageId;
    final allowedIds = data.packageLinks
        .where((link) => packageId == null || link.packageId == packageId)
        .map((link) => link.templateId)
        .toSet();

    return data.templates
        .where((template) {
          final version = template.currentVersion;
          if (!template.isActive || version == null || !version.isApproved) {
            return false;
          }
          if (!version.isAsset && !version.isStorage) return false;
          return allowedIds.isEmpty || allowedIds.contains(template.id);
        })
        .toList(growable: false);
  }

  Future<DocumentTemplateRecord?> _selectTemplate(
    _GenerationWorkspace data,
    EmployeeOnboardingRecord process,
  ) async {
    final templates = _templatesFor(data, process);
    if (templates.isEmpty) {
      final openTemplates = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Нет готового DOCX-шаблона'),
          content: const Text(
            'В пакет не добавлена утверждённая DOCX-версия из закрытого '
            'хранилища AppСтрой. Внешнюю ссылку система намеренно не копирует '
            'и не использует для автоматической генерации.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Открыть шаблоны'),
            ),
          ],
        ),
      );
      if (openTemplates == true && mounted) {
        await Navigator.of(context).push<void>(
          AppPageRoute<void>(
            builder: (_) => TemplateDocumentsScreen(profile: widget.profile),
          ),
        );
        await _refresh();
      }
      return null;
    }

    if (templates.length == 1) return templates.single;
    return showDialog<DocumentTemplateRecord>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Выберите утверждённый шаблон'),
        children: [
          for (final template in templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, template),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(template.title),
                subtitle: Text(
                  'Версия ${template.currentVersion!.versionNo} · '
                  '${template.currentVersion!.fileName}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate(
    _GenerationWorkspace data,
    EmployeeOnboardingRecord process,
  ) async {
    if (generatingIds.contains(process.id)) return;
    final template = await _selectTemplate(data, process);
    if (template == null || !mounted) return;

    setState(() => generatingIds.add(process.id));
    try {
      final employee = data.employee(process.employeeId);
      final now = DateTime.now();
      final shortId = process.id.length > 8
          ? process.id.substring(0, 8).toUpperCase()
          : process.id.toUpperCase();
      final result = await DocumentGenerationService.generateAndUpload(
        companyId: companyId,
        onboarding: process,
        template: template,
        fields: <String, dynamic>{
          ...process.recognizedData,
          ...process.conditions,
          'employee_full_name': process.personName,
          'phone': employee?.phone ?? '',
          'position': process.conditions['position']?.toString() ?? '',
          'object_name': process.objectName,
          'start_date': process.conditions['start_date']?.toString() ?? '',
          'compensation': process.conditions['compensation']?.toString() ?? '',
          'company_name': data.companyName,
          'manager_full_name': widget.profile.fullName,
          'document_date': _dateText(now),
          'document_number': shortId,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сформирован ${result.file.originalFileName}'),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed: () => _openOnboarding(process.id),
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => generatingIds.remove(process.id));
    }
  }

  void _openOnboarding(String onboardingId) {
    Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => DocumentOnboardingScreen(
          profile: widget.profile,
          onboardingId: onboardingId,
        ),
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
      title: 'Генератор документов',
      subtitle: 'Утверждённые DOCX-версии без изменения оригинала',
      onRefresh: _refresh,
      child: FutureBuilder<_GenerationWorkspace>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: _cleanError(snapshot.error),
              onRetry: _refresh,
            );
          }
          final data = snapshot.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PremiumWorkCard(
                radius: 24,
                child: Text(
                  'Генератор использует только утверждённую версию DOCX из '
                  'AppСтрой. Исходник не меняется: результат получает новую '
                  'версию, привязку к шаблону и запись в журнале.',
                  style: TextStyle(height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              if (data.onboardings.isEmpty)
                const PremiumWorkCard(
                  radius: 24,
                  child: Text(
                    'Нет оформлений, для которых уже выбраны сотрудник и '
                    'пакет документов.',
                  ),
                )
              else
                for (final process in data.onboardings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProcessGenerationCard(
                      process: process,
                      templates: _templatesFor(data, process),
                      busy: generatingIds.contains(process.id),
                      onGenerate: () => _generate(data, process),
                      onOpen: () => _openOnboarding(process.id),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _GenerationWorkspace {
  final DocumentWorkflowAccess access;
  final List<EmployeeOnboardingRecord> onboardings;
  final List<DocumentTemplateRecord> templates;
  final List<DocumentPackageTemplateLink> packageLinks;
  final List<DocumentEmployeeOption> employees;
  final String companyName;

  const _GenerationWorkspace({
    required this.access,
    required this.onboardings,
    required this.templates,
    required this.packageLinks,
    required this.employees,
    required this.companyName,
  });

  DocumentEmployeeOption? employee(String? id) {
    if (id == null) return null;
    for (final employee in employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }
}

class _ProcessGenerationCard extends StatelessWidget {
  final EmployeeOnboardingRecord process;
  final List<DocumentTemplateRecord> templates;
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onOpen;

  const _ProcessGenerationCard({
    required this.process,
    required this.templates,
    required this.busy,
    required this.onGenerate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            process.personName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            [
              if (process.packageTitle.isNotEmpty) process.packageTitle,
              if (process.objectName.isNotEmpty) process.objectName,
              'Этап: ${_stepTitle(process.currentStep)}',
            ].join(' · '),
          ),
          const SizedBox(height: 10),
          Text(
            templates.isEmpty
                ? 'Нет утверждённой локальной DOCX-версии'
                : 'Доступно шаблонов: ${templates.length}',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onGenerate,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: const Text('Сформировать DOCX'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Открыть оформление'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

String _stepTitle(String value) => switch (value) {
  'source_files' => 'Исходные документы',
  'source_completeness' => 'Комплектность',
  'recognition' => 'Распознавание данных',
  'hr_verification' => 'Проверка HR',
  'employee_card' => 'Карточка сотрудника',
  'package_and_conditions' => 'Пакет и условия',
  'generation' => 'Формирование документов',
  'printing' => 'Печать',
  'signing' => 'Подписание',
  'signed_documents' => 'Подписанные документы',
  'final_scans' => 'Финальные сканы',
  'archive_verification' => 'Проверка архива',
  'completion' => 'Завершение',
  _ => value,
};

String _dateText(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _cleanError(Object? value) {
  final text = value?.toString() ?? 'Неизвестная ошибка';
  return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
