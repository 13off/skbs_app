import 'package:flutter/services.dart';

const MethodChannel _taskVoiceChannel = MethodChannel(
  'ru.appstroy.skbs/task_voice',
);

Future<String> recognizeTaskVoice() async {
  try {
    final value = await _taskVoiceChannel.invokeMethod<String>(
      'recognizeTask',
      const <String, Object>{'locale': 'ru-RU'},
    );
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      throw const PlatformException(
        code: 'empty_speech',
        message: 'Речь не распознана. Попробуйте сказать задачу ещё раз.',
      );
    }
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
