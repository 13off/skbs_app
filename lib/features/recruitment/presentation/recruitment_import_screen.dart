import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_crm_workspace_repository.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';

class RecruitmentImportScreen extends StatefulWidget {
  final AppUserProfile profile;
  final RecruitmentWorkspaceData workspace;

  const RecruitmentImportScreen({
    super.key,
    required this.profile,
    required this.workspace,
  });

  @override
  State<RecruitmentImportScreen> createState() =>
      _RecruitmentImportScreenState();
}

class _RecruitmentImportScreenState extends State<RecruitmentImportScreen> {
  List<String> headers = const [];
  List<List<String>> rows = const [];
  final Map<int, String> mapping = <int, String>{};
  final Set<int> selectedRows = <int>{};
  bool loading = false;
  bool importing = false;
  String? error;
  List<String> importErrors = const [];
  int importedCount = 0;

  RecruitmentCrmConfiguration get configuration =>
      widget.workspace.configuration;
  List<RecruitmentApplication> get existing => widget.workspace.applications;

  Map<String, String> get fields {
    final result = <String, String>{
      '': 'Не импортировать',
      'full_name': 'ФИО',
      'phone': 'Телефон',
      'citizenship': 'Гражданство',
      'vacancy': 'Вакансия',
      'object': 'Объект',
      'experience': 'Опыт',
      'departure_date': 'Дата выезда',
      'comment': 'Комментарий',
      'stage': 'Колонка CRM',
    };
    for (final field in configuration.fields) {
      result['custom:${field.id}'] = field.title;
    }
    return result;
  }

