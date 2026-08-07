import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let taskVoiceChannelName = "ru.appstroy.skbs/task_voice"
  private let audioEngine = AVAudioEngine()
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var voiceResult: FlutterResult?
  private var voiceTimeout: DispatchWorkItem?
  private var latestTranscript = ""
  private var hasAudioTap = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TaskVoiceRecognition")
    let channel = FlutterMethodChannel(
      name: taskVoiceChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizeTask" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let locale = (arguments?["locale"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      self?.requestTaskSpeech(locale: locale?.isEmpty == false ? locale! : "ru-RU", result: result)
    }
  }

  private func requestTaskSpeech(locale: String, result: @escaping FlutterResult) {
    guard voiceResult == nil else {
      result(FlutterError(code: "speech_busy", message: "Голосовой ввод уже запущен.", details: nil))
      return
    }
    voiceResult = result

    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        guard let self else { return }
        guard self.voiceResult != nil else { return }
        guard status == .authorized else {
          self.finishVoiceError(
            code: "speech_denied",
            message: "Разрешите AppСтрой распознавание речи и повторите."
          )
          return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
          DispatchQueue.main.async {
            guard let self else { return }
            guard self.voiceResult != nil else { return }
            guard granted else {
              self.finishVoiceError(
                code: "microphone_denied",
                message: "Разрешите AppСтрой доступ к микрофону и повторите."
              )
              return
            }
            self.startTaskSpeech(locale: locale)
          }
        }
      }
    }
  }

  private func startTaskSpeech(locale: String) {
    stopVoiceResources()
    latestTranscript = ""

    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
    guard let recognizer, recognizer.isAvailable else {
      finishVoiceError(
        code: "speech_unavailable",
        message: "На iPhone сейчас недоступно распознавание речи."
      )
      return
    }
    speechRecognizer = recognizer

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    recognitionRequest = request

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement)
      try session.setActive(true)

      let inputNode = audioEngine.inputNode
      let format = inputNode.outputFormat(forBus: 0)
      guard format.sampleRate > 0 else {
        finishVoiceError(code: "microphone_unavailable", message: "Микрофон недоступен.")
        return
      }
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        request.append(buffer)
      }
      hasAudioTap = true
      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      finishVoiceError(code: "microphone_failed", message: "Не удалось запустить микрофон.")
      return
    }

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] speechResult, error in
      DispatchQueue.main.async {
        guard let self, self.voiceResult != nil else { return }
        if let speechResult {
          let text = speechResult.bestTranscription.formattedString.trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          if !text.isEmpty {
            self.latestTranscript = text
          }
          if speechResult.isFinal {
            if self.latestTranscript.isEmpty {
              self.finishVoiceError(
                code: "empty_speech",
                message: "Речь не распознана. Попробуйте сказать задачу ещё раз."
              )
            } else {
              self.finishVoiceSuccess(self.latestTranscript)
            }
            return
          }
        }
        if error != nil {
          if self.latestTranscript.isEmpty {
            self.finishVoiceError(
              code: "speech_failed",
              message: "Не удалось распознать голос. Попробуйте ещё раз."
            )
          } else {
            self.finishVoiceSuccess(self.latestTranscript)
          }
        }
      }
    }

    let timeout = DispatchWorkItem { [weak self] in
      guard let self, self.voiceResult != nil else { return }
      if self.latestTranscript.isEmpty {
        self.finishVoiceError(code: "speech_timeout", message: "Не услышал задачу. Попробуйте ещё раз.")
      } else {
        self.finishVoiceSuccess(self.latestTranscript)
      }
    }
    voiceTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
  }

  private func finishVoiceSuccess(_ text: String) {
    guard let result = voiceResult else { return }
    voiceResult = nil
    stopVoiceResources()
    result(text)
  }

  private func finishVoiceError(code: String, message: String) {
    guard let result = voiceResult else { return }
    voiceResult = nil
    stopVoiceResources()
    result(FlutterError(code: code, message: message, details: nil))
  }

  private func stopVoiceResources() {
    voiceTimeout?.cancel()
    voiceTimeout = nil
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionRequest = nil
    speechRecognizer = nil

    if audioEngine.isRunning {
      audioEngine.stop()
    }
    if hasAudioTap {
      audioEngine.inputNode.removeTap(onBus: 0)
      hasAudioTap = false
    }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
