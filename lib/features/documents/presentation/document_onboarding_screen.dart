import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';

class DocumentOnboardingScreen extends StatefulWidget {
  final AppUserProfile profile;
  final EmployeeOnboardingRecord? onboarding;

  const DocumentOnboardingScreen({
    super.key,
    required this.profile,
    this.onboarding,
  });

  @override
  State<DocumentOnboardingScreen> createState() => _DocumentOnboardingScreenState();
}

class _DocumentOnboardingScreenState extends State<DocumentOnboardingScreen> {
  EmployeeOnboardingRecord? onboarding;
  Future<_OnboardingData>? future;
  bool busy = false;

  String get companyId => widget.profile.activeCompanyId;

  @override
  void initState() {
    super.initState();
    onboarding = widget.onboarding;
    if (onboarding != null) future = load();
  }

  Future<_OnboardingData> load() async {
    final current = onboarding;
    if (current == null) throw StateError('Процесс оформления не создан');
    final values = await Future.wait<dynamic>([
      DocumentWorkflowRepository.fetchSteps(current.id),
      DocumentWorkflowRepository.fetchFiles(
        companyId: companyId,
        onboardingId: current.id,
      ),
      DocumentWorkflowRepository.fetchAudit(
        companyId: companyId,
        onboardingId: current.id,
      ),
      DocumentWorkflowRepository.fetchPackages(companyId),
    ]);
    return _OnboardingData(
      steps: values[0] as List<DocumentOnboardingStepRecord>,
      files: values[1] as List<EmployeeDocumentFileRecord>,
      audit: values[2] as List<DocumentAuditRecord>,
      packages: values[3] as List<DocumentPackageRecord>,
    );
  }

  Future<void> refresh() async {
    if (onboarding == null) return;
    setState(() => future = load());
    await future;
  }

