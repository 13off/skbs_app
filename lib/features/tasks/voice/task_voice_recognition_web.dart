import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'task_voice_axis_hearing.dart';
import 'task_voice_dictionaries.dart';

_WebVoiceSession? _activeSession;

class _WebVoiceSession {
  final JSObject recognition;
  final Completer<String> completer = Completer<String>();
  List<String> hints;
  final List<String> segments = <String>[];
  final void Function(String transcript)? onPartial;
  bool prioritizeAxes;

  String interim = '';
  String lastPublished = '';
  bool stopRequested = false;

  _WebVoiceSession({
    required this.recognition,
    required this.hints,
    required this.onPartial,
    required this.prioritizeAxes,
  });
}

Future<String> recognizeTaskVoice({
  List<String> hints = const <String>[],
  void Function(String transcript)? onPartial,
  bool prioritizeAxes = false,
}) {
  if (_activeSession != null) {
    throw Exception('Голосовой ввод уже запущен.');
  }

  final constructor = _speechRecognitionConstructor();
  if (constructor == null) {
    throw Exception(
      'Голосовой ввод не поддерживается этим браузером. Откройте AppСтрой в Safari или Chrome.',
    );
  }

  final recognition = constructor.callAsConstructor<JSObject>();
  final cleanHints = normalizeTaskVoiceRecognitionHints(hints);
  final session = _WebVoiceSession(
    recognition: recognition,
    hints: cleanHints,
    onPartial: onPartial,
    prioritizeAxes: prioritizeAxes,
  );
  _activeSession = session;

  recognition
    ..setProperty('lang'.toJS, 'ru-RU'.toJS)
    ..setProperty('continuous'.toJS, true.toJS)
    ..setProperty('interimResults'.toJS, true.toJS)
    ..setProperty('maxAlternatives'.toJS, 3.toJS);
  _applySpeechGrammar(recognition, cleanHints);

  void handleResult(JSAny? eventValue) {
    if (eventValue == null || eventValue.isUndefinedOrNull) return;
    final event = eventValue as JSObject;
    final resultsValue = event.getProperty<JSAny?>('results'.toJS);
    if (resultsValue == null || resultsValue.isUndefinedOrNull) return;

    final results = resultsValue as JSObject;
    final length = _readInt(results.getProperty<JSAny?>('length'.toJS));
    final startIndex = _readInt(
      event.getProperty<JSAny?>('resultIndex'.toJS),
    );

    for (var index = startIndex; index < length; index += 1) {
      final resultValue = results.getProperty<JSAny?>(index.toString().toJS);
      if (resultValue == null || resultValue.isUndefinedOrNull) continue;
      final result = resultValue as JSObject;
      final text = _bestAlternative(
        result,
        session.hints,
        prioritizeAxes: session.prioritizeAxes,
      );
      if (text.isEmpty) continue;

      final isFinal = _readBool(result.getProperty<JSAny?>('isFinal'.toJS));
      if (isFinal) {
        session.interim = '';
        if (session.segments.isEmpty || session.segments.last != text) {
          session.segments.add(text);
        }
      } else {
        session.interim = text;
      }
    }
    _publishPartial(session);
  }

  void handleError(JSAny? eventValue) {
    final code = _speechErrorCode(eventValue);
    if (code == 'no-speech') return;
    if (code == 'aborted' && session.stopRequested) return;

    final message = switch (code) {
      'not-allowed' || 'service-not-allowed' =>
        'Разрешите AppСтрой доступ к микрофону и повторите.',
      'audio-capture' => 'Микрофон недоступен.',
      'network' => 'Не удалось распознать речь из-за сети. Попробуйте ещё раз.',
      _ => 'Не удалось распознать голос. Попробуйте ещё раз.',
    };
    _finishError(session, message);
  }

  void handleEnd() {
    if (_activeSession != session || session.completer.isCompleted) return;
    _commitInterim(session);
    _publishPartial(session);

    if (session.stopRequested) {
      _finishSuccess(session);
      return;
    }

    // Safari/Chrome могут завершить одну сессию после паузы даже при
    // continuous=true. Пока пользователь сам не нажал «Стоп», запускаем
    // слушание снова и продолжаем собирать тот же текст.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (_activeSession != session ||
            session.stopRequested ||
            session.completer.isCompleted) {
          return;
        }
        try {
          session.recognition.callMethod<JSAny?>('start'.toJS);
        } catch (_) {
          _finishError(
            session,
            'Браузер остановил микрофон. Нажмите «Сказать задачу» ещё раз.',
          );
        }
      }),
    );
  }

  recognition
    ..setProperty('onresult'.toJS, handleResult.toJS)
    ..setProperty('onerror'.toJS, handleError.toJS)
    ..setProperty('onend'.toJS, handleEnd.toJS);

  try {
    recognition.callMethod<JSAny?>('start'.toJS);
  } catch (_) {
    _activeSession = null;
    throw Exception('Не удалось запустить микрофон. Попробуйте ещё раз.');
  }

  return session.completer.future;
}

