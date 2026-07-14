import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_assistant_result.dart';

class AiAssistantRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static bool _useStructuredAssistant({
    required String mode,
    required String prompt,
  }) {
    if (mode.trim() != 'chat') return true;

    final normalized = prompt.trim().toLowerCase().replaceAll('ё', 'е');
    return RegExp(
      r'табел|смен|выход|отработ|сводк|подготов|состав|напиш|созда',
    ).hasMatch(normalized);
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
    final functionName = _useStructuredAssistant(
      mode: mode,
      prompt: cleanPrompt,
    )
        ? 'ai-assistant'
        : 'ai-search';
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
