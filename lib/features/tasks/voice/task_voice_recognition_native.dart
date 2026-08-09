import 'package:flutter/services.dart';

const MethodChannel _taskVoiceChannel = MethodChannel(
  'ru.appstroy.skbs/task_voice',
);

Future<String> recognizeTaskVoice({
  List<String> hints = const <String>[],
  void Function(String transcript)? onPartial,
  bool prioritizeAxes = false,
}) async {
  try {
    final value = await _taskVoiceChannel.invokeMethod<String>(
      'recognizeTask',
      <String, Object>{
        'locale': 'ru-RU',
        'hints': hints,
        'prioritize_axes': prioritizeAxes,
      },
    );
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      throw Exception('Речь не распознана. Попробуйте сказать задачу ещё раз.');
    }
    onPartial?.call(text);
    return text;
  } on PlatformException catch (error) {
    throw Exception(
      error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Не удалось распознать голос.',
    );
  } on MissingPluginException {
    throw Exception('Голосовой ввод пока недоступен на этом устройстве.');
  }
}

void updateTaskVoiceRecognitionContext({
  List<String> hints = const <String>[],
  bool prioritizeAxes = false,
}) {
  // Мобильные системные распознаватели получают словарь при запуске сессии.
  // PWA умеет менять подсказки прямо во время непрерывной записи; на native
  // новый контекст безопасно применится при следующем запуске микрофона.
}

Future<void> stopTaskVoiceRecognition() async {
  try {
    await _taskVoiceChannel.invokeMethod<void>('stopTask');
  } on MissingPluginException {
    // Старые мобильные сборки не знают ручную остановку. PWA использует
    // собственную реализацию; новая мобильная сборка получит канал отдельно.
  }
}
