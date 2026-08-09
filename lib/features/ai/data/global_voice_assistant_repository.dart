import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_assistant_result.dart';
import 'ai_assistant_repository.dart';
import 'global_voice_context_controller.dart';

/// Dedicated router for the floating microphone.
///
/// Global-only commands are resolved by `ai-global-command`. Anything that the
/// global endpoint does not own falls back to the existing assistant router, so
/// typed AI chat and the already proven action pipeline keep their behaviour.
///
/// The repository also owns two conversation-level behaviours which should not
/// be duplicated inside every domain parser:
/// - a short clarification memory for ambiguous/incomplete commands;
/// - explicit multi-step commands separated by «потом», «затем», «далее» or `;`.
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
    final pendingPrompt = snapshot?.pendingClarificationPrompt.trim() ?? '';

    if (pendingPrompt.isNotEmpty) {
      final mergedPrompt = _mergeClarification(pendingPrompt, cleanPrompt);
      return _requestSingle(
        companyId: cleanCompanyId,
        objectName: effectiveObject,
        date: requestDate,
        prompt: mergedPrompt,
      );
    }

    final commands = _splitCompoundCommands(cleanPrompt);
    if (commands.length > 1) {
      return _requestCompound(
        companyId: cleanCompanyId,
        objectName: effectiveObject,
        date: requestDate,
        commands: commands,
      );
    }

    return _requestSingle(
      companyId: cleanCompanyId,
      objectName: effectiveObject,
      date: requestDate,
      prompt: cleanPrompt,
    );
  }

  static Future<AiAssistantResult> _requestCompound({
    required String companyId,
    required String? objectName,
    required DateTime date,
    required List<String> commands,
  }) async {
    final results = <AiAssistantResult>[];

    for (var index = 0; index < commands.length; index++) {
      final result = await _requestSingle(
        companyId: companyId,
        objectName: objectName,
        date: date,
        prompt: commands[index],
      );
      results.add(result);

      if (_isClarificationResult(result)) {
        return AiAssistantResult(
          title: 'Нужно уточнение в шаге ${index + 1}',
          summary: result.summary,
          highlights: <String>[
            'Исходный шаг: ${commands[index]}',
            ...result.highlights,
          ],
          warnings: result.warnings,
          nextSteps: <String>[
            ...result.nextSteps,
            'После уточнения помощник продолжит этот шаг. Остальные шаги можно повторить одной фразой.',
          ],
          scopeLabel: _scopeLabel(objectName, date),
          preliminary: true,
          aiUsed: results.any((item) => item.aiUsed),
        );
      }
    }

    final actions = results
        .map((result) => result.action)
        .whereType<AiAssistantAction>()
        .toList(growable: false);
    final highlights = <String>[];
    for (var index = 0; index < results.length; index++) {
      final result = results[index];
      final description = result.summary.isNotEmpty
          ? result.summary
          : result.title;
      highlights.add('${index + 1}. ${commands[index]} — $description');
    }

    final AiAssistantAction? action;
    if (actions.isEmpty) {
      action = null;
    } else if (actions.length == 1) {
      action = actions.single;
    } else {
      action = AiAssistantAction(
        id: 'voice_compound_${DateTime.now().microsecondsSinceEpoch}',
        type: 'voice_compound_batch',
        title: 'Выполнить ${actions.length} действий по очереди',
        buttonLabel: 'Проверить ${actions.length} действий',
        confirmationRequired: true,
        payload: <String, dynamic>{
          'actions': actions.map(_actionMap).toList(growable: false),
          'source_prompts': commands,
        },
      );
    }

    return AiAssistantResult(
      title: 'Составная голосовая команда',
      summary: actions.isEmpty
          ? 'Разобрал и выполнил ${commands.length} информационных шага.'
          : 'Разобрал ${commands.length} шага. Изменения ещё не внесены: каждое действие пройдёт штатную проверку и подтверждение.',
      highlights: highlights,
      warnings: actions.isEmpty
          ? const <String>[]
          : const <String>[
              'Если один из шагов отменить, пакет остановится и следующие изменения не выполнятся.',
            ],
      nextSteps: actions.isEmpty
          ? const <String>[]
          : <String>[
              actions.length == 1
                  ? 'Проверьте подготовленное действие.'
                  : 'Нажмите «Проверить ${actions.length} действий» и подтвердите нужные шаги по очереди.',
            ],
      scopeLabel: _scopeLabel(objectName, date),
      preliminary: true,
      aiUsed: results.any((result) => result.aiUsed),
      action: action,
    );
  }

  static Future<AiAssistantResult> _requestSingle({
    required String companyId,
    required String? objectName,
    required DateTime date,
    required String prompt,
  }) async {
    final snapshot = GlobalVoiceContextController.snapshotFor(companyId);
    final body = <String, dynamic>{
      'company_id': companyId,
      'object_name': objectName,
      'date': _dateKey(date),
      'prompt': prompt,
    };
    if (snapshot != null && snapshot.conversationTopic.trim().isNotEmpty) {
      body['conversation_context'] = <String, dynamic>{
        'topic': snapshot.conversationTopic,
        'query_mode': snapshot.conversationMode,
        'date': snapshot.conversationDate,
        'prompt': snapshot.conversationPrompt,
        'object_name': snapshot.conversationObjectName,
      };
    }

    try {
      final response = await _client.functions.invoke(
        'ai-global-command',
        body: body,
      );
      final data = _map(response.data);

      if (data['fallback'] == true) {
        GlobalVoiceContextController.clearConversation(companyId: companyId);
        final result = await AiAssistantRepository.request(
          mode: 'chat',
          companyId: companyId,
          objectName: objectName,
          date: date,
          prompt: prompt,
        );
        GlobalVoiceContextController.clearClarification(companyId: companyId);
        return result;
      }

      final error = data['error']?.toString().trim() ?? '';
      if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
        final message = error.isNotEmpty
            ? error
            : 'Глобальная голосовая команда недоступна';
        if (_needsClarification(response.status, message)) {
          return _rememberClarification(
            companyId: companyId,
            prompt: prompt,
            message: message,
            objectName: objectName,
            date: date,
          );
        }
        throw Exception(message);
      }

      GlobalVoiceContextController.clearClarification(companyId: companyId);
      _rememberConversation(data, companyId);
      return AiAssistantResult.fromMap(data);
    } on FunctionException catch (error) {
      final details = _map(error.details);
      final mappedMessage = details['error']?.toString().trim() ?? '';
      final rawDetails = error.details?.toString().trim() ?? '';
      final message = mappedMessage.isNotEmpty
          ? mappedMessage
          : rawDetails.isNotEmpty
          ? rawDetails
          : error.reasonPhrase?.trim().isNotEmpty == true
          ? error.reasonPhrase!.trim()
          : 'Глобальная голосовая команда недоступна';

      if (_needsClarification(error.status, message)) {
        return _rememberClarification(
          companyId: companyId,
          prompt: prompt,
          message: message,
          objectName: objectName,
          date: date,
        );
      }
      throw Exception(message);
    }
  }

  static AiAssistantResult _rememberClarification({
    required String companyId,
    required String prompt,
    required String message,
    required String? objectName,
    required DateTime date,
  }) {
    GlobalVoiceContextController.setClarification(
      companyId: companyId,
      prompt: prompt,
      question: message,
    );
    return _clarificationResult(
      message: message,
      objectName: objectName,
      date: date,
    );
  }

  static AiAssistantResult _clarificationResult({
    required String message,
    required String? objectName,
    required DateTime date,
  }) {
    return AiAssistantResult(
      title: 'Нужно уточнение',
      summary: message,
      highlights: const <String>[],
      warnings: const <String>[
        'Исходную команду повторять не нужно — помощник уже её запомнил.',
      ],
      nextSteps: const <String>[
        'Нажмите микрофон ещё раз и скажите только недостающую деталь: имя, объект, количество, срок или нужный вариант.',
      ],
      scopeLabel: _scopeLabel(objectName, date),
      preliminary: true,
      aiUsed: false,
    );
  }

  static bool _isClarificationResult(AiAssistantResult result) {
    return result.title == 'Нужно уточнение';
  }

  static bool _needsClarification(int status, String message) {
    if (status != 400 && status != 409) return false;
    final value = message.toLowerCase().replaceAll('ё', 'е');
    return RegExp(
      r'(уточн|неоднознач|несколько|не хватает|не указан|не указана|не указано|укажите|не найден|не найдена|кого именно|какой именно|какую именно|какое именно)',
    ).hasMatch(value);
  }

  static List<String> _splitCompoundCommands(String prompt) {
    var value = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    value = value
        .replaceAll(RegExp(r'\s*;\s*'), '|||')
        .replaceAll(
          RegExp(r'\s+(?:(?:и|а)\s+)?потом\s+', caseSensitive: false),
          '|||',
        )
        .replaceAll(
          RegExp(r'\s+(?:(?:и|а)\s+)?затем\s+', caseSensitive: false),
          '|||',
        )
        .replaceAll(
          RegExp(r'\s+(?:(?:и|а)\s+)?далее\s+', caseSensitive: false),
          '|||',
        )
        .replaceAll(
          RegExp(
            r'\s+(?:(?:и|а)\s+)?после\s+этого\s+',
            caseSensitive: false,
          ),
          '|||',
        );
    final commands = value
        .split('|||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return commands.isEmpty ? <String>[prompt.trim()] : commands;
  }

  static String _mergeClarification(String prompt, String clarification) {
    return '$prompt ${clarification.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<String, dynamic> _actionMap(AiAssistantAction action) {
    return <String, dynamic>{
      'id': action.id,
      'type': action.type,
      'title': action.title,
      'button_label': action.buttonLabel,
      'confirmation_required': action.confirmationRequired,
      'payload': action.payload,
    };
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

  static String _scopeLabel(String? objectName, DateTime date) {
    final cleanObject = objectName?.trim() ?? '';
    return <String>[
      cleanObject.isEmpty ? 'Все доступные объекты' : cleanObject,
      _dateKey(date),
    ].join(' • ');
  }

  static String _dateKey(DateTime value) {
    final cleanDate = DateTime(value.year, value.month, value.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');
    return '${cleanDate.year}-$month-$day';
  }
}
