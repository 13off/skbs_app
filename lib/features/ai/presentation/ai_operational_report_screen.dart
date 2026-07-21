import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../features/documents/data/document_template_repository.dart';
import '../../../features/documents/models/document_template.dart';
import '../../../features/recruitment/data/candidate_package_service.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/payments_screen.dart';
import '../models/ai_assistant_result.dart';

class AiOperationalReportScreen extends StatefulWidget {
  final AppUserProfile profile;
  final AiAssistantAction action;

  const AiOperationalReportScreen({
    super.key,
    required this.profile,
    required this.action,
  });

  @override
  State<AiOperationalReportScreen> createState() =>
      _AiOperationalReportScreenState();
}

class _AiOperationalReportScreenState
    extends State<AiOperationalReportScreen> {
  List<DocumentTemplateRecord> templates = const [];
  bool loadingTemplates = false;
  bool buildingPackage = false;
  String? packageMessage;

  bool get isCandidate =>
      widget.action.type == 'prepare_candidate_documents';

  List<Map<String, dynamic>> maps(String key) {
    final value = widget.action.payload[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    if (isCandidate) loadTemplates();
  }

  Future<void> loadTemplates() async {
    setState(() => loadingTemplates = true);
    try {
      final result = await DocumentTemplateRepository.fetchTemplates(
        companyId: widget.profile.activeCompanyId,
      );
      if (!mounted) return;
      setState(() {
        templates = result.where((template) {
          return const {
            'employment_application',
            'salary_transfer_application',
            'personal_data_consent',
            'employment_contract',
          }.contains(template.code);
        }).toList();
        loadingTemplates = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingTemplates = false);
    }
  }

  String money(Object? value) {
    final number = num.tryParse(value?.toString() ?? '') ?? 0;
    return '${number.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    )} ₽';
  }

  String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} КБ';
    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} МБ';
  }

  String documentType(String value) {
    return switch (value) {
      'passport' => 'Паспорт',
      'snils' => 'СНИЛС',
      'inn' => 'ИНН',
      'bank_details' => 'Банковские реквизиты',
      _ => value.isEmpty ? 'Документ' : value,
    };
  }

  Future<void> openTemplate(DocumentTemplateRecord template) async {
    final version = template.currentVersion;
    if (version == null || !template.isActive) return;
    try {
      await DocumentTemplateRepository.downloadVersion(version);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть форму: $error')),
      );
    }
  }

  Future<void> downloadCandidatePackage() async {
    if (buildingPackage) return;
    setState(() {
      buildingPackage = true;
      packageMessage = null;
    });
    try {
      final result = await CandidatePackageService.build(
        action: widget.action,
        companyId: widget.profile.activeCompanyId,
      );
      await CandidatePackageService.download(result);
      if (!mounted) return;
      setState(() {
        packageMessage = 'ZIP сохранён: ${result.includedFiles} файлов, '
            '${fileSize(result.archiveBytes)}. '
            'Предупреждений: ${result.warnings.length}.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пакет кандидата собран и сохранён')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        packageMessage = 'Не удалось собрать пакет: '
            '${error.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) setState(() => buildingPackage = false);
    }
  }

  Widget missingReceipts() {
    final rows = maps('rows');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rows.isEmpty
              ? 'Выплат без чеков не найдено'
              : 'Выплаты без чеков: ${rows.length}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text('Период: ${widget.action.text('month')}'),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('По выбранной области все выплаты имеют чеки.'),
            ),
          )
        else
          ...rows.map(
            (row) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  row['employee_name']?.toString() ?? 'Сотрудник',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${row['payment_date'] ?? ''} • ${row['object_name'] ?? ''}\n'
                  '${row['payment_type'] ?? ''}${(row['comment'] ?? '').toString().isEmpty ? '' : ' • ${row['comment']}'}',
                ),
                isThreeLine: true,
                trailing: Text(
                  money(row['amount']),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push<void>(
              CupertinoPageRoute<void>(
                builder: (_) => PaymentsScreen(
                  selectedObjectName: widget.action.text('object_name').isEmpty
                      ? null
                      : widget.action.text('object_name'),
                ),
              ),
            );
          },
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Открыть выплаты'),
        ),
      ],
    );
  }

  Widget candidatePackage() {
    final existing = maps('existing_documents');
    final missing = widget.action.stringList('missing_documents');
    final consent = widget.action.boolean('consent_personal_data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Пакет кандидата',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.action.text('full_name'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Должность: '
                  '${widget.action.text('position_title').isEmpty ? 'Не указана' : widget.action.text('position_title')}',
                ),
                Text(
                  'Телефон: '
                  '${widget.action.text('phone').isEmpty ? 'Не указан' : widget.action.text('phone')}',
                ),
                Text(
                  'Гражданство: '
                  '${widget.action.text('citizenship').isEmpty ? 'Не указано' : widget.action.text('citizenship')}',
                ),
                Text(
                  'Дата готовности: '
                  '${widget.action.text('ready_date').isEmpty ? 'Не указана' : widget.action.text('ready_date')}',
                ),
                Text(
                  'Согласие на обработку данных: '
                  '${consent ? 'получено' : 'не подтверждено'}',
                ),
              ],
            ),
          ),
        ),
        if (!consent) ...[
          const SizedBox(height: 10),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Скачивание закрыто, пока в карточке кандидата не '
                      'подтверждено согласие на обработку персональных данных.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Полученные файлы',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (existing.isEmpty)
          const Text('Файлы кандидата ещё не получены')
        else
          ...existing.map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(
                documentType(row['document_type']?.toString() ?? ''),
              ),
              subtitle: Text(row['original_name']?.toString() ?? ''),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Не хватает',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (missing.isEmpty)
          const Text('Базовый комплект документов собран')
        else
          ...missing.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline),
              title: Text(documentType(item)),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              buildingPackage || !consent ? null : downloadCandidatePackage,
          icon: buildingPackage
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_zip_outlined),
          label: Text(
            buildingPackage
                ? 'Собираем пакет…'
                : consent
                    ? 'Скачать пакет кандидата ZIP'
                    : 'Нужно согласие кандидата',
          ),
        ),
        if (packageMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            packageMessage!,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Исходные формы',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (loadingTemplates)
          const Center(child: CircularProgressIndicator())
        else
          ...templates.map((template) {
            final enabled = template.isActive && template.currentVersion != null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                enabled ? Icons.description_outlined : Icons.pending_actions,
              ),
              title: Text(template.title),
              subtitle: Text(
                enabled ? 'Действующая форма' : 'Требует утверждения',
              ),
              trailing: enabled ? const Icon(Icons.open_in_new) : null,
              onTap: enabled ? () => openTemplate(template) : null,
            );
          }),
        const SizedBox(height: 12),
        const Text(
          'Паспортные реквизиты и содержимое файлов не передавались ИИ. '
          'ZIP собирается локально после повторной проверки RLS.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isCandidate ? 'Документы кандидата' : 'Проверка чеков'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          isCandidate ? candidatePackage() : missingReceipts(),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Проверено'),
            ),
          ),
        ],
      ),
    );
  }
}