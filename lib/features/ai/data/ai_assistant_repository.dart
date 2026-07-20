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
      r'документ|акт|заявлен|договор|соглас|служебн|записк|письм',
    ).hasMatch(normalized);
    return action && document;
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
      if (_isTaskCommand(normalized)) return 'ai-action-draft';
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
    final functionName = functionNameFor(
      mode: mode,
      prompt: cleanPrompt,
    );
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

    return AiAssistantResult.fromMap(data);
  }

  static String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