  String normalized(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

  String phoneKey(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  String autoField(String header) {
    final value = normalized(header);
    final synonyms = <String, List<String>>{
      'full_name': ['фио', 'кандидат', 'имя', 'fullname'],
      'phone': ['телефон', 'номер', 'phone', 'мобильный'],
      'citizenship': ['гражданство', 'citizenship'],
      'vacancy': ['вакансия', 'должность', 'профессия', 'vacancy'],
      'object': ['объект', 'город', 'направление', 'object'],
      'experience': ['опыт', 'стаж', 'experience'],
      'departure_date': ['датавыезда', 'готовность', 'дата', 'departuredate'],
      'comment': ['комментарий', 'примечание', 'заметка', 'comment'],
      'stage': ['этап', 'статус', 'колонка', 'stage'],
    };
    for (final entry in synonyms.entries) {
      if (entry.value.any(
        (candidate) => value.contains(normalized(candidate)),
      )) {
        return entry.key;
      }
    }
    for (final field in configuration.fields) {
      if (normalized(field.title) == value) return 'custom:${field.id}';
    }
    return '';
  }

  Future<void> pickFile() async {
    setState(() {
      loading = true;
      error = null;
      importErrors = const [];
    });
    try {
      const typeGroup = XTypeGroup(
        label: 'Excel',
        extensions: <String>['xlsx'],
      );
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('Выбранный файл пуст');
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) throw Exception('В книге нет листов');
      final sheet = excel.tables.values.first;
      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('В первом листе нет строк');
      }
      final parsedHeaders = sheet.rows.first
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .toList();
      final parsedRows = sheet.rows
          .skip(1)
          .map(
            (row) => List<String>.generate(
              parsedHeaders.length,
              (index) => index < row.length
                  ? row[index]?.value?.toString().trim() ?? ''
                  : '',
            ),
          )
          .where((row) => row.any((value) => value.isNotEmpty))
          .toList();
      mapping.clear();
      for (var index = 0; index < parsedHeaders.length; index++) {
        mapping[index] = autoField(parsedHeaders[index]);
      }
      selectedRows
        ..clear()
        ..addAll(List<int>.generate(parsedRows.length, (index) => index));
      if (!mounted) return;
      setState(() {
        headers = parsedHeaders;
        rows = parsedRows;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> downloadTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Кандидаты'];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final templateHeaders = <String>[
      'ФИО',
      'Телефон',
      'Гражданство',
      'Вакансия',
      'Объект',
      'Опыт',
      'Дата выезда',
      'Комментарий',
      'Колонка CRM',
      ...configuration.fields.map((field) => field.title),
    ];
    sheet.appendRow(templateHeaders.map(TextCellValue.new).toList());
    sheet.appendRow(<CellValue>[
      TextCellValue('Иванов Иван Иванович'),
      TextCellValue('+7 999 000-00-00'),
      TextCellValue('РФ'),
      TextCellValue('Бетонщик-арматурщик'),
      TextCellValue('Мурманск'),
      TextCellValue('5 лет'),
      TextCellValue('25.07.2026'),
      TextCellValue('Готов предоставить документы'),
      TextCellValue(
        configuration.stages.isEmpty ? '' : configuration.stages.first.title,
      ),
      ...configuration.fields.map((_) => TextCellValue('')),
    ]);
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Не удалось создать шаблон');
    await FileSaver.instance.saveFile(
      name: 'Шаблон_импорта_кандидатов',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  String valueFor(List<String> row, String fieldKey) {
    for (final entry in mapping.entries) {
      if (entry.value == fieldKey && entry.key < row.length)
        return row[entry.key];
    }
    return '';
  }

  RecruitmentPipelineStage? stageFor(String value) {
    final clean = normalized(value);
    if (clean.isEmpty) return configuration.stages.firstOrNull;
    for (final stage in configuration.stages) {
      if (normalized(stage.title) == clean ||
          normalized(stage.legacyStatus) == clean) {
        return stage;
      }
    }
    return configuration.stages.firstOrNull;
  }

  DateTime? parseDate(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    final direct = DateTime.tryParse(clean);
    if (direct != null) return direct;
    final parts = clean.split(RegExp(r'[./-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year < 100 ? 2000 + year : year, month, day);
      }
    }
    return null;
  }

  Map<String, dynamic> customValues(List<String> row) {
    final result = <String, dynamic>{};
    for (final field in configuration.fields) {
      final raw = valueFor(row, 'custom:${field.id}').trim();
      if (raw.isEmpty) continue;
      switch (field.fieldType) {
        case 'number':
        case 'money':
          result[field.id] =
              num.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.')) ?? raw;
          break;
        case 'boolean':
          result[field.id] = const {
            'да',
            'yes',
            'true',
            '1',
          }.contains(raw.toLowerCase());
          break;
        case 'multiselect':
          result[field.id] = raw
              .split(RegExp(r'[,;]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
          break;
        case 'date':
          result[field.id] =
              parseDate(raw)?.toIso8601String().split('T').first ?? raw;
          break;
        default:
          result[field.id] = raw;
      }
    }
    return result;
  }

  List<String> validateRow(int index) {
    final row = rows[index];
    final errors = <String>[];
    if (valueFor(row, 'full_name').trim().length < 2) errors.add('нет ФИО');
    if (phoneKey(valueFor(row, 'phone')).isEmpty) errors.add('нет телефона');
    if (valueFor(row, 'vacancy').trim().isEmpty) errors.add('нет вакансии');
    if (valueFor(row, 'object').trim().isEmpty) errors.add('нет объекта');
    return errors;
  }

  bool isDuplicate(int index) {
    final key = phoneKey(valueFor(rows[index], 'phone'));
    if (key.isEmpty) return false;
    return existing.any((item) => phoneKey(item.phone) == key) ||
        rows.asMap().entries.any((entry) {
          return entry.key < index &&
              selectedRows.contains(entry.key) &&
              phoneKey(valueFor(entry.value, 'phone')) == key;
        });
  }

  Future<void> downloadErrorReport() async {
    if (importErrors.isEmpty) return;
    final excel = Excel.createExcel();
    final sheet = excel['Ошибки'];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    sheet.appendRow(<CellValue>[
      TextCellValue('Результат импорта'),
      TextCellValue('Значение'),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Импортировано'),
      TextCellValue('$importedCount'),
    ]);
    for (final item in importErrors) {
      sheet.appendRow(<CellValue>[
        TextCellValue('Пропущено / ошибка'),
        TextCellValue(item),
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null) return;
    await FileSaver.instance.saveFile(
      name: 'Отчёт_импорта_кандидатов',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> runImport() async {
    if (importing || selectedRows.isEmpty) return;
    setState(() {
      importing = true;
      error = null;
      importErrors = const [];
    });
    final errors = <String>[];
    final importedIds = <String>[];
    var imported = 0;
    try {
      for (final index in selectedRows.toList()..sort()) {
        final rowErrors = validateRow(index);
        if (rowErrors.isNotEmpty) {
          errors.add('Строка ${index + 2}: ${rowErrors.join(', ')}');
          continue;
        }
        if (isDuplicate(index)) {
          errors.add('Строка ${index + 2}: дубль телефона');
          continue;
        }
        final row = rows[index];
        final stage = stageFor(valueFor(row, 'stage'));
        if (stage == null) {
          errors.add('Строка ${index + 2}: в CRM нет активных колонок');
          continue;
        }
        try {
          final application = await RecruitmentRepository.saveApplication(
            companyId: widget.profile.activeCompanyId,
            fullName: valueFor(row, 'full_name'),
            phone: valueFor(row, 'phone'),
            citizenship: valueFor(row, 'citizenship'),
            vacancy: valueFor(row, 'vacancy'),
            objectName: valueFor(row, 'object'),
            experience: valueFor(row, 'experience'),
            departureDate: parseDate(valueFor(row, 'departure_date')),
            status: stage.legacyStatus,
            stageId: stage.id,
            comment: valueFor(row, 'comment'),
            customValues: customValues(row),
            source: 'excel_import',
          );
          imported++;
          importedIds.add(application.id);
        } catch (exception) {
          errors.add(
            'Строка ${index + 2}: ${exception.toString().replaceFirst('Exception: ', '')}',
          );
        }
      }
      if (importedIds.isNotEmpty) {
        try {
          await RecruitmentCrmWorkspaceRepository.runAutomations(
            applicationIds: importedIds,
          );
        } catch (_) {
          errors.add(
            'Автоматизации для импортированных кандидатов не выполнились',
          );
        }
      }
      if (!mounted) return;
      setState(() {
        importErrors = errors;
        importedCount = imported;
      });
      if (imported > 0 && errors.isEmpty) Navigator.pop(context, imported);
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Импорт кандидатов',
      subtitle: 'Excel, сопоставление столбцов и проверка дублей',
      showBackButton: true,
      headerTrailing: FilledButton.icon(
        onPressed: downloadTemplate,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Шаблон'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '1. Выберите файл .xlsx',
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppUi.gap8),
                Text(
                  'Первая строка должна содержать названия столбцов. Перед сохранением можно изменить сопоставление и исключить строки.',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppUi.gap12),
                FilledButton.icon(
                  onPressed: loading ? null : pickFile,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(loading ? 'Читаю файл…' : 'Выбрать Excel'),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppUi.gap12),
            Text(error!, style: TextStyle(color: AppAdaptivePalette.danger)),
          ],
          if (headers.isNotEmpty) ...[
            const SizedBox(height: AppUi.gap16),
            PremiumWorkCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '2. Сопоставьте столбцы',
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap12),
                  Wrap(
                    spacing: AppUi.gap12,
                    runSpacing: AppUi.gap12,
                    children: headers.asMap().entries.map((entry) {
                      return SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<String>(
                          initialValue: mapping[entry.key] ?? '',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: entry.value.isEmpty
                                ? 'Столбец ${entry.key + 1}'
                                : entry.value,
                          ),
                          items: fields.entries
                              .map(
                                (field) => DropdownMenuItem(
                                  value: field.key,
                                  child: Text(
                                    field.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => mapping[entry.key] = value ?? ''),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUi.gap16),
            PremiumWorkCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '3. Предпросмотр — ${rows.length} строк',
                          style: TextStyle(
                            color: AppAdaptivePalette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          if (selectedRows.length == rows.length) {
                            selectedRows.clear();
                          } else {
                            selectedRows
                              ..clear()
                              ..addAll(
                                List<int>.generate(
                                  rows.length,
                                  (index) => index,
                                ),
                              );
                          }
                        }),
                        child: Text(
                          selectedRows.length == rows.length
                              ? 'Снять все'
                              : 'Выбрать все',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppUi.gap8),
                  ...rows.asMap().entries.take(200).map((entry) {
                    final rowErrors = validateRow(entry.key);
                    final duplicate = isDuplicate(entry.key);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selectedRows.contains(entry.key),
                      onChanged: (value) => setState(() {
                        value == true
                            ? selectedRows.add(entry.key)
                            : selectedRows.remove(entry.key);
                      }),
                      title: Text(
                        valueFor(entry.value, 'full_name').isEmpty
                            ? 'Строка ${entry.key + 2}'
                            : valueFor(entry.value, 'full_name'),
                      ),
                      subtitle: Text(
                        [
                          valueFor(entry.value, 'phone'),
                          valueFor(entry.value, 'vacancy'),
                          valueFor(entry.value, 'object'),
                          if (duplicate) 'ДУБЛЬ ТЕЛЕФОНА',
                          if (rowErrors.isNotEmpty) rowErrors.join(', '),
                        ].where((value) => value.isNotEmpty).join(' • '),
                      ),
                      secondary: Icon(
                        duplicate || rowErrors.isNotEmpty
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: duplicate || rowErrors.isNotEmpty
                            ? AppAdaptivePalette.warning
                            : AppAdaptivePalette.success,
                      ),
                    );
                  }),
                  if (rows.length > 200)
                    Text(
                      'Показаны первые 200 строк. Импорт обработает все выбранные.',
                    ),
                  if (importedCount > 0) ...[
                    const SizedBox(height: AppUi.gap12),
                    Text(
                      'Успешно импортировано: $importedCount',
                      style: TextStyle(
                        color: AppAdaptivePalette.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  if (importErrors.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap12),
                    Text(
                      importErrors.join('\n'),
                      style: TextStyle(
                        color: AppAdaptivePalette.warning,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppUi.gap8),
                    OutlinedButton.icon(
                      onPressed: downloadErrorReport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Скачать отчёт об ошибках'),
                    ),
                    if (importedCount > 0)
                      TextButton(
                        onPressed: () => Navigator.pop(context, importedCount),
                        child: const Text('Завершить импорт'),
                      ),
                  ],
                  const SizedBox(height: AppUi.gap16),
                  FilledButton.icon(
                    onPressed: importing || selectedRows.isEmpty
                        ? null
                        : runImport,
                    icon: importing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_check_rounded),
                    label: Text(
                      importing
                          ? 'Импортирую…'
                          : 'Импортировать выбранные (${selectedRows.length})',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
