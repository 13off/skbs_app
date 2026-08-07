import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<String> recognizeTaskVoice() async {
  final constructor = globalContext.getProperty<JSAny?>(
    'webkitSpeechRecognition'.toJS,
  );
  if (constructor == null || constructor.isUndefinedOrNull) {
    throw Exception(
      'Голосовой ввод не поддерживается этим браузером. Откройте AppСтрой в Safari или Chrome.',
    );
  }
  if (!constructor.isA<JSFunction>()) {
    throw Exception('Браузер не предоставил распознавание речи.');
  }
  // isA выше проверяет реальный JS-тип; cast нужен только статической типизации Dart.
  // ignore: invalid_runtime_check_with_js_interop_types
  final function = constructor as JSFunction;

  final recognition = function.callAsConstructor<JSObject>();
  recognition
    ..setProperty('lang'.toJS, 'ru-RU'.toJS)
    ..setProperty('continuous'.toJS, false.toJS)
    ..setProperty('interimResults'.toJS, false.toJS)
    ..setProperty('maxAlternatives'.toJS, 1.toJS);

  final completer = Completer<String>();
  var hasResult = false;

  void finishError(String message) {
    if (!completer.isCompleted) completer.completeError(Exception(message));
  }

  void handleResult(JSAny? eventValue) {
    if (eventValue == null || eventValue.isUndefinedOrNull) {
      finishError('Речь не распознана. Попробуйте ещё раз.');
      return;
    }
    final event = eventValue as JSObject;
    final results = event.getProperty<JSAny?>('results'.toJS);
    if (results == null || results.isUndefinedOrNull) {
      finishError('Речь не распознана. Попробуйте ещё раз.');
      return;
    }
    final first = (results as JSObject).getProperty<JSAny?>('0'.toJS);
    if (first == null || first.isUndefinedOrNull) {
      finishError('Речь не распознана. Попробуйте ещё раз.');
      return;
    }
    final alternative = (first as JSObject).getProperty<JSAny?>('0'.toJS);
    if (alternative == null || alternative.isUndefinedOrNull) {
      finishError('Речь не распознана. Попробуйте ещё раз.');
      return;
    }
    final transcript = (alternative as JSObject).getProperty<JSAny?>(
      'transcript'.toJS,
    );
    if (transcript == null || transcript.isUndefinedOrNull) {
      finishError('Речь не распознана. Попробуйте ещё раз.');
      return;
    }
    final text = (transcript as JSString).toDart.trim();
    if (text.isEmpty) {
      finishError('Речь не распознана. Попробуйте ещё раз.');
      return;
    }
    hasResult = true;
    if (!completer.isCompleted) completer.complete(text);
  }

  void handleError(JSAny? eventValue) {
    var code = '';
    if (eventValue != null && !eventValue.isUndefinedOrNull) {
      final raw = (eventValue as JSObject).getProperty<JSAny?>('error'.toJS);
      if (raw != null && !raw.isUndefinedOrNull) {
        code = (raw as JSString).toDart;
      }
    }
    final message = switch (code) {
      'not-allowed' || 'service-not-allowed' =>
        'Разрешите AppСтрой доступ к микрофону и повторите.',
      'audio-capture' => 'Микрофон недоступен.',
      'no-speech' => 'Не услышал речь. Попробуйте ещё раз.',
      _ => 'Не удалось распознать голос. Попробуйте ещё раз.',
    };
    finishError(message);
  }

  void handleEnd() {
    if (!hasResult && !completer.isCompleted) {
      finishError('Не услышал задачу. Попробуйте ещё раз.');
    }
  }

  recognition
    ..setProperty('onresult'.toJS, handleResult.toJS)
    ..setProperty('onerror'.toJS, handleError.toJS)
    ..setProperty('onend'.toJS, handleEnd.toJS);

  recognition.callMethod<JSAny?>('start'.toJS);
  return completer.future.timeout(
    const Duration(seconds: 18),
    onTimeout: () {
      try {
        recognition.callMethod<JSAny?>('stop'.toJS);
      } catch (_) {}
      throw Exception('Время ожидания истекло. Попробуйте ещё раз.');
    },
  );
}
