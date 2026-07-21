import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/employee_private_data_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../features/documents/data/exact_docx_service.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../models/employee_private_data.dart';
import '../../../widgets/premium_ui.dart';
import '../models/ai_assistant_result.dart';

class AiExactDocumentScreen extends StatefulWidget {
  final AppUserProfile profile;
  final AiAssistantAction action;
  final String templateCode;

  const AiExactDocumentScreen({
    super.key,
    required this.profile,
    required this.action,
    required this.templateCode,
  });

  @override
  State<AiExactDocumentScreen> createState() => _AiExactDocumentScreenState();
}

class _AiExactDocumentScreenState extends State<AiExactDocumentScreen> {
  final Map<String, TextEditingController> controllers =
      <String, TextEditingController>{};

  bool loading = true;
  bool building = false;
  bool downloaded = false;
  String? errorText;
  Employee? employee;
  EmployeePrivateData? privateData;

  ExactDocxTemplateInfo? get template =>
      ExactDocxService.templateFor(widget.templateCode);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final resolvedEmployee = await _resolveEmployee();
      EmployeePrivateData? resolvedPrivateData;
      final employeeId = resolvedEmployee?.id?.trim() ?? '';
      if ((widget.profile.isAdmin || widget.profile.isHr) &&
          employeeId.isNotEmpty) {
        try {
          resolvedPrivateData =
              await EmployeePrivateDataRepository.fetchByEmployeeId(employeeId);
        } catch (_) {
          // RLS остаётся источником истины. Поля можно заполнить вручную.
        }
      }

