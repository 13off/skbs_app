import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_employee_dossier_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';
import 'legal_matters_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalEmployeeDossierScreen extends StatefulWidget {
  final LegalWorkspaceEmployee employee;

  const LegalEmployeeDossierScreen({super.key, required this.employee});

  @override
  State<LegalEmployeeDossierScreen> createState() =>
      _LegalEmployeeDossierScreenState();
}

class _LegalEmployeeDossierScreenState
    extends State<LegalEmployeeDossierScreen> {
  late Future<_EmployeeDossierBundle> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_EmployeeDossierBundle> load() async {
    final values = await Future.wait<dynamic>([
      LegalEmployeeDossierRepository.fetchDossier(widget.employee.id),
      LegalEmployeeDossierRepository.fetchDocuments(widget.employee.id),
      LegalRepository.fetchMatters(),
      LegalWorkspaceRepository.fetchRecoveries(),
    ]);
    return _EmployeeDossierBundle(
      dossier: values[0] as LegalEmployeeDossier,
      documents: values[1] as List<LegalEmployeeDossierDocument>,
      matters: (values[2] as List<LegalMatter>)
          .where((item) => item.employeeId == widget.employee.id)
          .toList(growable: false),
      recoveries: (values[3] as List<LegalWorkspaceRecovery>)
          .where((item) => item.employeeId == widget.employee.id)
          .toList(growable: false),
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
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
      buffer.write(raw[index]);
    }
    return '${buffer.toString()} ₽';
  }

  String documentStatus(String value) {
    return switch (value.trim().toLowerCase()) {
      'draft' => 'Черновик',
      'review' => 'На проверке',
      'pending' => 'Ожидает',
      'generated' => 'Сформирован',
      'printed' => 'Распечатан',
      'signed' => 'Подписан',
      'verified' => 'Проверен',
      'approved' => 'Согласован',
      'active' => 'Действует',
      'confirmed' => 'Подтверждено',
      'cancelled' => 'Отменено',
      final raw when raw.isEmpty => '',
      final raw => raw,
    };
  }

  Future<void> openDocument(LegalEmployeeDossierDocument item) async {
    try {
      if (item.legalDocumentId.isNotEmpty) {
        final document = await LegalRepository.fetchDocument(
          item.legalDocumentId,
        );
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          AppPageRoute<void>(
            builder: (_) => LegalDocumentDetailsScreen(document: document),
          ),
        );
        return;
      }
      if (item.hasStoredFile) {
        await LegalWorkspaceRepository.openStoredFile(
          bucketName: item.bucketName,
          storagePath: item.storagePath,
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл этого документа ещё не прикреплён')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть документ: $error')),
      );
    }
  }

  Future<void> openMatter(LegalMatter matter) async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) =>
            LegalMatterDetailsScreen(matter: matter, canDecide: false),
      ),
    );
    if (mounted) await refresh();
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
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget emptyCard(String text) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget dataCard(
    String title,
    LegalEmployeeDossier dossier,
    List<_DossierField> fields,
  ) {
    final rows = <Widget>[];
    for (final field in fields) {
      final value = field.resolve(dossier);
      if (value.trim().isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 152,
                child: Text(
                  field.label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget personalData(LegalEmployeeDossier dossier) {
    String activeStatus(LegalEmployeeDossier value) {
      if (value.isArchived) return 'Архив';
      return value.isActive ? 'Работает' : 'Не работает';
    }

    String consent(LegalEmployeeDossier value) {
      final flag = value.boolean('consent_personal_data');
      if (flag == null) return '';
      final when = date(value.dateTime('consented_at'));
      return flag ? 'Получено${when.isEmpty ? '' : ' • $when'}' : 'Не получено';
    }

    String rate(LegalEmployeeDossier value) {
      final amount = value.number('daily_rate');
      return amount == null ? '' : '${money(amount)} / смена';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle(
          'Личные данные',
          subtitle:
              'Данные из кадровой карточки сотрудника. Просмотр фиксируется в журнале доступа.',
        ),
        dataCard('Работа и контакты', dossier, [
          _DossierField.custom('Статус', activeStatus),
          _DossierField.key('Должность', 'position'),
          _DossierField.key('Объект', 'object_name'),
          _DossierField.key('Телефон', 'phone'),
          _DossierField.key('Гражданство', 'citizenship'),
          _DossierField.custom('Ставка', rate),
          _DossierField.key('№ договора', 'contract_number'),
          _DossierField.key('Начало работы', 'employment_start_date'),
          _DossierField.key('Дата увольнения', 'dismissal_date'),
          _DossierField.custom('Согласие на ПД', consent),
        ]),
        dataCard('Паспорт и рождение', dossier, const [
          _DossierField.key('Дата рождения', 'birth_date'),
          _DossierField.key('Место рождения', 'birth_place'),
          _DossierField.key('Серия паспорта', 'passport_series'),
          _DossierField.key('Номер паспорта', 'passport_number'),
          _DossierField.key('Кем выдан', 'passport_issued_by'),
          _DossierField.key('Дата выдачи', 'passport_issued_date'),
          _DossierField.key('Код подразделения', 'passport_department_code'),
        ]),
        dataCard('Идентификаторы и адреса', dossier, const [
          _DossierField.key('СНИЛС', 'snils'),
          _DossierField.key('ИНН', 'inn'),
          _DossierField.key('Регистрация', 'registration_address'),
          _DossierField.key('Адрес проживания', 'living_address'),
        ]),
        dataCard('Банковские реквизиты', dossier, const [
          _DossierField.key('Банк', 'bank_name'),
          _DossierField.key('Карта', 'bank_card'),
          _DossierField.key('Расчётный счёт', 'bank_account'),
          _DossierField.key('БИК', 'bank_bik'),
          _DossierField.key('Корр. счёт', 'bank_corr_account'),
          _DossierField.key('ИНН банка', 'bank_inn'),
          _DossierField.key('КПП банка', 'bank_kpp'),
          _DossierField.key('ОКПО банка', 'bank_okpo'),
          _DossierField.key('ОГРН банка', 'bank_ogrn'),
          _DossierField.key('SWIFT', 'bank_swift'),
          _DossierField.key('Адрес банка', 'bank_address'),
          _DossierField.key('Адрес отделения', 'bank_office_address'),
        ]),
        dataCard('Дополнительно', dossier, const [
          _DossierField.key('Размер одежды', 'clothes_size'),
          _DossierField.key('Размер обуви', 'shoe_size'),
          _DossierField.key('Комментарий кадров', 'private_comment'),
          _DossierField.key('Комментарий сотрудника', 'employee_comment'),
        ]),
      ],
    );
  }

  Widget documentCard(LegalEmployeeDossierDocument item) {
    final meta = <String>[
      if (item.documentType.isNotEmpty) item.documentType,
      if (item.documentNumber.isNotEmpty) '№ ${item.documentNumber}',
      if (item.documentDate != null) date(item.documentDate),
      if (documentStatus(item.status).isNotEmpty) documentStatus(item.status),
      if (item.validFrom != null) 'с ${date(item.validFrom)}',
      if (item.expiresOn != null) 'до ${date(item.expiresOn)}',
      if (item.sourceLabel.isNotEmpty) item.sourceLabel,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumWorkCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 7,
          ),
          leading: CircleAvatar(
            child: Icon(switch (item.group) {
              'contract' => Icons.handshake_outlined,
              'application_consent' => Icons.edit_document,
              'personal_document' => Icons.badge_outlined,
              'act_explanation' => Icons.fact_check_outlined,
              _ => Icons.description_outlined,
            }),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(meta.isEmpty ? 'Документ' : meta.join(' • ')),
          trailing: Icon(
            item.hasStoredFile || item.legalDocumentId.isNotEmpty
                ? Icons.open_in_new_rounded
                : Icons.info_outline_rounded,
          ),
          onTap: () => openDocument(item),
        ),
      ),
    );
  }

  Widget documentSection(
    String title,
    String subtitle,
    List<LegalEmployeeDossierDocument> documents,
    String emptyText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle(title, subtitle: subtitle),
        if (documents.isEmpty)
          emptyCard(emptyText)
        else
          ...documents.map(documentCard),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget recoveries(List<LegalWorkspaceRecovery> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle(
          'Взыскания',
          subtitle: 'Только ожидающие решения и подтверждённые взыскания',
        ),
        if (items.isEmpty)
          emptyCard('Взысканий нет')
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
                          ? 'Подтверждено руководителем'
                          : 'Ожидает решения руководителя',
                      if (item.actFilePath.isNotEmpty) 'акт приложен',
                      if (item.explanationFilePath.isNotEmpty)
                        'объяснительная приложена',
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
          emptyCard('Связанных юридических дел нет')
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
                    <String>[
                      item.typeTitle,
                      item.statusTitle,
                      item.riskTitle,
                      if (item.dueAt != null) 'срок ${date(item.dueAt)}',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openMatter(item),
                ),
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.employee.fio),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_EmployeeDossierBundle>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return AppPage(
                title: widget.employee.fio,
                child: PremiumWorkCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Не удалось загрузить досье: ${snapshot.error}',
                    ),
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final dossier = data.dossier;
          final contracts = data.documents
              .where((item) => item.group == 'contract')
              .toList();
          final applications = data.documents
              .where((item) => item.group == 'application_consent')
              .toList();
          final personal = data.documents
              .where((item) => item.group == 'personal_document')
              .toList();
          final acts = data.documents
              .where((item) => item.group == 'act_explanation')
              .toList();
          final other = data.documents
              .where((item) => item.group == 'other')
              .toList();

          return AppPage(
            title: dossier.fio,
            subtitle: <String>[
              if (dossier.position.isNotEmpty) dossier.position,
              if (dossier.objectName.isNotEmpty) dossier.objectName,
              dossier.isArchived
                  ? 'Архив'
                  : dossier.isActive
                  ? 'Работает'
                  : 'Не работает',
            ].join(' • '),
            headerTrailing: FilledButton.icon(
              onPressed: () => addDocument(dossier),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Добавить документ'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                personalData(dossier),
                const SizedBox(height: 4),
                documentSection(
                  'Договоры',
                  'Трудовые, ГПХ, оказание услуг, подряд и другие договоры сотрудника',
                  contracts,
                  'Договоры не загружены. Трудовой, ГПХ и другие договоры появятся здесь после привязки к сотруднику.',
                ),
                documentSection(
                  'Заявления и согласия',
                  'Приём на работу, перечисление зарплаты, персональные данные и другие заявления/согласия',
                  applications,
                  'Заявления и согласия пока не загружены.',
                ),
                documentSection(
                  'Личные документы',
                  'Паспорт, регистрация, СНИЛС, ИНН, полис, фото и другие личные документы',
                  personal,
                  'Файлы личных документов пока не загружены. Реквизиты, которые есть в базе, показаны выше.',
                ),
                documentSection(
                  'Акты и объяснительные',
                  'Акты нарушений/невыходов и объяснительные сотрудника',
                  acts,
                  'Актов и объяснительных пока нет.',
                ),
                recoveries(data.recoveries),
                matters(data.matters),
                if (other.isNotEmpty)
                  documentSection(
                    'Прочие документы',
                    'Все остальные документы, привязанные к сотруднику',
                    other,
                    'Прочих документов нет.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeDossierBundle {
  final LegalEmployeeDossier dossier;
  final List<LegalEmployeeDossierDocument> documents;
  final List<LegalMatter> matters;
  final List<LegalWorkspaceRecovery> recoveries;

  const _EmployeeDossierBundle({
    required this.dossier,
    required this.documents,
    required this.matters,
    required this.recoveries,
  });
}

class _DossierField {
  final String label;
  final String? key;
  final String Function(LegalEmployeeDossier dossier)? resolver;

  const _DossierField.key(this.label, this.key) : resolver = null;

  const _DossierField.custom(this.label, this.resolver) : key = null;

  String resolve(LegalEmployeeDossier dossier) {
    final custom = resolver;
    if (custom != null) return custom(dossier);
    return dossier.text(key ?? '');
  }
}
