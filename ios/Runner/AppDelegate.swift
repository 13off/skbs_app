import AVFoundation
import Flutter
import PhotosUI
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let taskVoiceChannelName = "ru.appstroy.skbs/task_voice"
  private let taskPhotoChannelName = "ru.appstroy.skbs/task_photos"
  private let audioEngine = AVAudioEngine()
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var voiceResult: FlutterResult?
  private var voiceTimeout: DispatchWorkItem?
  private var latestTranscript = ""
  private var hasAudioTap = false
  private var photoPickerDelegate: AnyObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "AppStroyNativeFeatures"
    ) else {
      return
    }

    let voiceChannel = FlutterMethodChannel(
      name: taskVoiceChannelName,
      binaryMessenger: registrar.messenger()
    )
    voiceChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizeTask" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let locale = (arguments?["locale"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      self?.requestTaskSpeech(locale: locale?.isEmpty == false ? locale! : "ru-RU", result: result)
    }

    let photoChannel = FlutterMethodChannel(
      name: taskPhotoChannelName,
      binaryMessenger: registrar.messenger()
    )
    photoChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickPhotos" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let maxDimension = (arguments?["maxDimension"] as? NSNumber)?.doubleValue ?? 1440
      let qualityPercent = (arguments?["jpegQuality"] as? NSNumber)?.doubleValue ?? 78
      self?.presentTaskPhotoPicker(
        maxDimension: CGFloat(max(640, min(4096, maxDimension))),
        jpegQuality: CGFloat(max(45, min(95, qualityPercent)) / 100.0),
        result: result
      )
    }
  }

  private func presentTaskPhotoPicker(
    maxDimension: CGFloat,
    jpegQuality: CGFloat,
    result: @escaping FlutterResult
  ) {
    guard photoPickerDelegate == nil else {
      result(FlutterError(code: "photo_busy", message: "Выбор фотографий уже открыт.", details: nil))
      return
    }

    guard #available(iOS 14.0, *) else {
      result(
        FlutterError(
          code: "photo_picker_unavailable",
          message: "Для выбора нескольких фотографий требуется iOS 14 или новее.",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      result(FlutterError(code: "photo_picker_failed", message: "Не удалось открыть медиатеку.", details: nil))
      return
    }

    let delegate = TaskPhotoPickerDelegate(
      maxDimension: maxDimension,
      jpegQuality: jpegQuality
    ) { [weak self] pickerResult in
      DispatchQueue.main.async {
        self?.photoPickerDelegate = nil
        switch pickerResult {
        case .success(let rows):
          result(rows)
        case .failure(let error):
          result(
            FlutterError(
              code: "photo_prepare_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
    photoPickerDelegate = delegate

    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 0
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = delegate
    presenter.present(picker, animated: true)
  }

  private func topViewController(from root: UIViewController? = nil) -> UIViewController? {
    let rootController = root ?? window?.rootViewController
    if let presented = rootController?.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = rootController as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabs = rootController as? UITabBarController {
      return topViewController(from: tabs.selectedViewController)
    }
    return rootController
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

@available(iOS 14.0, *)
private final class TaskPhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
  private let maxDimension: CGFloat
  private let jpegQuality: CGFloat
  private let completion: (Result<[[String: Any]], Error>) -> Void
  private var finished = false

  init(
    maxDimension: CGFloat,
    jpegQuality: CGFloat,
    completion: @escaping (Result<[[String: Any]], Error>) -> Void
  ) {
    self.maxDimension = maxDimension
    self.jpegQuality = jpegQuality
    self.completion = completion
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard !results.isEmpty else {
      finish(.success([]))
      return
    }
    process(results: results, index: 0, rows: [])
  }

  private func process(
    results: [PHPickerResult],
    index: Int,
    rows: [[String: Any]]
  ) {
    if index >= results.count {
      finish(.success(rows))
      return
    }

    let provider = results[index].itemProvider
    guard provider.canLoadObject(ofClass: UIImage.self) else {
      finish(.failure(TaskPhotoPickerError.unreadable))
      return
    }

    provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
      guard let self, !self.finished else { return }
      if let error {
        self.finish(.failure(error))
        return
      }
      guard let image = object as? UIImage else {
        self.finish(.failure(TaskPhotoPickerError.unreadable))
        return
      }

      do {
        let row = try self.normalizedPhoto(
          image: image,
          suggestedName: provider.suggestedName,
          index: index
        )
        var updatedRows = rows
        updatedRows.append(row)
        self.process(results: results, index: index + 1, rows: updatedRows)
      } catch {
        self.finish(.failure(error))
      }
    }
  }

  private func normalizedPhoto(
    image: UIImage,
    suggestedName: String?,
    index: Int
  ) throws -> [String: Any] {
    let sourceWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
    let sourceHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
    guard sourceWidth > 0, sourceHeight > 0 else {
      throw TaskPhotoPickerError.unreadable
    }

    let longestSide = max(sourceWidth, sourceHeight)
    let scale = longestSide > maxDimension ? maxDimension / longestSide : 1
    let targetSize = CGSize(
      width: max(1, (sourceWidth * scale).rounded()),
      height: max(1, (sourceHeight * scale).rounded())
    )
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let normalized = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: targetSize))
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    guard let data = normalized.jpegData(compressionQuality: jpegQuality), !data.isEmpty else {
      throw TaskPhotoPickerError.encodeFailed
    }

    let cleanSuggested = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let sourceName = cleanSuggested.isEmpty ? "photo_\(index + 1)" : cleanSuggested
    let baseName = (sourceName as NSString).deletingPathExtension
    return [
      "name": "\(baseName.isEmpty ? "photo_\(index + 1)" : baseName).jpg",
      "contentType": "image/jpeg",
      "extension": "jpg",
      "bytes": FlutterStandardTypedData(bytes: data),
    ]
  }

  private func finish(_ result: Result<[[String: Any]], Error>) {
    guard !finished else { return }
    finished = true
    completion(result)
  }
}

private enum TaskPhotoPickerError: LocalizedError {
  case unreadable
  case encodeFailed

  var errorDescription: String? {
    switch self {
    case .unreadable:
      return "Не удалось открыть выбранную фотографию."
    case .encodeFailed:
      return "Не удалось подготовить фотографию для загрузки."
    }
  }
}
