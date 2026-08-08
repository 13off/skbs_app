import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_assistant_result.dart';
import 'ai_assistant_repository.dart';
import 'global_voice_context_controller.dart';

/// Dedicated router for the floating microphone.
///
/// Global-only commands are resolved by `ai-global-command`. Anything that the
/// global endpoint does not own falls back to the existing assistant router, so
/// typed AI chat and the already proven action pipeline keep their behaviour.
class GlobalVoiceAssistantRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<AiAssistantResult> request({
    required String companyId,
    required String prompt,
    String? objectName,
    DateTime? date,
  }) async {
    final cleanCompanyId = companyId.trim();
    final cleanPrompt = prompt.trim();
    if (cleanCompanyId.isEmpty) {
      throw Exception('Не выбрана активная компания');
    }
    if (cleanPrompt.isEmpty) {
      throw Exception('Голосовая команда пустая');
    }

    final contextObject = GlobalVoiceContextController.objectNameFor(
      cleanCompanyId,
    );
    final explicitObject = objectName?.trim() ?? '';
    final effectiveObject = explicitObject.isNotEmpty
        ? explicitObject
        : contextObject;
    final requestDate = date ?? DateTime.now();
    final response = await _client.functions.invoke(
      'ai-global-command',
      body: <String, dynamic>{
        'company_id': cleanCompanyId,
        'object_name': effectiveObject,
        'date': _dateKey(requestDate),
        'prompt': cleanPrompt,
      },
    );
    final data = _map(response.data);

    if (data['fallback'] == true) {
      return AiAssistantRepository.request(
        mode: 'chat',
        companyId: cleanCompanyId,
        objectName: effectiveObject,
        date: requestDate,
        prompt: cleanPrompt,
      );
    }

    final error = data['error']?.toString().trim() ?? '';
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(
        error.isNotEmpty ? error : 'Глобальная голосовая команда недоступна',
      );
    }

    return AiAssistantResult.fromMap(data);
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
