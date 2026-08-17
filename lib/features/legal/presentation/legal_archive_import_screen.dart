import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_document_operations_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';

class LegalArchiveImportScreen extends StatefulWidget {
  const LegalArchiveImportScreen({super.key});

  @override
  State<LegalArchiveImportScreen> createState() => _LegalArchiveImportScreenState();
}

class _LegalArchiveImportScreenState extends State<LegalArchiveImportScreen> {
  late Future<List<LegalWorkspaceEmployee>> employeesFuture;
  List<_ArchiveRow> rows = <_ArchiveRow>[];
  bool importing = false;
  int imported = 0;

  @override
  void initState() {
    super.initState();
    employeesFuture = LegalWorkspaceRepository.fetchEmployees();
  }

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-.,()]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String? autoEmployee(XFile file, List<LegalWorkspaceEmployee> employees) {
    final name = normalize(file.name);
    LegalWorkspaceEmployee? best;
    var bestScore = 0;
    for (final employee in employees) {
      final tokens = normalize(employee.fio)
          .split(' ')
          .where((token) => token.length >= 3)
          .toList();
      if (tokens.isEmpty) continue;
      final score = tokens.where(name.contains).length;
      if (score > bestScore && score >= 2) {
        best = employee;
        bestScore = score;
      }
    }
    return best?.id;
  }

  _ArchiveType classify(String fileName) {
    final value = normalize(fileName);
    if (value.contains('гпх') ||
        value.contains('оказан') && value.contains('услуг') ||
        value.contains('подряд')) {
      return const _ArchiveType('gph_contract', 'Договор ГПХ / оказания услуг');
    }
    if (value.contains('трудов') && value.contains('договор')) {
      return const _ArchiveType('employment_contract', 'Трудовой договор');
    }
    if (value.contains('заявлен') &&
        (value.contains('работ') || value.contains('прием') || value.contains('приём'))) {
      return const _ArchiveType('employment_application', 'Заявление на работу');
    }
    if (value.contains('заявлен') &&
        (value.contains('зарп') || value.contains('перечис') || value.contains('выплат'))) {
      return const _ArchiveType(
        'salary_transfer_application',
        'Заявление о перечислении зарплаты',
      );
    }
    if (value.contains('персональ') && value.contains('данн')) {
      return const _ArchiveType('personal_data_consent', 'Согласие на обработку персональных данных');
    }
    if (value.contains('паспорт')) {
      return const _ArchiveType('passport', 'Паспорт');
    }
    if (value.contains('пропис') || value.contains('регистрац')) {
      return const _ArchiveType('registration', 'Регистрация / прописка');
    }
    if (value.contains('снилс')) return const _ArchiveType('snils', 'СНИЛС');
    if (value.contains('инн')) return const _ArchiveType('inn', 'ИНН');
    if (value.contains('полис') || value.contains('страхов')) {
      return const _ArchiveType('insurance', 'Полис');
    }
    if (value.contains('фото')) return const _ArchiveType('photo', 'Фото');
    if (value.contains('объясн')) {
      return const _ArchiveType('explanation', 'Объяснительная');
    }
    if (value.contains('акт')) return const _ArchiveType('act', 'Акт');
    if (value.contains('увольн') && value.contains('заявлен')) {
      return const _ArchiveType('termination_application', 'Заявление на увольнение');
    }
    if (value.contains('билет') && value.contains('соглаш')) {
      return const _ArchiveType('ticket_purchase_agreement', 'Соглашение на приобретение билетов');
    }
    return const _ArchiveType('other', 'Прочий документ');
  }

  Future<void> pickFiles(List<LegalWorkspaceEmployee> employees) async {
    final files = await LegalDocumentOperationsRepository.pickDocumentFiles();
    if (files.isEmpty) return;
    setState(() {
      rows = files.map((file) {
        final type = classify(file.name);
        return _ArchiveRow(
          file: file,
          employeeId: autoEmployee(file, employees),
          typeCode: type.code,
          typeTitle: type.title,
        );
      }).toList();
      imported = 0;
    });
  }

  LegalWorkspaceEmployee? employeeById(
    String? id,
    List<LegalWorkspaceEmployee> employees,
  ) {
    if (id == null) return null;
    for (final item in employees) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> importAll(List<LegalWorkspaceEmployee> employees) async {
    if (importing) return;
    final ready = rows.where((item) => item.employeeId != null).toList();
    if (ready.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите сотрудника хотя бы для одного файла')),
      );
      return;
    }
    setState(() {
      importing = true;
      imported = 0;
    });
    try {
      for (final row in ready) {
        final employee = employeeById(row.employeeId, employees);
        if (employee == null) continue;
        final document = await LegalRepository.saveDocument(
          title: row.typeTitle == 'Прочий документ'
              ? row.file.name
              : row.typeTitle,
          documentType: row.typeCode,
          documentNumber: '',
          status: 'prepared',
          createdOn: DateTime.now(),
          employeeId: employee.id,
          objectId: employee.objectId.isEmpty ? null : employee.objectId,
          comment: 'Импортировано из существующего архива: ${row.file.name}',
          nextAction: '',
          requiresForemanAction: false,
          requiresManagerApproval: false,
          approvalStatus: 'none',
        );
        await LegalDocumentOperationsRepository.uploadVersion(
          documentId: document.id,
          file: row.file,
          versionLabel: 'Импорт из архива',
        );
        if (mounted) setState(() => imported += 1);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импортировано: $imported')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импорт остановлен: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Widget rowCard(
    _ArchiveRow row,
    int index,
    List<LegalWorkspaceEmployee> employees,
  ) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Убрать',
                onPressed: importing
                    ? null
                    : () => setState(() => rows.removeAt(index)),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: row.employeeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Сотрудник',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            items: employees
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      item.objectName.isEmpty
                          ? item.fio
                          : '${item.fio} — ${item.objectName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: importing
                ? null
                : (value) => setState(() => row.employeeId = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: row.typeCode,
            decoration: const InputDecoration(
              labelText: 'Тип документа',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            items: _types
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.title),
                  ),
                )
                .toList(),
            onChanged: importing
                ? null
                : (value) {
                    if (value == null) return;
                    final type = _types.firstWhere((item) => item.code == value);
                    setState(() {
                      row.typeCode = type.code;
                      row.typeTitle = type.title;
                    });
                  },
          ),
          if (row.employeeId == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Сотрудник не определён автоматически — выберите вручную. Файл не будет импортирован без привязки.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт архива')),
      body: FutureBuilder<List<LegalWorkspaceEmployee>>(
        future: employeesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Не удалось загрузить сотрудников: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final employees = snapshot.data!;
          final ready = rows.where((item) => item.employeeId != null).length;
          return AppPage(
            title: 'Импорт существующих документов',
            subtitle: 'Приложение предлагает сотрудника и тип, но ничего не привязывает молча',
            headerTrailing: FilledButton.icon(
              onPressed: importing ? null : () => pickFiles(employees),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Выбрать файлы'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    rows.isEmpty
                        ? 'Выберите PDF, Word, Excel или изображения. По имени файла будет предложен сотрудник и тип документа.'
                        : 'Файлов: ${rows.length} • готовы: $ready • требуют ручной привязки: ${rows.length - ready}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  rows.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: rowCard(rows[index], index, employees),
                  ),
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    onPressed: importing ? null : () => importAll(employees),
                    icon: importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(importing ? 'Импорт $imported / $ready' : 'Импортировать $ready'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ArchiveRow {
  final XFile file;
  String? employeeId;
  String typeCode;
  String typeTitle;

  _ArchiveRow({
    required this.file,
    required this.employeeId,
    required this.typeCode,
    required this.typeTitle,
  });
}

class _ArchiveType {
  final String code;
  final String title;

  const _ArchiveType(this.code, this.title);
}

const _types = <_ArchiveType>[
  _ArchiveType('gph_contract', 'Договор ГПХ / оказания услуг'),
  _ArchiveType('employment_contract', 'Трудовой договор'),
  _ArchiveType('employment_application', 'Заявление на работу'),
  _ArchiveType('salary_transfer_application', 'Заявление о перечислении зарплаты'),
  _ArchiveType('personal_data_consent', 'Согласие на обработку персональных данных'),
  _ArchiveType('passport', 'Паспорт'),
  _ArchiveType('registration', 'Регистрация / прописка'),
  _ArchiveType('snils', 'СНИЛС'),
  _ArchiveType('inn', 'ИНН'),
  _ArchiveType('insurance', 'Полис'),
  _ArchiveType('photo', 'Фото'),
  _ArchiveType('act', 'Акт'),
  _ArchiveType('explanation', 'Объяснительная'),
  _ArchiveType('termination_application', 'Заявление на увольнение'),
  _ArchiveType('ticket_purchase_agreement', 'Соглашение на приобретение билетов'),
  _ArchiveType('other', 'Прочий документ'),
];
