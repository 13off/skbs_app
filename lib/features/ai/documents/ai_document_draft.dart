import '../../../models/employee.dart';
import '../../../models/employee_private_data.dart';
import '../models/ai_assistant_result.dart';

class AiDocumentDraft {
  final String title;
  final String body;
  final String fileBaseName;
  final List<String> missingFields;

  const AiDocumentDraft({
    required this.title,
    required this.body,
    required this.fileBaseName,
    required this.missingFields,
  });
}

class AiDocumentDraftBuilder {
  AiDocumentDraftBuilder._();

  static AiDocumentDraft build({
    required AiAssistantAction action,
    required String companyName,
    Employee? employee,
    EmployeePrivateData? privateData,
  }) {
    final kind = action.text('document_kind');
    final title = action.text('title').isNotEmpty
        ? action.text('title')
        : _titleFor(kind);
    final objectName = _value(action.text('object_name'), 'указать объект');
    final date = _formatDate(action.text('date'));
    final prompt = action.text('source_prompt');
    final name = _value(employee?.name ?? action.text('employee_name'), 'указать ФИО');
    final position = _value(employee?.position ?? '', 'указать должность');
    final company = _value(companyName, 'указать организацию');
    final private = privateData ?? EmployeePrivateData.empty(employee?.id ?? '');
    final missing = <String>[];

    String requiredValue(String value, String field) {
      final clean = value.trim();
      if (clean.isNotEmpty) return clean;
      missing.add(field);
      return '[указать $field]';
    }

    final body = switch (kind) {
      'job_application' => _jobApplication(
          company: company,
          name: name,
          position: position,
          startDate: requiredValue(private.employmentStartDate, 'дату начала работы'),
          date: date,
        ),
      'salary_transfer_application' => _salaryApplication(
          company: company,
          name: name,
          bankName: requiredValue(private.bankName, 'наименование банка'),
          account: requiredValue(private.bankAccount, 'номер счёта'),
          bik: requiredValue(private.bankBik, 'БИК'),
          card: private.bankCard.trim(),
          date: date,
        ),
      'personal_data_consent' => _personalDataConsent(
          company: company,
          name: name,
          passport: requiredValue(private.passportFull, 'паспортные данные'),
          address: requiredValue(
            private.registrationAddress,
            'адрес регистрации',
          ),
          date: date,
        ),
      'employment_contract' => _employmentContract(
          company: company,
          name: name,
          passport: requiredValue(private.passportFull, 'паспортные данные'),
          position: position,
          objectName: objectName,
          startDate: requiredValue(private.employmentStartDate, 'дату начала работы'),
          rate: employee == null || employee.dailyRate <= 0
              ? requiredValue('', 'ставку и порядок оплаты')
              : '${employee.dailyRate} руб. за смену',
          date: date,
        ),
      'service_memo' => _serviceMemo(
          company: company,
          author: name,
          objectName: objectName,
          prompt: prompt,
          date: date,
        ),
      'work_act' => _workAct(
          company: company,
          objectName: objectName,
          prompt: prompt,
          date: date,
        ),
      'letter' => _letter(
          company: company,
          author: name,
          prompt: prompt,
          date: date,
        ),
      _ => _genericDocument(
          title: title,
          company: company,
          employeeName: name,
          objectName: objectName,
          prompt: prompt,
          date: date,
        ),
    };

    return AiDocumentDraft(
      title: title,
      body: body,
      fileBaseName: _safeFileName('${title}_${employee?.name ?? date}'),
      missingFields: List<String>.unmodifiable(missing.toSet()),
    );
  }

  static String _titleFor(String kind) {
    return switch (kind) {
      'job_application' => 'Заявление о приёме на работу',
      'salary_transfer_application' =>
        'Заявление о перечислении заработной платы',
      'personal_data_consent' =>
        'Согласие на обработку персональных данных',
      'employment_contract' => 'Черновик трудового договора',
      'service_memo' => 'Служебная записка',
      'work_act' => 'Черновик акта',
      'letter' => 'Рабочее письмо',
      _ => 'Рабочий документ',
    };
  }

  static String _value(String value, String placeholder) {
    final clean = value.trim();
    return clean.isEmpty ? '[$placeholder]' : clean;
  }