void updateTaskVoiceRecognitionContext({
  List<String> hints = const <String>[],
  bool prioritizeAxes = false,
}) {
  final session = _activeSession;
  if (session == null || session.completer.isCompleted) return;

  final cleanHints = normalizeTaskVoiceRecognitionHints(hints);
  session.hints = cleanHints;
  session.prioritizeAxes = prioritizeAxes;

  // Даже если браузер не применяет обновлённый JSGF до следующего сегмента,
  // новый список подсказок сразу используется нашим выбором альтернатив.
  _applySpeechGrammar(session.recognition, cleanHints);
}

Future<void> stopTaskVoiceRecognition() async {
  final session = _activeSession;
  if (session == null || session.completer.isCompleted) return;
  if (session.stopRequested) return;

  session.stopRequested = true;
  try {
    session.recognition.callMethod<JSAny?>('stop'.toJS);
  } catch (_) {
    _finishSuccess(session);
  }
}

JSFunction? _speechRecognitionConstructor() {
  for (final name in const <String>[
    'SpeechRecognition',
    'webkitSpeechRecognition',
  ]) {
    final value = globalContext.getProperty<JSAny?>(name.toJS);
    if (value == null || value.isUndefinedOrNull || !value.isA<JSFunction>()) {
      continue;
    }
    // isA выше проверяет реальный JS-тип; cast нужен статической типизации Dart.
    // ignore: invalid_runtime_check_with_js_interop_types
    return value as JSFunction;
  }
  return null;
}

void _applySpeechGrammar(JSObject recognition, List<String> hints) {
  if (hints.isEmpty) return;

  JSAny? constructor;
  for (final name in const <String>[
    'SpeechGrammarList',
    'webkitSpeechGrammarList',
  ]) {
    final value = globalContext.getProperty<JSAny?>(name.toJS);
    if (value != null && !value.isUndefinedOrNull && value.isA<JSFunction>()) {
      constructor = value;
      break;
    }
  }
  if (constructor == null || !constructor.isA<JSFunction>()) return;

  try {
    // ignore: invalid_runtime_check_with_js_interop_types
    final function = constructor as JSFunction;
    final grammars = function.callAsConstructor<JSObject>();
    final alternatives = hints.take(160).join(' | ');
    final grammar =
        '#JSGF V1.0; grammar appstroy; public <term> = $alternatives ;';
    grammars.callMethod<JSAny?>(
      'addFromString'.toJS,
      grammar.toJS,
      1.toJS,
    );
    recognition.setProperty('grammars'.toJS, grammars);
  } catch (_) {
    // Подсказки — дополнительное улучшение. Если браузер не поддерживает
    // грамматики, обычное распознавание всё равно продолжает работать.
  }
}

