import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_assistant_result.dart';

class AiAssistantRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _normalized(String prompt) =>
      prompt.trim().toLowerCase().replaceAll('ё', 'е');

  static bool _isOperationalInsight(String normalized) {
    final absence =
        RegExp(
          r'(кто|кого|сотрудник).*(не выш|не явил|отсутств|нет на работ)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(не выш|не явил|отсутств).*(сотрудник|сегодня|объект)',
        ).hasMatch(normalized);
    final unpaid =
        RegExp(
          r'(кому|у кого|кто).*(не выплат|не доплат|должн|долг|остаток|задолж)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(долг|задолж|остаток).*(выплат|зарплат|сотрудник)',
        ).hasMatch(normalized);
    final expiringDocuments =
        RegExp(
          r'(документ|договор|удостоверен|медосмотр|патент).*(заканч|истека|просроч|срок)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(заканч|истека|просроч).*(документ|договор|удостоверен|медосмотр|патент)',
        ).hasMatch(normalized);
    final weeklyReport =
        RegExp(r'(сводк|отчет|итог).*(недел|7 дн)').hasMatch(normalized) ||
        RegExp(r'(недел|7 дн).*(сводк|отчет|итог)').hasMatch(normalized);
    return absence || unpaid || expiringDocuments || weeklyReport;
  }

  static bool _isTaskCommand(String normalized) {
    return RegExp(
      r'(созда|добав|постав|назнач|сдел).*(задач|работ|армирован|бетонир|монтаж|демонтаж)',
    ).hasMatch(normalized);
  }

  static bool _isDocumentCommand(String normalized) {
    final action = RegExp(
      r'подготов|состав|напиш|созда|сдел|сформир',
    ).hasMatch(normalized);
    final document = RegExp(
      r'документ|заявлен|договор|соглас|служебн|записк|письм',
    ).hasMatch(normalized);
    return action && document;
  }

  static bool _isCandidatePackage(String normalized) {
    return RegExp(
          r'(пакет|комплект).*(документ).*(кандидат|соискател)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(подготов|собер|проверь).*(документ).*(кандидат|соискател)',
        ).hasMatch(normalized);
  }

  static bool _isWorkAct(String normalized) {
    return RegExp(
      r'(сформир|подготов|созда|сдел).*(акт).*(выполн|работ|задач)',
    ).hasMatch(normalized);
  }

  static bool _isTimesheetAudit(String normalized) {
    return RegExp(
          r'(найд|покаж|проверь|есть ли).*(расхожд|ошиб|проблем|пропуск|пуст).*(табел|смен)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(расхожд|ошиб|проблем|пропуск|пуст).*(табел|смен)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(кому|у кого).*(нет|не хватает|нул).*(смен|табел)',
        ).hasMatch(normalized);
  }

  static bool _isOperationalAudit(String normalized) {
    return RegExp(
          r'(единый|общий|операционн).*(аудит|контрол|проверк).*(табел|смен|выплат|чек)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(проверь|сверь|найди).*(табел|смен).*(выплат|чек)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(проверь|сверь|найди).*(выплат|чек).*(табел|смен)',
        ).hasMatch(normalized);
  }

  static bool _isOperationalCommand(String normalized) {
    final reminder = RegExp(r'напомн|напоминан').hasMatch(normalized);
    final timesheetCorrection =
        RegExp(
          r'(исправ|измен|поправ|постав|отмет).*(табел|смен)',
        ).hasMatch(normalized) ||
        RegExp(
          r'(табел|смен).*(исправ|измен|поправ|постав|отмет)',
        ).hasMatch(normalized);
    final employeeUpdate = RegExp(
      r'(измен|обнов|постав).*(ставк|должност|телефон)',
    ).hasMatch(normalized);
    final employeeCreate = RegExp(
      r'(добав|созда|оформ).*(сотрудник|работник|человек)',
    ).hasMatch(normalized);
    final payment = RegExp(
      r'(подготов|добав|созда|провед|внес).*(выплат|аванс|зарплат|штраф)',
    ).hasMatch(normalized);
    final missingReceipts =
        RegExp(
          r'(найд|покаж|проверь|какие).*(чек).*(нет|отсутств|не прикреп|без)',
        ).hasMatch(normalized) ||
        RegExp(r'(нет|отсутств|без).*(чек)').hasMatch(normalized);
    final periodTimesheet = RegExp(
      r'(открой|покаж|собер|сформир).*(месячн|за месяц|период).*(табел)',
    ).hasMatch(normalized);
    return reminder ||
        timesheetCorrection ||
        _isTimesheetAudit(normalized) ||
        _isOperationalAudit(normalized) ||
        employeeUpdate ||
        employeeCreate ||
        payment ||
        missingReceipts ||
        periodTimesheet ||
        _isWorkAct(normalized) ||
        _isCandidatePackage(normalized);
  }

  static bool _useStructuredAssistant({
    required String mode,
    required String prompt,
  }) {
    if (mode.trim() != 'chat') return true;

    final normalized = _normalized(prompt);
    return RegExp(r'табел|смен|выход|отработ|сводк').hasMatch(normalized);
  }

  static String functionNameFor({
    required String mode,
    required String prompt,
  }) {
    if (mode.trim() == 'chat') {
      final normalized = _normalized(prompt);
      if (_isOperationalInsight(normalized)) {
        return 'ai-operational-insights';
      }
      if (_isTaskCommand(normalized)) return 'ai-action-draft';
      if (_isDocumentCommand(normalized) &&
          !_isCandidatePackage(normalized) &&
          !_isWorkAct(normalized)) {
        return 'ai-document-draft';
      }
      if (_isOperationalCommand(normalized)) return 'ai-operational-draft';
      if (_isDocumentCommand(normalized)) return 'ai-document-draft';
    }
    return _useStructuredAssistant(mode: mode, prompt: prompt)
        ? 'ai-assistant'
        : 'ai-search';
  }

  static Future<AiAssistantResult> request({
    required String mode,
    required String companyId,
    required String prompt,
    String? objectName,
    DateTime? date,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) {
      throw Exception('Не выбрана активная компания');
    }

    final cleanPrompt = prompt.trim();
    final functionName = functionNameFor(mode: mode, prompt: cleanPrompt);
    final requestDate = date ?? DateTime.now();
    final response = await _client.functions.invoke(
      functionName,
      body: <String, dynamic>{
        'mode': mode.trim(),
        'company_id': cleanCompanyId,
        'object_name': objectName?.trim(),
        'date': _dateKey(requestDate),
        'prompt': cleanPrompt,
      },
    );
    final data = _map(response.data);
    final error = data['error']?.toString().trim() ?? '';

    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(
        error.isNotEmpty ? error : 'ИИ-помощник временно недоступен',
      );
    }

    final result = AiAssistantResult.fromMap(data);
    final action = result.action;
    if (action != null && action.id.trim().isNotEmpty) {
      try {
        await _client.rpc<void>(
          'create_ai_draft_ready_notification',
          params: <String, dynamic>{
            'p_title': result.title,
            'p_action_type': action.type,
            'p_action_id': action.id,
          },
        );
      } catch (_) {
        // Черновик остаётся доступен в чате при временной ошибке уведомления.
      }
    }

    return result;
  }

  static String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
