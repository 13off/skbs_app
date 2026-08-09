import 'task_voice_recognition_native.dart'
    if (dart.library.js_interop) 'task_voice_recognition_web.dart' as platform;

Future<String> recognizeTaskVoice({
  List<String> hints = const <String>[],
  void Function(String transcript)? onPartial,
  bool prioritizeAxes = false,
}) => platform.recognizeTaskVoice(
  hints: hints,
  onPartial: onPartial,
  prioritizeAxes: prioritizeAxes,
);

Future<void> stopTaskVoiceRecognition() => platform.stopTaskVoiceRecognition();
