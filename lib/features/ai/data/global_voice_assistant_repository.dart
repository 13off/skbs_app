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

    final snapshot = GlobalVoiceContextController.snapshotFor(cleanCompanyId);
    final contextObject = snapshot?.objectName.trim() ?? '';
    final explicitObject = objectName?.trim() ?? '';
    final effectiveObject = explicitObject.isNotEmpty
        ? explicitObject
        : contextObject.isEmpty
        ? null
        : contextObject;
    final requestDate = date ?? DateTime.now();
    final body = <String, dynamic>{
      'company_id': cleanCompanyId,
      'object_name': effectiveObject,
      'date': _dateKey(requestDate),
      'prompt': cleanPrompt,
    };
    if (snapshot != null && snapshot.conversationTopic.trim().isNotEmpty) {
      body['conversation_context'] = <String, dynamic>{
        'topic': snapshot.conversationTopic,
        'query_mode': snapshot.conversationMode,
        'date': snapshot.conversationDate,
        'prompt': snapshot.conversationPrompt,
        'object_name': snapshot.objectName,
      };
    }

    final response = await _client.functions.invoke(
      'ai-global-command',
      body: body,
    );
    final data = _map(response.data);

    if (data['fallback'] == true) {
      GlobalVoiceContextController.clearConversation(companyId: cleanCompanyId);
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

    _rememberConversation(data, cleanCompanyId);
    return AiAssistantResult.fromMap(data);
  }

  static void _rememberConversation(
    Map<String, dynamic> data,
    String companyId,
  ) {
    final raw = data['conversation'];
    if (raw is! Map) {
      GlobalVoiceContextController.clearConversation(companyId: companyId);
      return;
    }
    final conversation = Map<String, dynamic>.from(raw);
    final topic = conversation['topic']?.toString().trim() ?? '';
    if (topic.isEmpty) {
      GlobalVoiceContextController.clearConversation(companyId: companyId);
      return;
    }
    GlobalVoiceContextController.setConversation(
      companyId: companyId,
      topic: topic,
      mode: conversation['query_mode']?.toString().trim() ?? '',
      date: conversation['date']?.toString().trim() ?? '',
      prompt: conversation['prompt']?.toString().trim() ?? '',
      objectName: conversation['object_name']?.toString(),
    );
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
