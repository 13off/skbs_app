import 'task_voice_recognition_native.dart'
    if (dart.library.js_interop) 'task_voice_recognition_web.dart' as platform;

Future<String> recognizeTaskVoice() => platform.recognizeTaskVoice();
