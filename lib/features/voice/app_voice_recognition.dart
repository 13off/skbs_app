import '../tasks/voice/task_voice_recognition.dart' as speech;

/// Общий вход в распознавание речи AppСтрой.
///
/// Пока использует тот же проверенный платформенный SpeechRecognition-движок,
/// что и голосовое создание задач, но без осевого приоритета. Это позволяет
/// всем модулям приложения использовать один стабильный микрофонный слой,
/// не копируя Web/Android/iOS реализацию по фичам.
Future<String> recognizeAppVoice({
  List<String> hints = const <String>[],
  void Function(String transcript)? onPartial,
}) {
  return speech.recognizeTaskVoice(
    hints: hints,
    onPartial: onPartial,
    prioritizeAxes: false,
  );
}

Future<void> stopAppVoiceRecognition() => speech.stopTaskVoiceRecognition();