      employee = resolvedEmployee;
      privateData = resolvedPrivateData;
      _fillControllers(resolvedEmployee, resolvedPrivateData);
      if (!mounted) return;
      setState(() => loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Не удалось загрузить данные для формы: $error';
      });
    }
  }

  Future<Employee?> _resolveEmployee() async {
    final employeeId = widget.action.text('employee_id');
    final employeeName = widget.action.text('employee_name');
    final objectName = widget.action.text('object_name');
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName.isEmpty ? null : objectName,
      includeFired: true,
      forceRefresh: true,
    );

    if (employeeId.isNotEmpty) {
      for (final item in employees) {
        if (item.id == employeeId) return item;
      }
    }

    if (employeeName.isNotEmpty) {
      final normalized = employeeName.trim().toLowerCase();
      final matches = employees
          .where((item) => item.name.trim().toLowerCase() == normalized)
          .toList(growable: false);
      if (matches.length == 1) return matches.single;
    }
    return null;
  }

  void _fillControllers(
    Employee? employee,
    EmployeePrivateData? privateData,
  ) {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();

    final documentDate = widget.action.date('date') ?? DateTime.now();
    final employmentDate = _firstNotEmpty(<String>[
      privateData?.employmentStartDate ?? '',
      widget.action.text('employment_date'),
      DateFormat('dd.MM.yyyy').format(documentDate),
    ]);
    final values = <String, String>{
      'employee_full_name': employee?.name ?? widget.action.text('employee_name'),
      'employee_short_name': _shortName(
        employee?.name ?? widget.action.text('employee_name'),
      ),
      'employee_position':
          employee?.position ?? widget.action.text('position_title'),
      'employment_date': employmentDate,
      'document_date': DateFormat('dd.MM.yyyy').format(documentDate),
      'bank_account': privateData?.bankAccount ?? '',
      'bank_name': privateData?.bankName ?? '',
      'bank_bik': privateData?.bankBik ?? '',
      'bank_corr_account': privateData?.bankCorrAccount ?? '',
      'bank_inn': privateData?.bankInn ?? '',
      'bank_kpp': privateData?.bankKpp ?? '',
      'bank_okpo': privateData?.bankOkpo ?? '',
      'bank_ogrn': privateData?.bankOgrn ?? '',
      'bank_swift': privateData?.bankSwift ?? '',
      'bank_address': privateData?.bankAddress ?? '',
      'bank_office_address': privateData?.bankOfficeAddress ?? '',
    };

    for (final field in template?.requiredFields ?? const <String>[]) {
      controllers[field] = TextEditingController(text: values[field] ?? '');
    }
  }

  String _firstNotEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _shortName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    final buffer = StringBuffer(parts.first);
    for (final part in parts.skip(1).take(2)) {
      buffer.write(' ${part.characters.first}.');
    }
    return buffer.toString();
  }

  Map<String, String> get currentValues => <String, String>{
        for (final entry in controllers.entries) entry.key: entry.value.text.trim(),
      };

  List<String> get missingFields {
    final values = currentValues;
    return (template?.requiredFields ?? const <String>[])
        .where((field) => (values[field] ?? '').trim().isEmpty)
        .toList(growable: false);
  }

  Future<void> downloadExactDocx() async {
    if (building) return;
    final missing = missingFields;
    if (missing.isNotEmpty) {
      setState(() {
        errorText = 'Заполни обязательные поля: '
            '${missing.map(_fieldTitle).join(', ')}';
      });
      return;
    }

    setState(() {
      building = true;
      errorText = null;
    });
    try {
      final result = ExactDocxService.build(
        templateCode: widget.templateCode,
        values: currentValues,
        fileBaseName:
            '${widget.templateCode}_${controllers['employee_full_name']?.text ?? ''}',
      );
      final baseName = result.fileName.replaceFirst(
        RegExp(r'\.docx$', caseSensitive: false),
        '',
      );
      await FileSaver.instance.saveFile(
        name: baseName,
        bytes: result.bytes,
        ext: 'docx',
        mimeType: MimeType.microsoftWord,
      );
      if (!mounted) return;
      setState(() => downloaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оригинальный DOCX заполнен и сохранён')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Не удалось собрать DOCX: $error');
    } finally {
      if (mounted) setState(() => building = false);
    }
  }

  String _fieldTitle(String field) {
    return switch (field) {
      'employee_full_name' => 'ФИО',
      'employee_short_name' => 'Фамилия и инициалы',
      'employee_position' => 'Должность',
      'employment_date' => 'Дата приёма',
      'document_date' => 'Дата документа',
      'bank_account' => 'Расчётный счёт',
      'bank_name' => 'Наименование банка',
      'bank_bik' => 'БИК',
      'bank_corr_account' => 'Корреспондентский счёт',
      'bank_inn' => 'ИНН банка',
      'bank_kpp' => 'КПП банка',
      'bank_okpo' => 'ОКПО банка',
      'bank_ogrn' => 'ОГРН банка',
      'bank_swift' => 'SWIFT',
      'bank_address' => 'Адрес банка',
      'bank_office_address' => 'Адрес отделения',
      _ => field,
    };
  }

  TextInputType _keyboardType(String field) {
    return switch (field) {
      'bank_account' ||
      'bank_bik' ||
      'bank_corr_account' ||
      'bank_inn' ||
      'bank_kpp' ||
      'bank_okpo' ||
      'bank_ogrn' => TextInputType.number,
      _ => TextInputType.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = template;
    return Scaffold(
      appBar: AppBar(title: Text(info?.title ?? 'Заполнение DOCX')),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : errorText != null && controllers.isEmpty
                  ? _buildFatalError()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                      children: [
                        PremiumWorkCard(
                          radius: 24,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Оригинальная форма ООО «СКБС»',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Структура, таблицы и поля формы сохраняются. '
                                'Реквизиты подставляются локально и не передаются ИИ. '
                                'Подпись и отправка не выполняются.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                'SHA-256 исходника: ${info?.originalSha256 ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final entry in controllers.entries) ...[
                          TextField(
                            controller: entry.value,
                            keyboardType: _keyboardType(entry.key),
                            decoration: InputDecoration(
                              labelText: _fieldTitle(entry.key),
                              border: const OutlineInputBorder(),
                              errorText: entry.value.text.trim().isEmpty &&
                                      errorText != null
                                  ? 'Заполни поле'
                                  : null,
                            ),
                            onChanged: (_) {
                              if (errorText != null) {
                                setState(() => errorText = null);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (errorText != null) ...[
                          Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: building ? null : downloadExactDocx,
                          icon: building
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(
                            building
                                ? 'Собираем DOCX…'
                                : 'Скачать заполненный оригинал',
                          ),
                        ),
                        if (downloaded) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Готово'),
                          ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildFatalError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorText ?? 'Не удалось открыть форму',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: loadData, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
