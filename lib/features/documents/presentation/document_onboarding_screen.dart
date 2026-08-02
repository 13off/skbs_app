import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/employee_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_template_repository.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import '../models/document_template.dart';

class DocumentOnboardingScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? onboardingId;
  final EmployeeOnboardingRecord? onboarding;

  const DocumentOnboardingScreen({
    super.key,
    required this.profile,
    this.onboardingId,
    this.onboarding,
  }) : assert(onboardingId != null || onboarding != null);

  String get resolvedOnboardingId => onboardingId ?? onboarding!.id;

  @override
  State<DocumentOnboardingScreen> createState() =>
      _DocumentOnboardingScreenState();
}

class _DocumentOnboardingScreenState extends State<DocumentOnboardingScreen> {
  late Future<_OnboardingData> future;
  bool busy = false;

  String get companyId => widget.profile.activeCompanyId;
  String get onboardingId => widget.resolvedOnboardingId;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_OnboardingData> load() async {
    final access = await DocumentWorkflowRepository.fetchAccess();
    if (!access.canView) throw StateError('Нет доступа к оформлению');
    final process = await DocumentWorkflowRepository.fetchOnboarding(
      onboardingId,
    );
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      DocumentWorkflowRepository.fetchSteps(onboardingId),
      DocumentWorkflowRepository.fetchFiles(
        companyId: companyId,
        onboardingId: onboardingId,
      ),
      DocumentWorkflowRepository.fetchPackages(companyId),
      DocumentWorkflowRepository.fetchEmployees(companyId),
      DocumentWorkflowRepository.fetchCandidates(companyId),
      DocumentWorkflowRepository.fetchObjects(companyId),
      access.canViewTemplates
          ? DocumentTemplateRepository.fetchTemplates(companyId: companyId)
          : Future<List<DocumentTemplateRecord>>.value(
              const <DocumentTemplateRecord>[],
            ),
      process.packageId == null
          ? Future<List<DocumentPackageTemplateLink>>.value(
              const <DocumentPackageTemplateLink>[],
            )
          : DocumentWorkflowRepository.fetchPackageTemplateLinks(
              companyId: companyId,
              packageId: process.packageId,
            ),
      access.canViewAudit
          ? DocumentWorkflowRepository.fetchAudit(
              companyId: companyId,
              onboardingId: onboardingId,
            )
          : Future<List<DocumentAuditRecord>>.value(
              const <DocumentAuditRecord>[],
            ),
    ]);
    return _OnboardingData(
      access: access,
      process: process,
      steps: values[0] as List<DocumentOnboardingStepRecord>,
      files: values[1] as List<EmployeeDocumentFileRecord>,
      packages: values[2] as List<DocumentPackageRecord>,
      employees: values[3] as List<DocumentEmployeeOption>,
      candidates: values[4] as List<DocumentCandidateOption>,
      objects: values[5] as List<DocumentObjectOption>,
      templates: values[6] as List<DocumentTemplateRecord>,
      packageLinks: values[7] as List<DocumentPackageTemplateLink>,
      audit: values[8] as List<DocumentAuditRecord>,
    );
  }

  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  Future<void> advance(
    _OnboardingData data,
    DocumentOnboardingStepRecord step,
  ) async {
    if (busy || data.process.isCompleted) return;
    setState(() => busy = true);
    try {
      final payload = await _payloadForStep(data, step.stepCode);
      if (payload == null || !mounted) return;
      await DocumentWorkflowRepository.advanceOnboarding(
        onboardingId: onboardingId,
        currentStep: step.stepCode,
        payload: payload,
      );
      await refresh();
      _message(
        step.stepCode == DocumentOnboardingSteps.completion
            ? 'Оформление завершено'
            : 'Этап завершён',
      );
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Map<String, dynamic>?> _payloadForStep(
    _OnboardingData data,
    String stepCode,
  ) async {
    switch (stepCode) {
      case DocumentOnboardingSteps.sourceFiles:
        return <String, dynamic>{
          'source_files': data.files
              .where((file) => file.fileKind == 'source')
              .map((file) => file.id)
              .toList(growable: false),
        };
      case DocumentOnboardingSteps.sourceCompleteness:
        final accepted = await _confirm(
          title: 'Комплектность проверена?',
          message:
              'Проверьте паспорт, прописку, СНИЛС, ИНН, полис и фото. '
              'Компания может дополнить обязательный перечень в настройках.',
          confirmLabel: 'Комплектность подтверждена',
        );
        return accepted
            ? <String, dynamic>{
                'confirmed': true,
                'checked_at': DateTime.now().toUtc().toIso8601String(),
              }
            : null;
      case DocumentOnboardingSteps.recognition:
        return _editRecognition(data.process.recognizedData);
      case DocumentOnboardingSteps.hrVerification:
        final accepted = await _confirmRecognized(data.process.recognizedData);
        return accepted
            ? <String, dynamic>{
                'hr_confirmed': true,
                'checked_fields': data.process.recognizedData.keys.toList(),
                'checked_at': DateTime.now().toUtc().toIso8601String(),
              }
            : null;
      case DocumentOnboardingSteps.employeeCard:
        if (data.process.employeeId == null) {
          final employeeId = await _selectOrCreateEmployee(data);
          if (employeeId == null) return null;
          await DocumentWorkflowRepository.setOnboardingContext(
            onboardingId: onboardingId,
            employeeId: employeeId,
          );
          return <String, dynamic>{'employee_id': employeeId};
        }
        return <String, dynamic>{'employee_id': data.process.employeeId};
      case DocumentOnboardingSteps.packageAndConditions:
        final contextDraft = await _editContext(data);
        if (contextDraft == null) return null;
        await DocumentWorkflowRepository.setOnboardingContext(
          onboardingId: onboardingId,
          packageId: contextDraft.packageId,
          objectId: contextDraft.objectId,
          onboardingType: contextDraft.onboardingType,
          conditions: contextDraft.conditions,
        );
        return <String, dynamic>{
          'confirmed': true,
          'package_id': contextDraft.packageId,
          'object_id': contextDraft.objectId,
          'conditions': contextDraft.conditions,
        };
      case DocumentOnboardingSteps.generation:
        final generated = data.files
            .where((file) => file.fileKind == 'generated')
            .toList(growable: false);
        if (generated.isEmpty) {
          throw StateError(
            'Сначала подготовьте документ по утверждённому шаблону и загрузите результат',
          );
        }
        return <String, dynamic>{
          'generated_file_ids': generated.map((file) => file.id).toList(),
        };
      case DocumentOnboardingSteps.printing:
        final accepted = await _confirm(
          title: 'Документы переданы на печать?',
          message:
              'Этот этап фиксирует передачу сформированного комплекта на печать.',
          confirmLabel: 'Да, переданы на печать',
        );
        return accepted
            ? <String, dynamic>{
                'printed': true,
                'printed_at': DateTime.now().toUtc().toIso8601String(),
              }
            : null;
      case DocumentOnboardingSteps.signing:
        final accepted = await _confirm(
          title: 'Подписание состоялось?',
          message:
              'Подтвердите факт подписания сотрудником и представителем компании.',
          confirmLabel: 'Да, документы подписаны',
        );
        return accepted
            ? <String, dynamic>{
                'signed': true,
                'signed_at': DateTime.now().toUtc().toIso8601String(),
              }
            : null;
      case DocumentOnboardingSteps.signedDocuments:
        return <String, dynamic>{
          'accepted_files': data.files
              .where((file) => file.fileKind == 'signed' && file.isAccepted)
              .map((file) => file.id)
              .toList(),
        };
      case DocumentOnboardingSteps.finalScans:
        return <String, dynamic>{
          'accepted_files': data.files
              .where((file) => file.fileKind == 'final_scan' && file.isAccepted)
              .map((file) => file.id)
              .toList(),
        };
      case DocumentOnboardingSteps.archiveVerification:
        final accepted = await _confirm(
          title: 'Архив проверен?',
          message:
              'Проверьте версии, читаемость, подписи и обязательный состав. '
              'Для СКБС в общий Word/PDF входят только паспорт, прописка, '
              'СНИЛС, ИНН, полис и фото.',
          confirmLabel: 'Архив проверен',
        );
        return accepted
            ? <String, dynamic>{
                'archive_confirmed': true,
                'checked_at': DateTime.now().toUtc().toIso8601String(),
              }
            : null;
      case DocumentOnboardingSteps.completion:
        final blockers = await DocumentWorkflowRepository.fetchBlockers(
          onboardingId,
        );
        if (blockers.isNotEmpty) {
          final messages = blockers
              .map((item) => item['message']?.toString() ?? '')
              .where((item) => item.isNotEmpty)
              .join('\n• ');
          throw StateError('Оформление пока нельзя завершить:\n• $messages');
        }
        final accepted = await _confirm(
          title: 'Завершить оформление?',
          message:
              'После завершения процесс и его юридически значимый архив '
              'останутся в истории. Старые версии не будут удалены.',
          confirmLabel: 'Завершить оформление',
        );
        return accepted
            ? <String, dynamic>{
                'completed': true,
                'confirmed_at': DateTime.now().toUtc().toIso8601String(),
              }
            : null;
      default:
        return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>?> _editRecognition(
    Map<String, dynamic> initial,
  ) async {
    const fields = <(String, String)>[
      ('full_name', 'ФИО'),
      ('birth_date', 'Дата рождения'),
      ('passport_series', 'Серия паспорта'),
      ('passport_number', 'Номер паспорта'),
      ('passport_issued_by', 'Кем выдан паспорт'),
      ('passport_issue_date', 'Дата выдачи'),
      ('registration_address', 'Адрес регистрации'),
      ('snils', 'СНИЛС'),
      ('inn', 'ИНН'),
      ('phone', 'Телефон'),
      ('bank_details', 'Банковские реквизиты'),
    ];
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field.$1: TextEditingController(
          text: initial[field.$1]?.toString() ?? '',
        ),
    };
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Распознанные данные'),
        content: SizedBox(
          width: 660,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OCR заполняет черновик, но юридически значимые поля всегда '
                  'проверяются человеком. Сейчас можно исправить каждое поле.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 14),
                for (final field in fields) ...[
                  TextField(
                    controller: controllers[field.$1],
                    decoration: InputDecoration(labelText: field.$2),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, <String, dynamic>{
              'mode': initial['mode'] ?? 'manual',
              'edited_at': DateTime.now().toUtc().toIso8601String(),
              for (final field in fields)
                field.$1: controllers[field.$1]!.text.trim(),
            }),
            child: const Text('Сохранить данные'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<bool> _confirmRecognized(Map<String, dynamic> values) async {
    var confirmed = false;
    final rows = values.entries
        .where(
          (entry) =>
              entry.key != 'mode' &&
              entry.key != 'edited_at' &&
              entry.value.toString().trim().isNotEmpty,
        )
        .toList(growable: false);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ручная проверка HR'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text('${row.key}: ${row.value}'),
                    ),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: (value) {
                      setDialogState(() => confirmed = value == true);
                    },
                    title: const Text(
                      'Я сверил данные с исходными документами',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: confirmed ? () => Navigator.pop(context, true) : null,
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<String?> _selectOrCreateEmployee(_OnboardingData data) async {
    String? selectedId;
    final candidate = _candidateForProcess(data);
    final result = await showDialog<_EmployeeChoice>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Карточка сотрудника'),
          content: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Выбрать существующего сотрудника',
                  ),
                  items: [
                    for (final employee in data.employees)
                      DropdownMenuItem(
                        value: employee.id,
                        child: Text(
                          employee.objectName.isEmpty
                              ? employee.fullName
                              : '${employee.fullName} · ${employee.objectName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedId = value);
                  },
                ),
                if (candidate != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Кандидат: ${candidate.fullName}'
                    '${candidate.phone.isEmpty ? '' : ' · ${candidate.phone}'}',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            if (candidate != null)
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(context, const _EmployeeChoice.create()),
                child: const Text('Создать из кандидата'),
              ),
            FilledButton(
              onPressed: selectedId == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _EmployeeChoice.existing(selectedId!),
                    ),
              child: const Text('Выбрать'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return null;
    if (result.employeeId != null) return result.employeeId;
    if (!result.createFromCandidate || candidate == null) return null;

    final duplicate = _findDuplicate(data.employees, candidate);
    if (duplicate != null) {
      final useExisting = await _confirm(
        title: 'Похожий сотрудник уже существует',
        message:
            '${duplicate.fullName} · ${duplicate.phone}. '
            'Чтобы не создать дубль, будет использована существующая карточка.',
        confirmLabel: 'Использовать карточку',
      );
      return useExisting ? duplicate.id : null;
    }

    final objectName = _objectName(
      data.objects,
      candidate.objectId.isNotEmpty
          ? candidate.objectId
          : data.process.objectId ?? '',
    );
    final draft = await _employeeDraft(candidate, objectName);
    if (draft == null) return null;
    return EmployeeRepository.addEmployee(
      fio: candidate.fullName,
      position: draft.position,
      phone: draft.phone,
      objectName: draft.objectName,
      dailyRate: draft.dailyRate,
      comment: 'Создано из документооборота AppСтрой',
    );
  }

  Future<_EmployeeDraft?> _employeeDraft(
    DocumentCandidateOption candidate,
    String objectName,
  ) async {
    final phone = TextEditingController(text: candidate.phone);
    final position = TextEditingController(text: candidate.position);
    final object = TextEditingController(text: objectName);
    final rate = TextEditingController();
    final result = await showDialog<_EmployeeDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Создать ${candidate.fullName}'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: position,
                decoration: const InputDecoration(labelText: 'Должность'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: object,
                decoration: const InputDecoration(labelText: 'Объект'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rate,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ставка за смену, ₽',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final cleanPosition = position.text.trim();
              final cleanObject = object.text.trim();
              if (cleanPosition.isEmpty || cleanObject.isEmpty) return;
              Navigator.pop(
                context,
                _EmployeeDraft(
                  phone: phone.text.trim(),
                  position: cleanPosition,
                  objectName: cleanObject,
                  dailyRate: int.tryParse(rate.text.trim()) ?? 0,
                ),
              );
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    phone.dispose();
    position.dispose();
    object.dispose();
    rate.dispose();
    return result;
  }

  Future<_ContextDraft?> _editContext(_OnboardingData data) async {
    String? packageId = data.process.packageId;
    String? objectId = data.process.objectId;
    String onboardingType = data.process.onboardingType;
    final position = TextEditingController(
      text: data.process.conditions['position']?.toString() ?? '',
    );
    final compensation = TextEditingController(
      text: data.process.conditions['compensation']?.toString() ?? '',
    );
    final startDate = TextEditingController(
      text: data.process.conditions['start_date']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: data.process.conditions['notes']?.toString() ?? '',
    );
    final result = await showDialog<_ContextDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Пакет и условия'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: packageId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Пакет документов',
                    ),
                    items: [
                      for (final item in data.packages)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.title),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        packageId = value;
                        for (final item in data.packages) {
                          if (item.id == value) {
                            onboardingType = item.onboardingType;
                            break;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: objectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Объект'),
                    items: [
                      for (final item in data.objects)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => objectId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: position,
                    decoration: const InputDecoration(labelText: 'Должность'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: compensation,
                    decoration: InputDecoration(
                      labelText: onboardingType == 'gph'
                          ? 'Вознаграждение по договору'
                          : 'Оплата',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: startDate,
                    decoration: const InputDecoration(labelText: 'Дата начала'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Комментарий'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: packageId == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _ContextDraft(
                        packageId: packageId!,
                        objectId: objectId,
                        onboardingType: onboardingType,
                        conditions: <String, dynamic>{
                          'position': position.text.trim(),
                          'compensation': compensation.text.trim(),
                          'start_date': startDate.text.trim(),
                          'notes': notes.text.trim(),
                          'payment_term': onboardingType == 'gph'
                              ? 'Вознаграждение по договору'
                              : 'Оплата по условиям оформления',
                        },
                      ),
                    ),
              child: const Text('Сохранить условия'),
            ),
          ],
        ),
      ),
    );
    position.dispose();
    compensation.dispose();
    startDate.dispose();
    notes.dispose();
    return result;
  }

  Future<void> uploadFile(
    _OnboardingData data, {
    required String fileKind,
  }) async {
    if (busy || !data.access.canEdit) return;
    final type = await _documentType(fileKind);
    if (type == null || !mounted) return;
    DocumentTemplateRecord? template;
    if (fileKind == 'generated') {
      template = await _selectTemplate(data);
      if (template == null || !mounted) return;
    }
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Документы',
          extensions: <String>[
            'pdf',
            'doc',
            'docx',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'txt',
          ],
        ),
      ],
    );
    if (file == null || !mounted) return;
    setState(() => busy = true);
    try {
      final version = template?.currentVersion;
      await DocumentWorkflowRepository.uploadFile(
        companyId: companyId,
        onboardingId: onboardingId,
        employeeId: data.process.employeeId,
        fileKind: fileKind,
        documentType: type,
        fileName: file.name,
        mimeType: _mime(file.name),
        bytes: await file.readAsBytes(),
        templateId: template?.id,
        templateVersionId: version?.id,
        metadata: <String, dynamic>{
          if (template != null) 'template_title': template.title,
          if (version != null) 'template_version': version.versionNo,
        },
      );
      await refresh();
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> _documentType(String fileKind) async {
    final options = switch (fileKind) {
      'source' => const <(String, String)>[
        ('passport', 'Паспорт'),
        ('registration', 'Прописка'),
        ('snils', 'СНИЛС'),
        ('inn', 'ИНН'),
        ('policy', 'Полис'),
        ('photo', 'Фото'),
        ('other', 'Другой документ'),
      ],
      'generated' => const <(String, String)>[
        ('generated_document', 'Сформированный документ'),
      ],
      'signed' => const <(String, String)>[
        ('signed_contract', 'Подписанный договор'),
        ('signed_application', 'Подписанное заявление'),
        ('signed_consent', 'Подписанное согласие'),
        ('signed_other', 'Другой подписанный документ'),
      ],
      _ => const <(String, String)>[
        ('passport', 'Паспорт'),
        ('registration', 'Прописка'),
        ('snils', 'СНИЛС'),
        ('inn', 'ИНН'),
        ('policy', 'Полис'),
        ('photo', 'Фото'),
        ('other', 'Другой финальный скан'),
      ],
    };
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Тип документа'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option.$1),
              child: Text(option.$2),
            ),
        ],
      ),
    );
  }

  Future<DocumentTemplateRecord?> _selectTemplate(_OnboardingData data) async {
    final allowedIds = data.packageLinks.map((item) => item.templateId).toSet();
    final templates = data.templates
        .where((template) {
          if (!template.isActive || template.currentVersion == null)
            return false;
          return allowedIds.isEmpty || allowedIds.contains(template.id);
        })
        .toList(growable: false);
    if (templates.isEmpty) {
      throw StateError(
        'В выбранном пакете нет утверждённого шаблона с активной версией',
      );
    }
    return showDialog<DocumentTemplateRecord>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Исходный шаблон'),
        children: [
          for (final template in templates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, template),
              child: Text(
                '${template.title} · v${template.currentVersion!.versionNo}',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> openTemplate(_OnboardingData data) async {
    try {
      final template = await _selectTemplate(data);
      final version = template?.currentVersion;
      if (version == null) return;
      await DocumentTemplateRepository.downloadVersion(version);
    } catch (error) {
      _message(_cleanError(error));
    }
  }

  Future<void> verifyFile(
    _OnboardingData data,
    EmployeeDocumentFileRecord file,
  ) async {
    if (busy || !data.access.canVerify) return;
    final decision = await showDialog<_VerificationDraft>(
      context: context,
      builder: (context) => const _VerificationDialog(),
    );
    if (decision == null || !mounted) return;
    setState(() => busy = true);
    try {
      await DocumentWorkflowRepository.verifyFile(
        fileId: file.id,
        accepted: decision.accepted,
        qualityStatus: decision.qualityStatus,
        comment: decision.comment,
      );
      await refresh();
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openFileRecord(EmployeeDocumentFileRecord file) async {
    try {
      final url = await DocumentWorkflowRepository.createSignedFileUrl(file);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Не удалось открыть файл');
    } catch (error) {
      _message(_cleanError(error));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  DocumentCandidateOption? _candidateForProcess(_OnboardingData data) {
    final id = data.process.recruitmentApplicationId;
    if (id == null) return null;
    for (final candidate in data.candidates) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  DocumentEmployeeOption? _findDuplicate(
    List<DocumentEmployeeOption> employees,
    DocumentCandidateOption candidate,
  ) {
    final name = candidate.fullName.trim().toLowerCase();
    final phone = _digits(candidate.phone);
    for (final employee in employees) {
      if (employee.fullName.trim().toLowerCase() == name) return employee;
      if (phone.isNotEmpty && _digits(employee.phone) == phone) return employee;
    }
    return null;
  }

  String _objectName(List<DocumentObjectOption> objects, String id) {
    for (final object in objects) {
      if (object.id == id) return object.name;
    }
    return '';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Оформление сотрудника',
      subtitle: '13 обязательных этапов',
      onRefresh: refresh,
      child: FutureBuilder<_OnboardingData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: _cleanError(snapshot.error),
              onRetry: refresh,
            );
          }
          final data = snapshot.requireData;
          final currentStep = _currentStep(data);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProcessHeader(data: data),
              const SizedBox(height: 14),
              _ProgressHeader(
                steps: data.steps,
                currentStep: data.process.currentStep,
              ),
              const SizedBox(height: 14),
              if (data.process.isCompleted)
                _CompletedCard(process: data.process)
              else if (currentStep != null)
                _CurrentStepCard(
                  data: data,
                  step: currentStep,
                  busy: busy,
                  onAdvance: () => advance(data, currentStep),
                  onUpload: (kind) => uploadFile(data, fileKind: kind),
                  onOpenTemplate: () => openTemplate(data),
                ),
              const SizedBox(height: 18),
              _FilesSection(
                data: data,
                busy: busy,
                onOpen: openFileRecord,
                onVerify: (file) => verifyFile(data, file),
              ),
              if (data.access.canViewAudit) ...[
                const SizedBox(height: 18),
                _AuditSection(records: data.audit),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OnboardingData {
  final DocumentWorkflowAccess access;
  final EmployeeOnboardingRecord process;
  final List<DocumentOnboardingStepRecord> steps;
  final List<EmployeeDocumentFileRecord> files;
  final List<DocumentPackageRecord> packages;
  final List<DocumentEmployeeOption> employees;
  final List<DocumentCandidateOption> candidates;
  final List<DocumentObjectOption> objects;
  final List<DocumentTemplateRecord> templates;
  final List<DocumentPackageTemplateLink> packageLinks;
  final List<DocumentAuditRecord> audit;

  const _OnboardingData({
    required this.access,
    required this.process,
    required this.steps,
    required this.files,
    required this.packages,
    required this.employees,
    required this.candidates,
    required this.objects,
    required this.templates,
    required this.packageLinks,
    required this.audit,
  });
}

class _ProcessHeader extends StatelessWidget {
  final _OnboardingData data;

  const _ProcessHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.process.personName,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (data.process.packageTitle.isNotEmpty)
                data.process.packageTitle,
              if (data.process.objectName.isNotEmpty) data.process.objectName,
              _statusTitle(data.process.status),
            ].join(' · '),
          ),
          if (data.process.dueAt != null) ...[
            const SizedBox(height: 7),
            Text('Срок: ${_dateText(data.process.dueAt!)}'),
          ],
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final List<DocumentOnboardingStepRecord> steps;
  final String currentStep;

  const _ProgressHeader({required this.steps, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final completed = steps.where((step) => step.isCompleted).length;
    final total = steps.isEmpty ? 13 : steps.length;
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stepTitle(currentStep),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text('$completed из $total'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: total == 0 ? 0 : completed / total),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  _StepDot(
                    index: index + 1,
                    completed: steps[index].isCompleted,
                    active: steps[index].stepCode == currentStep,
                  ),
                  if (index != steps.length - 1)
                    Container(
                      width: 18,
                      height: 2,
                      color: steps[index].isCompleted
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool completed;
  final bool active;

  const _StepDot({
    required this.index,
    required this.completed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed || active
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
      child: completed
          ? Icon(Icons.check_rounded, size: 17, color: scheme.onPrimary)
          : Text(
              '$index',
              style: TextStyle(
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
    );
  }
}

class _CurrentStepCard extends StatelessWidget {
  final _OnboardingData data;
  final DocumentOnboardingStepRecord step;
  final bool busy;
  final VoidCallback onAdvance;
  final ValueChanged<String> onUpload;
  final VoidCallback onOpenTemplate;

  const _CurrentStepCard({
    required this.data,
    required this.step,
    required this.busy,
    required this.onAdvance,
    required this.onUpload,
    required this.onOpenTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final uploadKind = switch (step.stepCode) {
      DocumentOnboardingSteps.sourceFiles => 'source',
      DocumentOnboardingSteps.generation => 'generated',
      DocumentOnboardingSteps.signedDocuments => 'signed',
      DocumentOnboardingSteps.finalScans => 'final_scan',
      _ => null,
    };
    final requiredVerify = <String>{
      DocumentOnboardingSteps.hrVerification,
      DocumentOnboardingSteps.signedDocuments,
      DocumentOnboardingSteps.finalScans,
      DocumentOnboardingSteps.archiveVerification,
      DocumentOnboardingSteps.completion,
    }.contains(step.stepCode);
    final canAdvance = requiredVerify
        ? data.access.canVerify
        : data.access.canEdit;
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stepTitle(step.stepCode),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(_stepDescription(step.stepCode)),
          if (uploadKind != null) ...[
            const SizedBox(height: 10),
            Text(
              'Файлов этого этапа: '
              '${data.files.where((file) => file.fileKind == uploadKind).length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (step.stepCode == DocumentOnboardingSteps.generation)
                OutlinedButton.icon(
                  onPressed: busy ? null : onOpenTemplate,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Открыть утверждённый шаблон'),
                ),
              if (uploadKind != null && data.access.canEdit)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onUpload(uploadKind),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    uploadKind == 'generated'
                        ? 'Загрузить сформированный файл'
                        : 'Загрузить файл',
                  ),
                ),
              FilledButton.icon(
                onPressed: busy || !canAdvance ? null : onAdvance,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  step.stepCode == DocumentOnboardingSteps.completion
                      ? 'Завершить оформление'
                      : 'Завершить этап',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilesSection extends StatelessWidget {
  final _OnboardingData data;
  final bool busy;
  final ValueChanged<EmployeeDocumentFileRecord> onOpen;
  final ValueChanged<EmployeeDocumentFileRecord> onVerify;

  const _FilesSection({
    required this.data,
    required this.busy,
    required this.onOpen,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Файлы и версии',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (data.files.isEmpty)
            const Text('Файлы ещё не загружены')
          else
            for (final file in data.files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_fileIcon(file.fileKind)),
                title: Text(file.originalFileName),
                subtitle: Text(
                  '${_fileKindTitle(file.fileKind)} · ${file.documentType} · '
                  'v${file.versionNo} · ${_verificationTitle(file.verificationStatus)}',
                ),
                onTap: () => onOpen(file),
                trailing:
                    data.access.canVerify &&
                        file.verificationStatus == 'pending'
                    ? IconButton(
                        tooltip: 'Проверить',
                        onPressed: busy ? null : () => onVerify(file),
                        icon: const Icon(Icons.fact_check_outlined),
                      )
                    : Icon(
                        file.isAccepted
                            ? Icons.verified_rounded
                            : file.isRejected
                            ? Icons.cancel_outlined
                            : Icons.chevron_right_rounded,
                      ),
              ),
        ],
      ),
    );
  }
}

class _AuditSection extends StatelessWidget {
  final List<DocumentAuditRecord> records;

  const _AuditSection({required this.records});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'История действий',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (records.isEmpty)
            const Text('Записей пока нет')
          else
            for (final record in records.take(30))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.history_rounded),
                title: Text(record.action),
                subtitle: Text(
                  '${record.entityType} · ${_dateTimeText(record.createdAt)}',
                ),
              ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final EmployeeOnboardingRecord process;

  const _CompletedCard({required this.process});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, size: 58),
          const SizedBox(height: 12),
          const Text(
            'Оформление завершено',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Архив, версии шаблонов и журнал действий сохранены.',
            textAlign: TextAlign.center,
          ),
          if (process.completionSnapshot.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Сформировано: ${process.completionSnapshot['generated_files'] ?? 0} · '
              'Подписано: ${process.completionSnapshot['signed_files'] ?? 0} · '
              'Финальных сканов: ${process.completionSnapshot['final_scans'] ?? 0}',
            ),
          ],
        ],
      ),
    );
  }
}

class _VerificationDialog extends StatefulWidget {
  const _VerificationDialog();

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  bool accepted = true;
  String quality = 'accepted';
  final comment = TextEditingController();

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Проверка файла'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.check_rounded),
                  label: Text('Принять'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.close_rounded),
                  label: Text('Отклонить'),
                ),
              ],
              selected: <bool>{accepted},
              onSelectionChanged: (values) {
                setState(() => accepted = values.first);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: quality,
              decoration: const InputDecoration(labelText: 'Качество'),
              items: const [
                DropdownMenuItem(value: 'accepted', child: Text('Читаемый')),
                DropdownMenuItem(
                  value: 'manual_review',
                  child: Text('Нужна ручная проверка'),
                ),
                DropdownMenuItem(value: 'blurred', child: Text('Смазан')),
                DropdownMenuItem(value: 'cropped', child: Text('Обрезан')),
                DropdownMenuItem(value: 'dark', child: Text('Слишком тёмный')),
                DropdownMenuItem(
                  value: 'unreadable',
                  child: Text('Нечитаемый'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => quality = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _VerificationDraft(
              accepted: accepted,
              qualityStatus: accepted ? quality : 'rejected',
              comment: comment.text.trim(),
            ),
          ),
          child: const Text('Сохранить проверку'),
        ),
      ],
    );
  }
}

class _VerificationDraft {
  final bool accepted;
  final String qualityStatus;
  final String comment;

  const _VerificationDraft({
    required this.accepted,
    required this.qualityStatus,
    required this.comment,
  });
}

class _EmployeeChoice {
  final String? employeeId;
  final bool createFromCandidate;

  const _EmployeeChoice.existing(String id)
    : employeeId = id,
      createFromCandidate = false;

  const _EmployeeChoice.create()
    : employeeId = null,
      createFromCandidate = true;
}

class _EmployeeDraft {
  final String phone;
  final String position;
  final String objectName;
  final int dailyRate;

  const _EmployeeDraft({
    required this.phone,
    required this.position,
    required this.objectName,
    required this.dailyRate,
  });
}

class _ContextDraft {
  final String packageId;
  final String? objectId;
  final String onboardingType;
  final Map<String, dynamic> conditions;

  const _ContextDraft({
    required this.packageId,
    required this.objectId,
    required this.onboardingType,
    required this.conditions,
  });
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

DocumentOnboardingStepRecord? _currentStep(_OnboardingData data) {
  for (final step in data.steps) {
    if (step.stepCode == data.process.currentStep) return step;
  }
  return data.steps.isEmpty ? null : data.steps.first;
}

String _stepTitle(String code) => switch (code) {
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
  _ => code,
};

String _stepDescription(String code) => switch (code) {
  'source_files' =>
    'Загрузите фото, PDF или сканы документов кандидата. Файлы из CRM подключаются автоматически без дублирования.',
  'source_completeness' =>
    'Проверьте обязательный комплект по правилам компании.',
  'recognition' =>
    'Проверьте и исправьте поля, полученные из документов. Автоподтверждение запрещено.',
  'hr_verification' =>
    'Ответственный HR вручную сверяет каждое юридически значимое поле.',
  'employee_card' =>
    'Выберите существующего сотрудника или создайте карточку из кандидата без дубля.',
  'package_and_conditions' =>
    'Зафиксируйте пакет, объект, должность, дату начала и оплату. Для ГПХ используется формулировка «вознаграждение».',
  'generation' =>
    'Используйте утверждённую версию шаблона, подготовьте DOCX/PDF и загрузите результат с привязкой к версии.',
  'printing' => 'Зафиксируйте передачу сформированного комплекта на печать.',
  'signing' => 'Зафиксируйте подписание сотрудником и компанией.',
  'signed_documents' =>
    'Загрузите подписанные экземпляры. Проверяющий должен принять хотя бы один файл.',
  'final_scans' =>
    'Загрузите качественные финальные сканы. Проверяющий должен принять хотя бы один файл.',
  'archive_verification' =>
    'Проверьте комплект, качество, версии и правила формирования общего Word/PDF.',
  'completion' =>
    'Система повторно проверит все обязательные этапы и закроет процесс.',
  _ => '',
};

String _statusTitle(String value) => switch (value) {
  'draft' => 'Черновик',
  'in_progress' => 'В работе',
  'blocked' => 'Заблокировано',
  'completed' => 'Завершено',
  'cancelled' => 'Отменено',
  _ => value,
};

String _fileKindTitle(String value) => switch (value) {
  'source' => 'Исходный файл',
  'generated' => 'Сформированный документ',
  'signed' => 'Подписанный документ',
  'final_scan' => 'Финальный скан',
  'archive' => 'Архив',
  _ => value,
};

String _verificationTitle(String value) => switch (value) {
  'accepted' => 'принят',
  'rejected' => 'отклонён',
  _ => 'ожидает проверки',
};

IconData _fileIcon(String value) => switch (value) {
  'source' => Icons.file_present_outlined,
  'generated' => Icons.description_outlined,
  'signed' => Icons.draw_outlined,
  'final_scan' => Icons.scanner_outlined,
  'archive' => Icons.archive_outlined,
  _ => Icons.insert_drive_file_outlined,
};

String _mime(String name) {
  final value = name.toLowerCase();
  if (value.endsWith('.pdf')) return 'application/pdf';
  if (value.endsWith('.doc')) return 'application/msword';
  if (value.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (value.endsWith('.png')) return 'image/png';
  if (value.endsWith('.webp')) return 'image/webp';
  if (value.endsWith('.jpg') || value.endsWith('.jpeg')) return 'image/jpeg';
  if (value.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _dateText(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _dateTimeText(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_dateText(value)} $hour:$minute';
}

String _cleanError(Object? value) {
  final text = value?.toString() ?? 'Неизвестная ошибка';
  return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
