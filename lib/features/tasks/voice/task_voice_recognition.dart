import 'task_voice_recognition_native.dart'
    if (dart.library.js_interop) 'task_voice_recognition_web.dart' as platform;

Future<String> recognizeTaskVoice({List<String> hints = const <String>[]}) =>
    platform.recognizeTaskVoice(hints: hints);

Future<void> stopTaskVoiceRecognition() => platform.stopTaskVoiceRecognition();
