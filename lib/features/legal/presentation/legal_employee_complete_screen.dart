import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_employee_dossier_repository.dart';
import '../data/legal_operations_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import '../models/legal_models.dart';
import 'legal_document_complete_screen.dart';
import 'legal_documents_screen.dart';
import 'legal_matters_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalEmployeeCompleteScreen extends StatefulWidget {
  final LegalWorkspaceEmployee employee;

  const LegalEmployeeCompleteScreen({super.key, required this.employee});

  @override
  State<LegalEmployeeCompleteScreen> createState() =>
      _LegalEmployeeCompleteScreenState();
}

class _LegalEmployeeCompleteScreenState
    extends State<LegalEmployeeCompleteScreen> {
  late Future<_EmployeeCompleteData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_EmployeeCompleteData> load() async {
    final values = await Future.wait<dynamic>([
      LegalEmployeeDossierRepository.fetchDossier(widget.employee.id),
      LegalEmployeeDossierRepository.fetchDocuments(widget.employee.id),
      LegalOperationsRepository.fetchEmployeeCompleteness(widget.employee.id),
      LegalRepository.fetchMatters(),
      LegalWorkspaceRepository.fetchRecoveries(),
    ]);
    return _EmployeeCompleteData(
      dossier: values[0] as LegalEmployeeDossier,
      documents: values[1] as List<LegalEmployeeDossierDocument>,
      requirements: values[2] as List<LegalEmployeeRequirement>,
      matters: (values[3] as List<LegalMatter>)
          .where((item) => item.employeeId == widget.employee.id)
          .toList(),
      recoveries: (values[4] as List<LegalWorkspaceRecovery>)
          .where((item) => item.employeeId == widget.employee.id)
          .toList(),
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String date(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String money(double value) {
    final raw = value.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(' ');
      out.write(raw[i]);
    }
    return '${out.toString()} ₽';
  }

  String dataValue(LegalEmployeeDossier dossier, String key) =>
      dossier.text(key);

  Widget sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget fieldCard(String title, List<(String, String)> fields) {
    final visible = fields.where((item) => item.$2.trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...visible.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 145,
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        item.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget completeness(List<LegalEmployeeRequirement> requirements) {
    final applicable = requirements.where((item) => item.applicable).toList();
    final required = applicable.where((item) => item.required).toList();
    final done = required.where((item) => item.present).length;
    final missing = required.where((item) => !item.present).toList();
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Icon(
                  missing.isEmpty
                      ? Icons.verified_outlined
                      : Icons.assignment_late_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Комплект документов',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      required.isEmpty
                          ? 'Обязательные документы не настроены'
                          : '$done из ${required.length} обязательных документов',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (required.isNotEmpty)
                Text(
                  '${((done / required.length) * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (required.isNotEmpty) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: done / required.length,
              minHeight: 8,
            ),
          ],
          const SizedBox(height: 12),
          ...applicable.map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.present
                    ? Icons.check_circle_rounded
                    : item.required
                    ? Icons.cancel_outlined
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.required ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              subtitle: Text(
                item.present
                    ? (item.matchedSource.isEmpty
                          ? 'есть'
                          : 'есть • ${item.matchedSource}')
                    : item.required
                    ? 'не загружено'
                    : 'необязательно',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> addDocument(LegalEmployeeDossier dossier) async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => LegalDocumentEditorScreen(
          initialEmployeeId: dossier.employeeId,
          initialObjectId: dossier.objectId,
        ),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> openDocument(LegalEmployeeDossierDocument item) async {
    if (item.legalDocumentId.isNotEmpty) {
      final doc = await LegalRepository.fetchDocument(item.legalDocumentId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalDocumentCompleteScreen(document: doc),
        ),
      );
      if (mounted) await refresh();
      return;
    }
    if (item.hasStoredFile) {
      await LegalWorkspaceRepository.openStoredFile(
        bucketName: item.bucketName,
        storagePath: item.storagePath,
      );
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Файл ещё не прикреплён')));
    }
  }

  Widget documentGroups(List<LegalEmployeeDossierDocument> documents) {
    const groups = <String, (String, String)>{
      'contract': (
        'Договоры',
        'Трудовые, ГПХ, оказание услуг, подряд и другие договоры',
      ),
      'application_consent': (
        'Заявления и согласия',
        'Приём, выплаты, персональные данные и другие формы',
      ),
      'personal_document': (
        'Личные документы',
        'Паспорт, регистрация, СНИЛС, ИНН, полис, фото',
      ),
      'act_explanation': (
        'Акты и объяснительные',
        'Нарушения, невыходы, объяснительные и другие акты',
      ),
      'other': ('Прочие документы', 'Остальные документы сотрудника'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups.entries.map((entry) {
        final items = documents
            .where((item) => item.group == entry.key)
            .toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sectionTitle(entry.value.$1, subtitle: entry.value.$2),
              if (items.isEmpty)
                PremiumWorkCard(
                  radius: 20,
                  padding: const EdgeInsets.all(15),
                  child: const Text('Не загружено'),
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PremiumWorkCard(
                      radius: 20,
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.description_outlined),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          <String>[
                            if (item.documentType.isNotEmpty) item.documentType,
                            if (item.documentNumber.isNotEmpty)
                              '№ ${item.documentNumber}',
                            if (item.documentDate != null)
                              date(item.documentDate),
                            if (item.sourceLabel.isNotEmpty) item.sourceLabel,
                          ].join(' • '),
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => openDocument(item),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget personalData(LegalEmployeeDossier d) {
    final status = d.isArchived
        ? 'Архив'
        : d.isActive
        ? 'Работает'
        : 'Не работает';
    final rate = d.number('daily_rate');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle(
          'Личные данные',
          subtitle:
              'Просмотр персональных данных фиксируется в журнале доступа',
        ),
        fieldCard('Работа и контакты', [
          ('Статус', status),
          ('Должность', d.position),
          ('Объект', d.objectName),
          ('Телефон', d.phone),
          ('Гражданство', dataValue(d, 'citizenship')),
          ('Ставка', rate == null ? '' : '${money(rate)} / смена'),
          ('№ договора', dataValue(d, 'contract_number')),
          ('Начало работы', dataValue(d, 'employment_start_date')),
          ('Дата увольнения', dataValue(d, 'dismissal_date')),
        ]),
        fieldCard('Паспорт и рождение', [
          ('Дата рождения', dataValue(d, 'birth_date')),
          ('Место рождения', dataValue(d, 'birth_place')),
          ('Серия паспорта', dataValue(d, 'passport_series')),
          ('Номер паспорта', dataValue(d, 'passport_number')),
          ('Кем выдан', dataValue(d, 'passport_issued_by')),
          ('Дата выдачи', dataValue(d, 'passport_issued_date')),
          ('Код подразделения', dataValue(d, 'passport_department_code')),
        ]),
        fieldCard('Идентификаторы и адреса', [
          ('СНИЛС', dataValue(d, 'snils')),
          ('ИНН', dataValue(d, 'inn')),
          ('Регистрация', dataValue(d, 'registration_address')),
          ('Проживание', dataValue(d, 'living_address')),
        ]),
        fieldCard('Банковские реквизиты', [
          ('Банк', dataValue(d, 'bank_name')),
          ('Карта', dataValue(d, 'bank_card')),
          ('Расчётный счёт', dataValue(d, 'bank_account')),
          ('БИК', dataValue(d, 'bank_bik')),
          ('Корр. счёт', dataValue(d, 'bank_corr_account')),
          ('ИНН банка', dataValue(d, 'bank_inn')),
          ('КПП банка', dataValue(d, 'bank_kpp')),
          ('ОКПО банка', dataValue(d, 'bank_okpo')),
          ('ОГРН банка', dataValue(d, 'bank_ogrn')),
          ('SWIFT', dataValue(d, 'bank_swift')),
          ('Адрес банка', dataValue(d, 'bank_address')),
          ('Адрес отделения', dataValue(d, 'bank_office_address')),
        ]),
        fieldCard('Дополнительно', [
          ('Размер одежды', dataValue(d, 'clothes_size')),
          ('Размер обуви', dataValue(d, 'shoe_size')),
          ('Комментарий кадров', dataValue(d, 'private_comment')),
          ('Комментарий сотрудника', dataValue(d, 'employee_comment')),
        ]),
      ],
    );
  }

  Widget recoveries(List<LegalWorkspaceRecovery> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Взыскания'),
        if (items.isEmpty)
          const PremiumWorkCard(child: Text('Взысканий нет'))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PremiumWorkCard(
                radius: 20,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.payments_outlined),
                  ),
                  title: Text(
                    '${money(item.amount)} • ${date(item.absenceDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    <String>[
                      item.status == 'confirmed'
                          ? 'Подтверждено'
                          : 'Ожидает решения',
                      item.actFilePath.isEmpty ? 'нет акта' : 'акт есть',
                      item.explanationFilePath.isEmpty
                          ? 'нет объяснительной'
                          : 'объяснительная есть',
                    ].join(' • '),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget matters(List<LegalMatter> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Юридические дела'),
        if (items.isEmpty)
          const PremiumWorkCard(child: Text('Связанных дел нет'))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PremiumWorkCard(
                radius: 20,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.gavel_outlined),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${item.typeTitle} • ${item.statusTitle} • ${item.riskTitle} риск',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      AppPageRoute<void>(
                        builder: (_) => LegalMatterDetailsScreen(
                          matter: item,
                          canDecide: false,
                        ),
                      ),
                    );
                    if (mounted) await refresh();
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee.fio),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_EmployeeCompleteData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Не удалось загрузить досье: ${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return AppPage(
            title: data.dossier.fio,
            subtitle: <String>[
              if (data.dossier.position.isNotEmpty) data.dossier.position,
              if (data.dossier.objectName.isNotEmpty) data.dossier.objectName,
            ].join(' • '),
            headerTrailing: FilledButton.icon(
              onPressed: () => addDocument(data.dossier),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Документ'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                completeness(data.requirements),
                const SizedBox(height: 20),
                personalData(data.dossier),
                const SizedBox(height: 8),
                documentGroups(data.documents),
                recoveries(data.recoveries),
                matters(data.matters),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeCompleteData {
  final LegalEmployeeDossier dossier;
  final List<LegalEmployeeDossierDocument> documents;
  final List<LegalEmployeeRequirement> requirements;
  final List<LegalMatter> matters;
  final List<LegalWorkspaceRecovery> recoveries;

  const _EmployeeCompleteData({
    required this.dossier,
    required this.documents,
    required this.requirements,
    required this.matters,
    required this.recoveries,
  });
}