String _bestAlternative(
  JSObject result,
  List<String> hints, {
  required bool prioritizeAxes,
}) {
  final length = _readInt(result.getProperty<JSAny?>('length'.toJS));
  final alternatives = length <= 0 ? 1 : (length > 3 ? 3 : length);
  var bestText = '';
  var bestScore = double.negativeInfinity;

  for (var index = 0; index < alternatives; index += 1) {
    final value = result.getProperty<JSAny?>(index.toString().toJS);
    if (value == null || value.isUndefinedOrNull) continue;
    final alternative = value as JSObject;
    final transcriptValue = alternative.getProperty<JSAny?>('transcript'.toJS);
    if (transcriptValue == null ||
        transcriptValue.isUndefinedOrNull ||
        !transcriptValue.isA<JSString>()) {
      continue;
    }
    final text = (transcriptValue as JSString).toDart.trim();
    if (text.isEmpty) continue;

    final confidence = _readDouble(
      alternative.getProperty<JSAny?>('confidence'.toJS),
    );
    final axisContext = prioritizeAxes || _containsExplicitAxisMarker(text);
    final axisScore = axisContext ? scoreTaskVoiceAxesCandidate(text) * 0.45 : 0.0;
    final score =
        confidence + scoreTaskVoiceRecognitionHints(text, hints) + axisScore;
    if (score > bestScore) {
      bestScore = score;
      bestText = text;
    }
  }

  return bestText;
}

bool _containsExplicitAxisMarker(String value) => RegExp(
      r'(^|[^А-Яа-яЁё])(ось|оси|по\s+осям)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ).hasMatch(value);

String _liveTranscript(_WebVoiceSession session) => <String>[
  ...session.segments,
  if (session.interim.trim().isNotEmpty) session.interim.trim(),
].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

void _publishPartial(_WebVoiceSession session) {
  final text = _liveTranscript(session);
  if (text.isEmpty || text == session.lastPublished) return;
  session.lastPublished = text;
  try {
    session.onPartial?.call(text);
  } catch (_) {
    // Ошибка UI-предпросмотра не должна останавливать микрофон.
  }
}

void _commitInterim(_WebVoiceSession session) {
  final text = session.interim.trim();
  session.interim = '';
  if (text.isEmpty) return;
  if (session.segments.isEmpty || session.segments.last != text) {
    session.segments.add(text);
  }
}

void _finishSuccess(_WebVoiceSession session) {
  if (session.completer.isCompleted) return;
  _commitInterim(session);
  _publishPartial(session);
  final text = session.segments.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_activeSession == session) _activeSession = null;
  if (text.isEmpty) {
    session.completer.completeError(
      Exception('Не услышал задачу. Попробуйте ещё раз.'),
    );
  } else {
    session.completer.complete(text);
  }
}

void _finishError(_WebVoiceSession session, String message) {
  if (session.completer.isCompleted) return;
  session.stopRequested = true;
  if (_activeSession == session) _activeSession = null;
  try {
    session.recognition.callMethod<JSAny?>('abort'.toJS);
  } catch (_) {}
  session.completer.completeError(Exception(message));
}

String _speechErrorCode(JSAny? eventValue) {
  if (eventValue == null || eventValue.isUndefinedOrNull) return '';
  final raw = (eventValue as JSObject).getProperty<JSAny?>('error'.toJS);
  if (raw == null || raw.isUndefinedOrNull || !raw.isA<JSString>()) return '';
  return (raw as JSString).toDart;
}

int _readInt(JSAny? value) {
  if (value == null || value.isUndefinedOrNull || !value.isA<JSNumber>()) {
    return 0;
  }
  return (value as JSNumber).toDartInt;
}

double _readDouble(JSAny? value) {
  if (value == null || value.isUndefinedOrNull || !value.isA<JSNumber>()) {
    return 0;
  }
  return (value as JSNumber).toDartDouble;
}

bool _readBool(JSAny? value) {
  if (value == null || value.isUndefinedOrNull || !value.isA<JSBoolean>()) {
    return false;
  }
  return (value as JSBoolean).toDart;
}
