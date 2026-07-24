import 'pwa_install_service_stub.dart'
    if (dart.library.html) 'pwa_install_service_web.dart'
    as implementation;

class PwaInstallService {
  const PwaInstallService._();

  static bool get isSupported => implementation.isSupported;

  static bool get isInstalled => implementation.isInstalled;

  static bool get canPrompt => implementation.canPrompt;

  static String get browserName => implementation.browserName;

  static bool get isYandexBrowser => implementation.isYandexBrowser;

  static String get platformName => implementation.platformName;

  static String get manualInstruction => implementation.manualInstruction;

  static Future<String> install() => implementation.install();
}
