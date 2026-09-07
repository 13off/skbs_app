import BackgroundTasks
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

final class OfflineBackgroundSyncWakeCoordinator: NSObject, URLSessionDownloadDelegate {
  static let shared = OfflineBackgroundSyncWakeCoordinator()
  static let channelName = "ru.appstroy.skbs/offline_background_sync"

  private let probeTaskMarker = "appstroy-offline-sync-network-wake"
  private let nativeDiagnosticKey = "flutter.appstroy_background_sync_native_last_event"

  private var prepared = false
  private var foregroundChannel: FlutterMethodChannel?
  private var headlessEngine: FlutterEngine?
  private var headlessChannel: FlutterMethodChannel?
  private var wakeTimeout: DispatchWorkItem?
  private var wakeInFlight = false
  private var lastProbeURL: URL?
  private var processingTask: BGProcessingTask?
  private var backgroundSessionCompletionHandler: (() -> Void)?
  private var sessionEventsFinished = false
  private var executionBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  private var bundleIdentifier: String {
    Bundle.main.bundleIdentifier ?? "ru.appstroy.mobile"
  }

  private var processingIdentifier: String {
    "\(bundleIdentifier).offlineSync"
  }

  private var backgroundSessionIdentifier: String {
    "\(bundleIdentifier).offlineSync.transport"
  }

