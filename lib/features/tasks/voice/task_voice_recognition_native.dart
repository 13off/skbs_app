import 'package:flutter/services.dart';

const MethodChannel _taskVoiceChannel = MethodChannel(
  'ru.appstroy.skbs/task_voice',
);

Future<String> recognizeTaskVoice({
  List<String> hints = const <String>[],
  void Function(String transcript)? onPartial,
}) async {
  try {
    final value = await _taskVoiceChannel.invokeMethod<String>(
      'recognizeTask',
      <String, Object>{
        'locale': 'ru-RU',
        'hints': hints,
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

Future<void> stopTaskVoiceRecognition() async {
  try {
    await _taskVoiceChannel.invokeMethod<void>('stopTask');
  } on MissingPluginException {
    // Старые мобильные сборки не знают ручную остановку. PWA использует
    // собственную реализацию; новая мобильная сборка получит канал отдельно.
  }
}