  static String _formatDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return value.trim().isEmpty ? '[указать дату]' : value.trim();
    return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
  }

  static String _safeFileName(String value) {
    final result = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return result.isEmpty ? 'document' : result;
  }

  static String _header(String title) =>
      'ЧЕРНОВИК — ТРЕБУЕТ ПРОВЕРКИ\n\n$title\n\n';

  static String _jobApplication({
    required String company,
    required String name,
    required String position,
    required String startDate,
    required String date,
  }) {
    return '${_header('ЗАЯВЛЕНИЕ')}Руководителю $company\n'
        'от $name\n\n'
        'Прошу принять меня на работу на должность «$position» с $startDate.\n\n'
        'Дата: $date\n\n'
        'Подпись: __________________ / $name /';
  }

  static String _salaryApplication({
    required String company,
    required String name,
    required String bankName,
    required String account,
    required String bik,
    required String card,
    required String date,
  }) {
    final cardLine = card.trim().isEmpty ? '' : '\nНомер карты: $card';
    return '${_header('ЗАЯВЛЕНИЕ')}Руководителю $company\n'
        'от $name\n\n'
        'Прошу перечислять причитающуюся мне заработную плату по следующим банковским реквизитам:\n\n'
        'Банк: $bankName\n'
        'Счёт: $account\n'
        'БИК: $bik$cardLine\n\n'
        'Дата: $date\n\n'
        'Подпись: __________________ / $name /';
  }

  static String _personalDataConsent({
    required String company,
    required String name,
    required String passport,
    required String address,
    required String date,
  }) {
    return '${_header('СОГЛАСИЕ НА ОБРАБОТКУ ПЕРСОНАЛЬНЫХ ДАННЫХ')}'
        'Я, $name, паспорт: $passport, зарегистрированный(ая) по адресу: $address, '
        'даю $company согласие на обработку моих персональных данных в целях оформления и исполнения трудовых отношений, кадрового, бухгалтерского и налогового учёта.\n\n'
        'Согласие распространяется на данные, необходимые для указанных целей, и действует до прекращения оснований обработки либо его отзыва в предусмотренном законом порядке.\n\n'
        'Дата: $date\n\n'
        'Подпись: __________________ / $name /';
  }

  static String _employmentContract({
    required String company,
    required String name,
    required String passport,
    required String position,
    required String objectName,
    required String startDate,
    required String rate,
    required String date,
  }) {
    return '${_header('ТРУДОВОЙ ДОГОВОР — ЧЕРНОВИК ИСХОДНЫХ ДАННЫХ')}'
        'Организация: $company\n'
        'Работник: $name\n'
        'Паспорт: $passport\n'
        'Должность: $position\n'
        'Место работы / объект: $objectName\n'
        'Дата начала работы: $startDate\n'
        'Оплата: $rate\n\n'
        '1. Работодатель предоставляет Работнику работу по указанной должности, а Работник обязуется лично выполнять трудовую функцию и соблюдать действующие правила.\n\n'
        '2. Режим работы, условия труда, гарантии, компенсации, порядок оплаты, ответственность сторон и основания прекращения договора должны быть проверены и дополнены ответственным сотрудником.\n\n'
        'Дата подготовки черновика: $date\n\n'
        'Работодатель: __________________\n\n'
        'Работник: __________________ / $name /';
  }

  static String _serviceMemo({
    required String company,
    required String author,
    required String objectName,
    required String prompt,
    required String date,
  }) {
    return '${_header('СЛУЖЕБНАЯ ЗАПИСКА')}'
        'Организация: $company\n'
        'Объект: $objectName\n'
        'Автор: $author\n'
        'Дата: $date\n\n'
        'Тема: [указать тему]\n\n'
        '${_value(prompt, 'описать обстоятельства и требуемое решение')}\n\n'
        'Прошу: [указать требуемое решение]\n\n'
        'Подпись: __________________ / $author /';
  }

  static String _workAct({
    required String company,
    required String objectName,
    required String prompt,
    required String date,
  }) {
    return '${_header('АКТ — ЧЕРНОВИК')}'
        'Организация: $company\n'
        'Объект: $objectName\n'
        'Дата: $date\n\n'
        'Описание выполненных работ:\n'
        '${_value(prompt, 'перечислить выполненные работы, объёмы и оси')}\n\n'
        'Замечания: [указать при наличии]\n\n'
        'Сдал: __________________\n\n'
        'Принял: __________________';
  }

  static String _letter({
    required String company,
    required String author,
    required String prompt,
    required String date,
  }) {
    return '${_header('РАБОЧЕЕ ПИСЬМО')}'
        'От: $company\n'
        'Автор: $author\n'
        'Дата: $date\n\n'
        'Кому: [указать получателя]\n'
        'Тема: [указать тему]\n\n'
        '${_value(prompt, 'ввести текст письма')}\n\n'
        'С уважением,\n$author';
  }

  static String _genericDocument({
    required String title,
    required String company,
    required String employeeName,
    required String objectName,
    required String prompt,
    required String date,
  }) {
    return '${_header(title.toUpperCase())}'
        'Организация: $company\n'
        'Сотрудник: $employeeName\n'
        'Объект: $objectName\n'
        'Дата: $date\n\n'
        '${_value(prompt, 'ввести содержание документа')}\n\n'
        'Подпись: __________________';
  }
}