  Future<void> create() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final created = await DocumentWorkflowRepository.createOnboarding(
        companyId: companyId,
        onboardingType: 'custom',
        assignedUserId: widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        onboarding = created;
        future = load();
      });
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> advance(DocumentOnboardingStepRecord step) async {
    final current = onboarding;
    if (current == null || busy) return;
    if (!_canAdvance(step)) {
      showError(StateError(_blockReason(step.stepCode)));
      return;
    }
    setState(() => busy = true);
    try {
      await DocumentWorkflowRepository.advanceOnboarding(
        companyId: companyId,
        onboardingId: current.id,
        currentStep: step.stepCode,
        payload: step.payload,
      );
      final refreshed = await DocumentWorkflowRepository.fetchOnboardings(
        companyId: companyId,
      );
      final next = refreshed.where((item) => item.id == current.id).firstOrNull;
      if (!mounted) return;
      setState(() {
        onboarding = next ?? current;
        future = load();
      });
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool _canAdvance(DocumentOnboardingStepRecord step) {
    final data = future;
    if (data == null) return true;
    return true;
  }

  String _blockReason(String stepCode) {
    return switch (stepCode) {
      DocumentOnboardingSteps.hrVerification => 'Подтвердите распознанные данные вручную',
      DocumentOnboardingSteps.signedDocuments => 'Загрузите подписанные документы',
      DocumentOnboardingSteps.finalScans => 'Загрузите финальные сканы',
      _ => 'Этап ещё не готов к завершению',
    };
  }

  Future<void> upload({
    required String fileKind,
    required String documentType,
  }) async {
    final current = onboarding;
    if (current == null || busy) return;
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Документы',
          extensions: <String>['pdf', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (file == null) return;
    setState(() => busy = true);
    try {
      final bytes = await file.readAsBytes();
      await DocumentWorkflowRepository.uploadFile(
        companyId: companyId,
        onboardingId: current.id,
        employeeId: current.employeeId,
        fileKind: fileKind,
        documentType: documentType,
        fileName: file.name,
        mimeType: _mime(file.name),
        bytes: bytes,
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify(EmployeeDocumentFileRecord file, bool accepted) async {
    final current = onboarding;
    if (current == null || busy) return;
    setState(() => busy = true);
    try {
      await DocumentWorkflowRepository.verifyFile(
        companyId: companyId,
        fileId: file.id,
        onboardingId: current.id,
        accepted: accepted,
      );
      await refresh();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openFileRecord(EmployeeDocumentFileRecord file) async {
    try {
      final url = await DocumentWorkflowRepository.createSignedFileUrl(file);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(file.originalFileName),
          content: SelectableText(url),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (error) {
      showError(error);
    }
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cleanError(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = onboarding;
    return AppPage(
      title: current == null ? 'Новое оформление' : 'Оформление сотрудника',
      subtitle: current == null ? 'Создание процесса' : _statusTitle(current.status),
      child: current == null
          ? _CreateState(busy: busy, onCreate: create)
          : FutureBuilder<_OnboardingData>(
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
                final active = data.steps.where((step) => step.stepCode == current.currentStep).firstOrNull ?? data.steps.firstOrNull;
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _ProgressHeader(
                        steps: data.steps,
                        currentStep: current.currentStep,
                      ),
                      const SizedBox(height: 16),
                      if (active != null)
                        _CurrentStepCard(
                          step: active,
                          busy: busy,
                          files: data.files,
                          onAdvance: () => advance(active),
                          onUploadSource: () => upload(
                            fileKind: 'source',
                            documentType: 'candidate_document',
                          ),
                          onUploadSigned: () => upload(
                            fileKind: 'signed',
                            documentType: 'signed_document',
                          ),
                          onUploadFinal: () => upload(
                            fileKind: 'final_scan',
                            documentType: 'final_scan',
                          ),
                        ),
                      const SizedBox(height: 18),
                      _FilesSection(
                        files: data.files,
                        busy: busy,
                        onOpen: openFileRecord,
                        onVerify: verify,
                      ),
                      const SizedBox(height: 18),
                      _AuditSection(records: data.audit),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _OnboardingData {
  final List<DocumentOnboardingStepRecord> steps;
  final List<EmployeeDocumentFileRecord> files;
  final List<DocumentAuditRecord> audit;
  final List<DocumentPackageRecord> packages;

  const _OnboardingData({
    required this.steps,
    required this.files,
    required this.audit,
    required this.packages,
  });
}

class _CreateState extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreate;

  const _CreateState({required this.busy, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 60),
        PremiumWorkCard(
          radius: 28,
          child: Column(
            children: [
              const Icon(Icons.assignment_ind_outlined, size: 58),
              const SizedBox(height: 16),
              const Text(
                'Создать процесс оформления',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                'Будут созданы 13 последовательных этапов — от исходных документов кандидата до проверенного кадрового архива.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: busy ? null : onCreate,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Начать оформление'),
              ),
            ],
          ),
        ),
      ],
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              Text('$completed из $total'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: completed / total),
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

  const _StepDot({required this.index, required this.completed, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed || active ? scheme.primary : scheme.surfaceContainerHighest,
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
  final DocumentOnboardingStepRecord step;
  final bool busy;
  final List<EmployeeDocumentFileRecord> files;
  final VoidCallback onAdvance;
  final VoidCallback onUploadSource;
  final VoidCallback onUploadSigned;
  final VoidCallback onUploadFinal;

  const _CurrentStepCard({
    required this.step,
    required this.busy,
    required this.files,
    required this.onAdvance,
    required this.onUploadSource,
    required this.onUploadSigned,
    required this.onUploadFinal,
  });

  @override
  Widget build(BuildContext context) {
    final uploadAction = switch (step.stepCode) {
      DocumentOnboardingSteps.sourceFiles => onUploadSource,
      DocumentOnboardingSteps.signedDocuments => onUploadSigned,
      DocumentOnboardingSteps.finalScans => onUploadFinal,
      _ => null,
    };
    final relevantKind = switch (step.stepCode) {
      DocumentOnboardingSteps.sourceFiles => 'source',
      DocumentOnboardingSteps.signedDocuments => 'signed',
      DocumentOnboardingSteps.finalScans => 'final_scan',
      _ => null,
    };
    final relevantCount = relevantKind == null ? 0 : files.where((file) => file.fileKind == relevantKind).length;
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
          if (relevantKind != null) ...[
            const SizedBox(height: 14),
            Text(
              'Загружено: $relevantCount',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (uploadAction != null)
                OutlinedButton.icon(
                  onPressed: busy ? null : uploadAction,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Загрузить файл'),
                ),
              FilledButton.icon(
                onPressed: busy ? null : onAdvance,
                icon: const Icon(Icons.arrow_forward_rounded),
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
  final List<EmployeeDocumentFileRecord> files;
  final bool busy;
  final Future<void> Function(EmployeeDocumentFileRecord file) onOpen;
  final Future<void> Function(EmployeeDocumentFileRecord file, bool accepted) onVerify;

  const _FilesSection({
    required this.files,
    required this.busy,
    required this.onOpen,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Файлы оформления',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (files.isEmpty)
          const PremiumWorkCard(
            radius: 22,
            child: Text('Файлы ещё не загружены.'),
          )
        else
          for (final file in files)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumWorkCard(
                radius: 22,
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.originalFileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text('${_fileKindTitle(file.fileKind)} · v${file.versionNo} · ${_verificationTitle(file.verificationStatus)}'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Открыть',
                      onPressed: busy ? null : () => onOpen(file),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                    PopupMenuButton<bool>(
                      enabled: !busy,
                      onSelected: (value) => onVerify(file, value),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: true, child: Text('Принять файл')),
                        PopupMenuItem(value: false, child: Text('Отклонить файл')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _AuditSection extends StatelessWidget {
  final List<DocumentAuditRecord> records;

  const _AuditSection({required this.records});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'История действий',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      children: [
        for (final record in records)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded),
            title: Text(_auditTitle(record.action)),
            subtitle: Text('${record.entityType} · ${_dateTime(record.createdAt)}'),
          ),
      ],
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
            const Icon(Icons.error_outline_rounded, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

String _stepTitle(String value) => switch (value) {
      DocumentOnboardingSteps.sourceFiles => '1. Документы кандидата получены',
      DocumentOnboardingSteps.sourceCompleteness => '2. Комплектность исходных документов',
      DocumentOnboardingSteps.recognition => '3. Распознавание данных',
      DocumentOnboardingSteps.hrVerification => '4. Проверка HR',
      DocumentOnboardingSteps.employeeCard => '5. Создание или обновление сотрудника',
      DocumentOnboardingSteps.packageAndConditions => '6. Пакет и условия',
      DocumentOnboardingSteps.generation => '7. Формирование документов',
      DocumentOnboardingSteps.printing => '8. Печать',
      DocumentOnboardingSteps.signing => '9. Подписание',
      DocumentOnboardingSteps.signedDocuments => '10. Подписанные документы',
      DocumentOnboardingSteps.finalScans => '11. Финальные сканы',
      DocumentOnboardingSteps.archiveVerification => '12. Проверка архива',
      DocumentOnboardingSteps.completion => '13. Завершение оформления',
      _ => value,
    };

String _stepDescription(String value) => switch (value) {
      DocumentOnboardingSteps.sourceFiles => 'Загрузите фото, PDF или сканы исходных документов кандидата.',
      DocumentOnboardingSteps.sourceCompleteness => 'Проверьте паспорт, прописку, СНИЛС, ИНН, полис, фото и требования компании.',
      DocumentOnboardingSteps.recognition => 'Запустите распознавание и предварительное заполнение карточки. Юридически значимые данные автоматически не подтверждаются.',
      DocumentOnboardingSteps.hrVerification => 'HR вручную сверяет и подтверждает каждое распознанное поле.',
      DocumentOnboardingSteps.employeeCard => 'Создайте черновик сотрудника или свяжите процесс с существующей карточкой без дубля.',
      DocumentOnboardingSteps.packageAndConditions => 'Выберите тип оформления, пакет, объект, должность, дату начала и вознаграждение.',
      DocumentOnboardingSteps.generation => 'Сформируйте DOCX и PDF по утверждённым версиям существующих шаблонов.',
      DocumentOnboardingSteps.printing => 'Зафиксируйте передачу документов на печать.',
      DocumentOnboardingSteps.signing => 'Подтвердите подписание сотрудником и компанией.',
      DocumentOnboardingSteps.signedDocuments => 'Загрузите подписанные договоры, заявления и согласия.',
      DocumentOnboardingSteps.finalScans => 'Загрузите качественные архивные сканы документов.',
      DocumentOnboardingSteps.archiveVerification => 'Проверьте комплектность, качество, версии и соответствие данных.',
      DocumentOnboardingSteps.completion => 'Система повторно проверит обязательные этапы, подписанные документы и финальные сканы.',
      _ => '',
    };

String _fileKindTitle(String value) => switch (value) {
      'source' => 'Исходный файл',
      'generated' => 'Сформированный документ',
      'signed' => 'Подписанный документ',
      'final_scan' => 'Финальный скан',
      _ => value,
    };

String _verificationTitle(String value) => switch (value) {
      'pending' => 'ожидает проверки',
      'accepted' => 'принят',
      'rejected' => 'отклонён',
      _ => value,
    };

String _statusTitle(String value) => switch (value) {
      'draft' => 'Черновик',
      'in_progress' => 'В работе',
      'blocked' => 'Заблокировано',
      'completed' => 'Завершено',
      _ => value,
    };

String _auditTitle(String value) => switch (value) {
      'created' => 'Процесс создан',
      'uploaded' => 'Файл загружен',
      'accepted' => 'Файл принят',
      'rejected' => 'Файл отклонён',
      'completed' => 'Этап или процесс завершён',
      _ => value,
    };

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _mime(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _cleanError(Object? value) {
  final text = value?.toString() ?? 'Неизвестная ошибка';
  return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
