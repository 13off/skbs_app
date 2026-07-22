import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/company_compliance_repository.dart';
import '../models/company_compliance_models.dart';

class CompanyComplianceScreen extends StatefulWidget {
  final AppUserProfile profile;

  const CompanyComplianceScreen({super.key, required this.profile});

  @override
  State<CompanyComplianceScreen> createState() =>
      _CompanyComplianceScreenState();
}

class _CompanyComplianceScreenState extends State<CompanyComplianceScreen> {
  final Map<String, TextEditingController> fields =
      <String, TextEditingController>{};
  bool loading = true;
  bool savingEmployer = false;
  bool savingGate = false;
  bool legalApproved = false;
  DateTime? legalApprovedAt;
  late CompanyPersonalDataGate gate;

  static const List<String> fieldKeys = <String>[
    'legalName',
    'shortName',
    'legalAddress',
    'actualAddress',
    'inn',
    'kpp',
    'ogrn',
    'bankName',
    'bankAccount',
    'bankBik',
    'bankCorrAccount',
    'representativeName',
    'representativePosition',
    'representativeBasis',
    'contractCity',
    'workSchedule',
    'salaryTermsTemplate',
    'retentionPolicy',
    'employerApprovedBy',
    'storageRegion',
    'retentionDays',
    'deletionPolicy',
    'incidentOwner',
    'gateApprovedBy',
  ];