  private lazy var backgroundSession: URLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: backgroundSessionIdentifier
    )
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.allowsCellularAccess = true
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
    if #available(iOS 13.0, *) {
      configuration.allowsExpensiveNetworkAccess = true
      configuration.allowsConstrainedNetworkAccess = true
    }
    let queue = OperationQueue()
    queue.name = "ru.appstroy.skbs.offline-background-session"
    queue.maxConcurrentOperationCount = 1
    return URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
  }()

  private override init() {
    super.init()
  }

  func prepare() {
    guard !prepared else { return }
    prepared = true

    // Reconnect to a background URLSession created by an earlier app process.
    _ = backgroundSession

    if #available(iOS 13.0, *) {
      let registered = BGTaskScheduler.shared.register(
        forTaskWithIdentifier: processingIdentifier,
        using: nil
      ) { [weak self] task in
        guard let self, let processing = task as? BGProcessingTask else {
          task.setTaskCompleted(success: false)
          return
        }
        self.handleProcessingTask(processing)
      }
      recordNativeEvent(
        registered
          ? "bg-processing-handler-registered"
          : "bg-processing-handler-registration-rejected"
      )
    }
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    configureNativeHandler(on: channel, isHeadless: false)
    foregroundChannel = channel
    recordNativeEvent("foreground-flutter-channel-attached")
  }

  @discardableResult
  func handleEventsForBackgroundURLSession(
    identifier: String,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard identifier == backgroundSessionIdentifier else { return false }

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        completionHandler()
        return
      }
      self.backgroundSessionCompletionHandler = completionHandler
      self.sessionEventsFinished = false
      _ = self.backgroundSession
      self.recordNativeEvent("background-url-session-relaunched-app")
    }
    return true
  }

  private func configureNativeHandler(
    on channel: FlutterMethodChannel,
    isHeadless: Bool
  ) {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }

      switch call.method {
      case "scheduleWake":
        guard
          let arguments = call.arguments as? [String: Any],
          let probeText = arguments["probeUrl"] as? String,
          let probeURL = URL(string: probeText),
          probeURL.scheme == "https"
        else {
          self.recordNativeEvent("schedule-rejected-invalid-probe-url")
          result(false)
          return
        }
        self.scheduleWake(probeURL: probeURL) { scheduled in
          result(scheduled)
        }

      case "backgroundFlushFinished":
        let arguments = call.arguments as? [String: Any]
        let success = arguments?["success"] as? Bool ?? false
        self.finishWake(success: success)
        result(nil)

      default:
        if isHeadless {
          result(FlutterMethodNotImplemented)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func scheduleWake(
    probeURL: URL,
    completion: @escaping (Bool) -> Void
  ) {
    lastProbeURL = probeURL
    scheduleProcessingFallback(earliestDelay: 15 * 60)

    backgroundSession.getAllTasks { [weak self] tasks in
      guard let self else {
        DispatchQueue.main.async { completion(false) }
        return
      }
      let alreadyPending = tasks.contains {
        $0.taskDescription == self.probeTaskMarker &&
          $0.state != .completed &&
          $0.state != .canceling
      }
      DispatchQueue.main.async {
        if alreadyPending {
          self.recordNativeEvent("background-network-probe-already-pending")
          completion(true)
          return
        }

        var request = URLRequest(
          url: probeURL,
          cachePolicy: .reloadIgnoringLocalCacheData,
          timeoutInterval: 60
        )
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let task = self.backgroundSession.downloadTask(with: request)
        task.taskDescription = self.probeTaskMarker
        task.resume()
        self.recordNativeEvent("background-network-probe-scheduled")
        completion(true)
      }
    }
  }

  private func scheduleProcessingFallback(earliestDelay: TimeInterval) {
    guard #available(iOS 13.0, *) else { return }

    BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
      guard let self else { return }
      if requests.contains(where: { $0.identifier == self.processingIdentifier }) {
        return
      }

      let request = BGProcessingTaskRequest(identifier: self.processingIdentifier)
      request.requiresNetworkConnectivity = true
      request.requiresExternalPower = false
      request.earliestBeginDate = Date(timeIntervalSinceNow: earliestDelay)
      do {
        try BGTaskScheduler.shared.submit(request)
        self.recordNativeEvent("bg-processing-fallback-scheduled")
      } catch {
        self.recordNativeEvent("bg-processing-fallback-error:\(error.localizedDescription)")
      }
    }
  }

  private func handleProcessingTask(_ task: BGProcessingTask) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        task.setTaskCompleted(success: false)
        return
      }
      self.processingTask = task
      self.recordNativeEvent("bg-processing-fallback-started")
      task.expirationHandler = { [weak self, weak task] in
        DispatchQueue.main.async {
          self?.recordNativeEvent("bg-processing-fallback-expired")
          task?.setTaskCompleted(success: false)
          if self?.processingTask === task {
            self?.processingTask = nil
          }
          self?.finishWake(success: false, completeProcessingTask: false)
        }
      }
      self.triggerDartFlush(source: "bg-processing")
    }
  }

  private func triggerDartFlush(source: String) {
    if wakeInFlight {
      recordNativeEvent("dart-flush-already-running:\(source)")
      return
    }

    wakeInFlight = true
    beginExecutionBackgroundTask()
    recordNativeEvent("dart-flush-start:\(source)")

    let timeout = DispatchWorkItem { [weak self] in
      guard let self, self.wakeInFlight else { return }
      self.recordNativeEvent("dart-flush-timeout")
      self.finishWake(success: false)
    }
    wakeTimeout?.cancel()
    wakeTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 28, execute: timeout)

    if let channel = foregroundChannel {
      channel.invokeMethod(
        "networkWake",
        arguments: ["source": source]
      ) { [weak self] response in
        DispatchQueue.main.async {
          guard let self, self.wakeInFlight else { return }
          if let success = response as? Bool {
            self.finishWake(success: success)
          } else {
            self.recordNativeEvent("foreground-dart-wake-unavailable")
            self.startHeadlessFlush()
          }
        }
      }
      return
    }

    startHeadlessFlush()
  }

  private func startHeadlessFlush() {
    if headlessEngine != nil { return }

    let engine = FlutterEngine(
      name: "appstroy-offline-background-sync",
      project: nil,
      allowHeadlessExecution: true
    )
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: engine.binaryMessenger
    )
    configureNativeHandler(on: channel, isHeadless: true)
    headlessEngine = engine
    headlessChannel = channel

    guard engine.run(withEntrypoint: "iosBackgroundNetworkWakeMain") else {
      recordNativeEvent("headless-flutter-engine-start-failed")
      headlessChannel?.setMethodCallHandler(nil)
      headlessChannel = nil
      headlessEngine = nil
      finishWake(success: false)
      return
    }

    GeneratedPluginRegistrant.register(with: engine)
    recordNativeEvent("headless-flutter-engine-started")
  }

  private func finishWake(
    success: Bool,
    completeProcessingTask: Bool = true
  ) {
    guard wakeInFlight || processingTask != nil || headlessEngine != nil else {
      completeBackgroundSessionEventsIfPossible()
      return
    }

    wakeTimeout?.cancel()
    wakeTimeout = nil
    wakeInFlight = false

    recordNativeEvent(success ? "dart-flush-success" : "dart-flush-failed")

    if completeProcessingTask, let task = processingTask {
      task.expirationHandler = nil
      task.setTaskCompleted(success: success)
      processingTask = nil
    }

    headlessChannel?.setMethodCallHandler(nil)
    headlessChannel = nil
    headlessEngine = nil
    endExecutionBackgroundTask()

    if #available(iOS 13.0, *) {
      if success {
        BGTaskScheduler.shared.cancel(
          taskRequestWithIdentifier: processingIdentifier
        )
      } else {
        scheduleProcessingFallback(earliestDelay: 5 * 60)
      }
    }

    completeBackgroundSessionEventsIfPossible()
  }

  private func beginExecutionBackgroundTask() {
    guard executionBackgroundTask == .invalid else { return }
    executionBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "AppStroyOfflineQueueFlush"
    ) { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        self.recordNativeEvent("ui-background-time-expired")
        self.finishWake(success: false)
      }
    }
  }

  private func endExecutionBackgroundTask() {
    guard executionBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(executionBackgroundTask)
    executionBackgroundTask = .invalid
  }

  private func completeBackgroundSessionEventsIfPossible() {
    guard
      sessionEventsFinished,
      !wakeInFlight,
      let completion = backgroundSessionCompletionHandler
    else {
      return
    }

    backgroundSessionCompletionHandler = nil
    sessionEventsFinished = false
    DispatchQueue.main.async {
      completion()
    }
  }

  private func recordNativeEvent(_ event: String) {
    UserDefaults.standard.set(
      "\(Date().timeIntervalSince1970):\(event)",
      forKey: nativeDiagnosticKey
    )
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    // The response body is irrelevant; receiving it is only the durable signal
    // that iOS managed to reach the backend after connectivity returned.
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard task.taskDescription == probeTaskMarker else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if let error {
        self.recordNativeEvent("background-network-probe-error:\(error.localizedDescription)")
        self.scheduleProcessingFallback(earliestDelay: 5 * 60)
        self.completeBackgroundSessionEventsIfPossible()
        return
      }

      self.recordNativeEvent("background-network-probe-complete")
      self.triggerDartFlush(source: "background-url-session")
    }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.sessionEventsFinished = true
      self.recordNativeEvent("background-url-session-events-finished")
      self.completeBackgroundSessionEventsIfPossible()
    }
  }
}
