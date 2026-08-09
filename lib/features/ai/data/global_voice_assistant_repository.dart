import 'dart:convert';

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
/// Conversation-level behaviour lives here instead of being duplicated inside
/// every HR/accounting/legal/procurement parser:
/// - clarification memory for ambiguous/incomplete commands;
/// - explicit multi-step commands separated by «потом», «затем», «далее» or `;`;
/// - short corrections of the previous turn («не Иванову, а Петрову»);
/// - replay with changed context («то же самое на завтра», «так же для Москвы»);
/// - safe continuation of a prepared action («да, подтверждай»), which still
///   goes through the existing visual confirmation and audit pipeline.
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
      if (_isCancelFollowUp(cleanPrompt)) {
        GlobalVoiceContextController.clearClarification(
          companyId: cleanCompanyId,
        );
        return _localResult(
          title: 'Уточнение отменено',
          summary: 'Предыдущую незавершённую команду не продолжаю.',
          objectName: effectiveObject,
          date: requestDate,
        );
      }

      final before = List<String>.from(
        snapshot?.pendingClarificationBefore ?? const <String>[],
      );
      final after = List<String>.from(
        snapshot?.pendingClarificationAfter ?? const <String>[],
      );
      final mergedPrompt = _mergeClarification(pendingPrompt, cleanPrompt);
      final clarified = await _requestSingle(
        companyId: cleanCompanyId,
        objectName: effectiveObject,
        date: requestDate,
        prompt: mergedPrompt,
      );

      if (_isClarificationResult(clarified)) {
        GlobalVoiceContextController.setClarification(
          companyId: cleanCompanyId,
          prompt: mergedPrompt,
          question: clarified.summary,
          before: before,
          after: after,
        );
        return clarified;
      }

      if (before.isNotEmpty || after.isNotEmpty) {
        return _requestCompound(
          companyId: cleanCompanyId,
          objectName: effectiveObject,
          date: requestDate,
          commands: <String>[...before, mergedPrompt, ...after],
        );
      }
      return clarified;
    }

    if (snapshot != null && snapshot.lastCommandPrompt.trim().isNotEmpty) {
      if (_isCancelFollowUp(cleanPrompt) && snapshot.lastAction.isNotEmpty) {
        GlobalVoiceContextController.rememberTurn(
          companyId: cleanCompanyId,
          prompt: snapshot.lastCommandPrompt,
          objectName: snapshot.lastCommandObjectName,
          date: snapshot.lastCommandDate,
          resultTitle: snapshot.lastResultTitle,
          resultSummary: snapshot.lastResultSummary,
        );
        return _localResult(
          title: 'Подготовленное действие отменено',
          summary:
              'Ничего не изменено. Предыдущую команду оставил в истории разговора, но подтверждать её больше не предлагаю.',
          objectName: snapshot.lastCommandObjectName,
          date: requestDate,
        );
      }

      if (_isAffirmativeFollowUp(cleanPrompt) && snapshot.lastAction.isNotEmpty) {
        final action = AiAssistantAction.fromMap(
          Map<String, dynamic>.from(snapshot.lastAction),
        );
        if (action.type.isNotEmpty) {
          return _resumePreparedResult(snapshot, action, requestDate);
        }
      }
    }

    var resolvedPrompt = cleanPrompt;
    if (snapshot != null && snapshot.lastCommandPrompt.trim().isNotEmpty) {
      final corrected = _rewriteCorrection(
        snapshot.lastCommandPrompt,
        cleanPrompt,
      );
      if (corrected != null) {
        resolvedPrompt = corrected;
      } else if (_isReplayFollowUp(cleanPrompt)) {
        final replay = _rewriteReplay(
          basePrompt: snapshot.lastCommandPrompt,
          followUp: cleanPrompt,
          lastObjectName: snapshot.lastCommandObjectName,
          lastDate: snapshot.lastCommandDate,
        );
        if (replay.clarification.isNotEmpty) {
          GlobalVoiceContextController.setClarification(
            companyId: cleanCompanyId,
            prompt: replay.prompt,
            question: replay.clarification,
          );
          return _clarificationResult(
            message: replay.clarification,
            objectName: effectiveObject,
            date: requestDate,
          );
        }
        if (replay.prompt.isNotEmpty) resolvedPrompt = replay.prompt;
      }
    }

    final commands = _splitCompoundCommands(resolvedPrompt);
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
      prompt: resolvedPrompt,
    );
  }

  /// The floating voice UI may immediately open the already-established
  /// confirmation sheet for these short phrases. This is not final approval:
  /// the underlying action coordinator still requires its normal confirmation.
  static bool shouldExecutePreparedAction(String prompt) {
    return _isAffirmativeFollowUp(prompt);
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
        GlobalVoiceContextController.setClarification(
          companyId: companyId,
          prompt: commands[index],
          question: result.summary,
          before: commands.take(index),
          after: commands.skip(index + 1),
        );
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
            if (index + 1 < commands.length)
              'Оставшиеся ${commands.length - index - 1} шагов уже запомнены и продолжатся после уточнения.',
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

    final result = AiAssistantResult(
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

    GlobalVoiceContextController.rememberTurn(
      companyId: companyId,
      prompt: commands.join('; затем '),
      objectName: _actionObjectName(action) ?? objectName ?? '',
      date: _dateKey(date),
      resultTitle: result.title,
      resultSummary: result.summary,
      action: action == null
          ? const <String, dynamic>{}
          : _actionMap(action),
    );
    return result;
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
        _rememberTurn(
          companyId: companyId,
          prompt: prompt,
          objectName: objectName,
          date: date,
          result: result,
        );
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
      final result = AiAssistantResult.fromMap(data);
      _rememberTurn(
        companyId: companyId,
        prompt: prompt,
        objectName: objectName,
        date: date,
        result: result,
        raw: data,
      );
      return result;
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

  static void _rememberTurn({
    required String companyId,
    required String prompt,
    required String? objectName,
    required DateTime date,
    required AiAssistantResult result,
    Map<String, dynamic> raw = const <String, dynamic>{},
  }) {
    final action = result.action;
    final scope = raw['scope'];
    final scopeMap = scope is Map
        ? Map<String, dynamic>.from(scope)
        : const <String, dynamic>{};
    final rawObject = scopeMap['object_name']?.toString().trim() ?? '';
    final actionObject = _actionObjectName(action) ?? '';
    final effectiveObject = actionObject.isNotEmpty
        ? actionObject
        : rawObject.isNotEmpty && rawObject != 'Все доступные объекты'
        ? rawObject
        : objectName?.trim() ?? '';
    final rawDate = scopeMap['date']?.toString().trim() ?? '';

    GlobalVoiceContextController.rememberTurn(
      companyId: companyId,
      prompt: prompt,
      objectName: effectiveObject,
      date: rawDate.isNotEmpty ? rawDate : _dateKey(date),
      resultTitle: result.title,
      resultSummary: result.summary,
      action: action == null
          ? const <String, dynamic>{}
          : _actionMap(action),
    );
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

  static AiAssistantResult _resumePreparedResult(
    GlobalVoiceContextSnapshot snapshot,
    AiAssistantAction action,
    DateTime date,
  ) {
    return AiAssistantResult(
      title: snapshot.lastResultTitle.isNotEmpty
          ? snapshot.lastResultTitle
          : action.title,
      summary: snapshot.lastResultSummary.isNotEmpty
          ? snapshot.lastResultSummary
          : 'Предыдущее действие готово к проверке.',
      highlights: const <String>[
        'Продолжаю последнее подготовленное действие без повторения команды.',
      ],
      warnings: const <String>[
        'Голосовое «подтверждай» только открывает штатную проверку. Изменение данных всё равно требует финального подтверждения.',
      ],
      nextSteps: <String>['Проверьте действие «${action.title}».'],
      scopeLabel: _scopeLabel(
        snapshot.lastCommandObjectName.isEmpty
            ? null
            : snapshot.lastCommandObjectName,
        _dateFromKey(snapshot.lastCommandDate) ?? date,
      ),
      preliminary: true,
      aiUsed: false,
      action: action,
    );
  }

  static AiAssistantResult _localResult({
    required String title,
    required String summary,
    required String? objectName,
    required DateTime date,
  }) {
    return AiAssistantResult(
      title: title,
      summary: summary,
      highlights: const <String>[],
      warnings: const <String>[],
      nextSteps: const <String>[],
      scopeLabel: _scopeLabel(objectName, date),
      preliminary: false,
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
      r'(уточн|неоднознач|несколько|не хватает|не указан|не указана|не указано|укажите|укажи|назови|назовите|скажи|скажите|не понял|не поняла|не найден|не найдена|кого именно|какой именно|какую именно|какое именно)',
    ).hasMatch(value);
  }

  static bool _isAffirmativeFollowUp(String prompt) {
    final value = _normalizedSpeech(prompt);
    if (value.length > 48) return false;
    return RegExp(
      r'^(?:(?:да|ага|угу|ок|окей)\s+)?(?:подтверди|подтверждай|выполняй|выполни|делай|поехали|запускай|запусти)$|^(?:да|ага|угу|ок|окей)$',
    ).hasMatch(value);
  }

  static bool _isCancelFollowUp(String prompt) {
    final value = _normalizedSpeech(prompt);
    if (value.length > 48) return false;
    return RegExp(
      r'^(?:нет|не надо|отмена|отмени|забудь|не делай|стоп|отбой)(?:\s+(?:это|его|ее|их|действие))?$',
    ).hasMatch(value);
  }

  static String? _rewriteCorrection(String basePrompt, String followUp) {
    if (basePrompt.trim().isEmpty || followUp.trim().length > 180) return null;
    final value = followUp.trim();
    final patterns = <RegExp>[
      RegExp(
        r'^(?:нет[,\s]+)?не\s+(.+?)(?:\s*,?\s*а\s+|\s*,\s*)(.+?)[.!?]*$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:нет[,\s]+)?(.+?)\s+(?:замени|поменяй)\s+на\s+(.+?)[.!?]*$',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match == null) continue;
      final oldValue = match.group(1)?.trim() ?? '';
      final newValue = match.group(2)?.trim() ?? '';
      if (oldValue.isEmpty || newValue.isEmpty) continue;
      final oldPattern = RegExp(RegExp.escape(oldValue), caseSensitive: false);
      if (!oldPattern.hasMatch(basePrompt)) return null;
      return basePrompt.replaceFirst(oldPattern, newValue).trim();
    }
    return null;
  }

  static bool _isReplayFollowUp(String prompt) {
    final value = _normalizedSpeech(prompt);
    if (value.length > 180) return false;
    return RegExp(
      r'^(?:(?:а|и)\s+)?(?:теперь\s+)?(?:(?:сделай\s+)?то\s+же(?:\s+самое)?|(?:сделай\s+)?так\s+же|повтори(?:\s+это)?|еще\s+раз|сделай\s+еще\s+раз)(?:\s+.*)?$|^(?:(?:а|и)\s+)?(?:теперь\s+)?(?:на\s+(?:сегодня|завтра|послезавтра|вчера)|для\s+.+|на\s+объект(?:е)?\s+.+|по\s+объекту\s+.+)$',
    ).hasMatch(value);
  }

  static _PromptRewrite _rewriteReplay({
    required String basePrompt,
    required String followUp,
    required String lastObjectName,
    required String lastDate,
  }) {
    var modifier = followUp.trim();
    modifier = modifier
        .replaceFirst(
          RegExp(
            r'^(?:(?:а|и)\s+)?(?:теперь\s+)?(?:(?:сделай\s+)?то\s+же(?:\s+самое)?|(?:сделай\s+)?так\s+же|повтори(?:\s+это)?|еще\s+раз|сделай\s+еще\s+раз)\b[,\s]*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    final genericSecondObject = RegExp(
      r'(?:втор(?:ого|ой|ому)|друг(?:ого|ой|ому))\s+объект',
      caseSensitive: false,
    ).hasMatch(modifier);
    if (genericSecondObject) {
      return _PromptRewrite(
        prompt: _stripKnownObject(basePrompt, lastObjectName),
        clarification:
            'Назови второй объект по имени — остальную часть предыдущей команды я уже помню.',
      );
    }

    var result = basePrompt.trim();
    final objectTarget = _objectModifier(modifier);
    if (objectTarget.isNotEmpty) {
      final oldObjectPattern = _objectLikePattern(lastObjectName);
      if (oldObjectPattern != null && oldObjectPattern.hasMatch(result)) {
        result = result.replaceFirst(oldObjectPattern, objectTarget);
      } else {
        result = '$result на объект $objectTarget'.trim();
      }
    }

    final dateModifier = _dateModifier(modifier);
    if (dateModifier.isNotEmpty) {
      final anyDate = RegExp(
        r'\b(?:сегодня|завтра|послезавтра|вчера|20\d{2}-\d{1,2}-\d{1,2}|\d{1,2}[./]\d{1,2}(?:[./]20\d{2})?)\b',
        caseSensitive: false,
      );
      if (anyDate.hasMatch(result)) {
        result = result.replaceFirst(anyDate, dateModifier);
      } else if (lastDate.isNotEmpty && result.contains(lastDate)) {
        result = result.replaceFirst(lastDate, dateModifier);
      } else {
        result = '$result $dateModifier'.trim();
      }
    }

    if (RegExp(r'\bсроч', caseSensitive: false).hasMatch(modifier) &&
        !RegExp(r'\bсроч', caseSensitive: false).hasMatch(result)) {
      result = '$result срочно'.trim();
    }

    return _PromptRewrite(prompt: result);
  }

  static RegExp? _objectLikePattern(String objectName) {
    final cleanObject = objectName.trim();
    if (cleanObject.isEmpty) return null;
    final escaped = cleanObject
        .split(RegExp(r'\s+'))
        .map(RegExp.escape)
        .join(r'\s+');
    return RegExp('$escaped[а-яa-z]*', caseSensitive: false);
  }

  static String _stripKnownObject(String prompt, String objectName) {
    final pattern = _objectLikePattern(objectName);
    if (pattern == null) return prompt.trim();
    return prompt
        .replaceFirst(pattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _objectModifier(String value) {
    final match = RegExp(
      r'(?:для|на\s+объект(?:е)?|по\s+объекту)\s+(.+?)(?=\s+(?:на\s+)?(?:сегодня|завтра|послезавтра|вчера)\b|$)',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.trim() ?? '';
  }

  static String _dateModifier(String value) {
    final match = RegExp(
      r'\b(послезавтра|завтра|сегодня|вчера|20\d{2}-\d{1,2}-\d{1,2}|\d{1,2}[./]\d{1,2}(?:[./]20\d{2})?)\b',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.trim() ?? '';
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

  static String _normalizedSpeech(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
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

  static String? _actionObjectName(AiAssistantAction? action) {
    if (action == null) return null;
    final direct = action.text('object_name');
    if (direct.isNotEmpty) return direct;
    if (action.type != 'voice_compound_batch') return null;
    final raw = action.payload['actions'];
    if (raw is! List) return null;
    for (final item in raw.reversed) {
      if (item is! Map) continue;
      final nested = AiAssistantAction.fromMap(
        Map<String, dynamic>.from(item),
      );
      final objectName = nested.text('object_name');
      if (objectName.isNotEmpty) return objectName;
    }
    return null;
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
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // FunctionException may contain plain text rather than JSON.
      }
    }
    return <String, dynamic>{};
  }

  static String _scopeLabel(String? objectName, DateTime date) {
    final cleanObject = objectName?.trim() ?? '';
    return <String>[
      cleanObject.isEmpty ? 'Все доступные объекты' : cleanObject,
      _dateKey(date),
    ].join(' • ');
  }

  static DateTime? _dateFromKey(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static String _dateKey(DateTime value) {
    final cleanDate = DateTime(value.year, value.month, value.day);
    final month = cleanDate.month.toString().padLeft(2, '0');
    final day = cleanDate.day.toString().padLeft(2, '0');
    return '${cleanDate.year}-$month-$day';
  }
}

class _PromptRewrite {
  final String prompt;
  final String clarification;

  const _PromptRewrite({required this.prompt, this.clarification = ''});
}