  @override
  void initState() {
    super.initState();
    for (final key in fieldKeys) {
      fields[key] = TextEditingController();
    }
    gate = CompanyPersonalDataGate.empty(widget.profile.activeCompanyId);
    load();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController controller(String key) => fields[key]!;

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final snapshot = await CompanyComplianceRepository.fetchSnapshot(
        widget.profile.activeCompanyId,
      );
      final employer = snapshot.employer;
      controller('legalName').text = employer.legalName;
      controller('shortName').text = employer.shortName;
      controller('legalAddress').text = employer.legalAddress;
      controller('actualAddress').text = employer.actualAddress;
      controller('inn').text = employer.inn;
      controller('kpp').text = employer.kpp;
      controller('ogrn').text = employer.ogrn;
      controller('bankName').text = employer.bankName;
      controller('bankAccount').text = employer.bankAccount;
      controller('bankBik').text = employer.bankBik;
      controller('bankCorrAccount').text = employer.bankCorrAccount;
      controller('representativeName').text = employer.representativeName;
      controller('representativePosition').text =
          employer.representativePosition;
      controller('representativeBasis').text = employer.representativeBasis;
      controller('contractCity').text = employer.contractCity;
      controller('workSchedule').text = employer.workSchedule;
      controller('salaryTermsTemplate').text = employer.salaryTermsTemplate;
      controller('retentionPolicy').text = employer.retentionPolicy;
      controller('employerApprovedBy').text = employer.approvedByName;
      controller('storageRegion').text = snapshot.gate.storageRegion;
      controller('retentionDays').text = snapshot.gate.retentionDays == 0
          ? ''
          : snapshot.gate.retentionDays.toString();
      controller('deletionPolicy').text = snapshot.gate.deletionPolicy;
      controller('incidentOwner').text = snapshot.gate.incidentOwner;
      controller('gateApprovedBy').text = snapshot.gate.approvedByName;
      if (!mounted) return;
      setState(() {
        legalApproved = employer.legalDocumentsApproved;
        legalApprovedAt = employer.approvedAt;
        gate = snapshot.gate;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      showError(error);
    }
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }

  Future<void> saveEmployer() async {
    if (savingEmployer) return;
    setState(() => savingEmployer = true);
    try {
      final approvedBy = controller('employerApprovedBy').text.trim();
      final approvedAt = legalApproved
          ? legalApprovedAt ?? DateTime.now()
          : null;
      await CompanyComplianceRepository.saveEmployerProfile(
        companyId: widget.profile.activeCompanyId,
        legalName: controller('legalName').text,
        shortName: controller('shortName').text,
        legalAddress: controller('legalAddress').text,
        actualAddress: controller('actualAddress').text,
        inn: controller('inn').text,
        kpp: controller('kpp').text,
        ogrn: controller('ogrn').text,
        bankName: controller('bankName').text,
        bankAccount: controller('bankAccount').text,
        bankBik: controller('bankBik').text,
        bankCorrAccount: controller('bankCorrAccount').text,
        representativeName: controller('representativeName').text,
        representativePosition: controller('representativePosition').text,
        representativeBasis: controller('representativeBasis').text,
        contractCity: controller('contractCity').text,
        workSchedule: controller('workSchedule').text,
        salaryTermsTemplate: controller('salaryTermsTemplate').text,
        retentionPolicy: controller('retentionPolicy').text,
        legalDocumentsApproved: legalApproved,
        approvedByName: approvedBy,
        approvedAt: approvedAt,
      );
      if (!mounted) return;
      legalApprovedAt = approvedAt;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль работодателя сохранён')),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => savingEmployer = false);
    }
  }

  CompanyPersonalDataGate currentGate() {
    return CompanyPersonalDataGate(
      companyId: widget.profile.activeCompanyId,
      realDocumentsEnabled: gate.realDocumentsEnabled,
      russianStorageLocationConfirmed: gate.russianStorageLocationConfirmed,
      dataControllerDetailsApproved: gate.dataControllerDetailsApproved,
      personalDataConsentApproved: gate.personalDataConsentApproved,
      retentionAndDeletionPolicyApproved:
          gate.retentionAndDeletionPolicyApproved,
      downloadAuditLogVerified: gate.downloadAuditLogVerified,
      backupAndRestoreTested: gate.backupAndRestoreTested,
      accessOffboardingTested: gate.accessOffboardingTested,
      incidentResponseOwnerAssigned: gate.incidentResponseOwnerAssigned,
      storageRegion: controller('storageRegion').text,
      retentionDays: int.tryParse(controller('retentionDays').text.trim()) ?? 0,
      deletionPolicy: controller('deletionPolicy').text,
      incidentOwner: controller('incidentOwner').text,
      approvedByName: controller('gateApprovedBy').text,
      approvedAt: gate.realDocumentsEnabled
          ? gate.approvedAt ?? DateTime.now()
          : gate.approvedAt,
    );
  }

  Future<void> saveGate() async {
    if (savingGate) return;
    setState(() => savingGate = true);
    try {
      final saved = await CompanyComplianceRepository.saveGate(
        gate: currentGate(),
      );
      if (!mounted) return;
      setState(() => gate = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.realDocumentsEnabled
                ? 'Production gate открыт'
                : 'Production gate сохранён и остаётся закрытым',
          ),
        ),
      );
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => savingGate = false);
    }
  }

  Widget textField(
    String key,
    String label, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller(key),
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget employerCard() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
            'Профиль работодателя',
            'Эти данные используются в согласии и трудовом договоре. Пустые значения не выдумываются.',
          ),
          textField('legalName', 'Полное юридическое наименование'),
          textField('shortName', 'Краткое наименование'),
          textField(
            'legalAddress',
            'Юридический адрес',
            minLines: 2,
            maxLines: 3,
          ),
          textField(
            'actualAddress',
            'Фактический адрес',
            minLines: 2,
            maxLines: 3,
          ),
          Row(
            children: [
              Expanded(child: textField('inn', 'ИНН')),
              const SizedBox(width: 10),
              Expanded(child: textField('kpp', 'КПП')),
            ],
          ),
          textField('ogrn', 'ОГРН'),
          textField('bankName', 'Банк работодателя'),
          textField('bankAccount', 'Расчётный счёт'),
          Row(
            children: [
              Expanded(child: textField('bankBik', 'БИК')),
              const SizedBox(width: 10),
              Expanded(child: textField('bankCorrAccount', 'Корр. счёт')),
            ],
          ),
          textField('representativeName', 'ФИО представителя работодателя'),
          textField('representativePosition', 'Должность представителя'),
          textField('representativeBasis', 'Основание полномочий'),
          textField('contractCity', 'Город заключения договора'),
          textField(
            'workSchedule',
            'Стандартный режим работы',
            minLines: 2,
            maxLines: 4,
          ),
          textField(
            'salaryTermsTemplate',
            'Стандартные условия оплаты',
            minLines: 2,
            maxLines: 4,
          ),
          textField(
            'retentionPolicy',
            'Утверждённый порядок хранения документов',
            minLines: 3,
            maxLines: 6,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Юридические формы утверждены',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Включать только после проверки согласия и трудового договора юристом.',
            ),
            value: legalApproved,
            onChanged: (value) => setState(() {
              legalApproved = value;
              legalApprovedAt = value ? DateTime.now() : null;
            }),
          ),
          textField('employerApprovedBy', 'Кто утвердил юридические формы'),
          FilledButton.icon(
            onPressed: savingEmployer ? null : saveEmployer,
            icon: savingEmployer
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Сохранить профиль работодателя'),
          ),
        ],
      ),
    );
  }

  void updateGate(CompanyPersonalDataGate next) => setState(() => gate = next);

  CompanyPersonalDataGate gateWith({
    bool? realDocumentsEnabled,
    bool? russianStorageLocationConfirmed,
    bool? dataControllerDetailsApproved,
    bool? personalDataConsentApproved,
    bool? retentionAndDeletionPolicyApproved,
    bool? downloadAuditLogVerified,
    bool? backupAndRestoreTested,
    bool? accessOffboardingTested,
    bool? incidentResponseOwnerAssigned,
  }) {
    return CompanyPersonalDataGate(
      companyId: gate.companyId,
      realDocumentsEnabled: realDocumentsEnabled ?? gate.realDocumentsEnabled,
      russianStorageLocationConfirmed:
          russianStorageLocationConfirmed ??
          gate.russianStorageLocationConfirmed,
      dataControllerDetailsApproved:
          dataControllerDetailsApproved ?? gate.dataControllerDetailsApproved,
      personalDataConsentApproved:
          personalDataConsentApproved ?? gate.personalDataConsentApproved,
      retentionAndDeletionPolicyApproved:
          retentionAndDeletionPolicyApproved ??
          gate.retentionAndDeletionPolicyApproved,
      downloadAuditLogVerified:
          downloadAuditLogVerified ?? gate.downloadAuditLogVerified,
      backupAndRestoreTested:
          backupAndRestoreTested ?? gate.backupAndRestoreTested,
      accessOffboardingTested:
          accessOffboardingTested ?? gate.accessOffboardingTested,
      incidentResponseOwnerAssigned:
          incidentResponseOwnerAssigned ?? gate.incidentResponseOwnerAssigned,
      storageRegion: gate.storageRegion,
      retentionDays: gate.retentionDays,
      deletionPolicy: gate.deletionPolicy,
      incidentOwner: gate.incidentOwner,
      approvedByName: gate.approvedByName,
      approvedAt: gate.approvedAt,
    );
  }

  Widget evidenceSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget gateCard() {
    final current = currentGate();
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
            'Production gate персональных данных',
            'Сервер не позволит открыть реальные документы, пока не закрыты все пункты и не утверждён профиль работодателя.',
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gate.realDocumentsEnabled
                  ? const Color(0xFFE7F4EC)
                  : const Color(0xFFFFF3DE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              gate.realDocumentsEnabled
                  ? 'ОТКРЫТО: реальные документы разрешены сервером'
                  : 'ЗАКРЫТО: разрешены только тестовые и обезличенные записи',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          evidenceSwitch(
            'Российское хранение подтверждено',
            'Есть документальное подтверждение региона хранения.',
            gate.russianStorageLocationConfirmed,
            (value) =>
                updateGate(gateWith(russianStorageLocationConfirmed: value)),
          ),
          evidenceSwitch(
            'Реквизиты оператора утверждены',
            'Определены оператор, адрес и ответственные лица.',
            gate.dataControllerDetailsApproved,
            (value) =>
                updateGate(gateWith(dataControllerDetailsApproved: value)),
          ),
          evidenceSwitch(
            'Согласие утверждено',
            'Юрист утвердил актуальный текст согласия.',
            gate.personalDataConsentApproved,
            (value) => updateGate(gateWith(personalDataConsentApproved: value)),
          ),
          evidenceSwitch(
            'Сроки хранения и удаление утверждены',
            'Есть формализованный срок и порядок удаления.',
            gate.retentionAndDeletionPolicyApproved,
            (value) =>
                updateGate(gateWith(retentionAndDeletionPolicyApproved: value)),
          ),
          evidenceSwitch(
            'Журнал доступа проверен',
            'Генерация, просмотр, загрузка и скачивание фиксируются.',
            gate.downloadAuditLogVerified,
            (value) => updateGate(gateWith(downloadAuditLogVerified: value)),
          ),
          evidenceSwitch(
            'Backup/restore протестирован',
            'Есть успешная проверка восстановления данных.',
            gate.backupAndRestoreTested,
            (value) => updateGate(gateWith(backupAndRestoreTested: value)),
          ),
          evidenceSwitch(
            'Отзыв доступа протестирован',
            'Доступ бывшего сотрудника реально отзывается.',
            gate.accessOffboardingTested,
            (value) => updateGate(gateWith(accessOffboardingTested: value)),
          ),
          evidenceSwitch(
            'Ответственный за инциденты назначен',
            'Назначен человек, который принимает и ведёт инциденты.',
            gate.incidentResponseOwnerAssigned,
            (value) =>
                updateGate(gateWith(incidentResponseOwnerAssigned: value)),
          ),
          textField('storageRegion', 'Регион и провайдер хранения'),
          textField(
            'retentionDays',
            'Срок хранения, дней',
            keyboardType: TextInputType.number,
          ),
          textField(
            'deletionPolicy',
            'Порядок удаления',
            minLines: 3,
            maxLines: 6,
          ),
          textField('incidentOwner', 'Ответственный за инциденты'),
          textField('gateApprovedBy', 'Кто разрешил production-использование'),
          const SizedBox(height: 4),
          Text(
            'Закрыто доказательств: ${current.completedEvidenceCount}/8',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Разрешить реальные персональные документы',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Даже включённый переключатель не сохранится, если сервер найдёт незакрытый пункт.',
            ),
            value: gate.realDocumentsEnabled,
            onChanged: (value) =>
                updateGate(gateWith(realDocumentsEnabled: value)),
          ),
          FilledButton.icon(
            onPressed: savingGate ? null : saveGate,
            icon: savingGate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: const Text('Сохранить production gate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Работодатель и персональные данные',
      showBackButton: true,
      subtitle: 'Юридические реквизиты, доказательства и серверный gate',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                employerCard(),
                const SizedBox(height: 14),
                gateCard(),
                const SizedBox(height: 12),
                const Text(
                  'Все изменения gate записываются в отдельный журнал. Реальные реквизиты не подставляются автоматически и должны быть подтверждены ответственным лицом.',
                  style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }
}
