import 'theme_platform_sync_stub.dart'
    if (dart.library.html) 'theme_platform_sync_web.dart'
    if (dart.library.io) 'theme_platform_sync_io.dart' as implementation;

abstract final class AppThemePlatformSync {
  static Future<void> apply({required bool isDark}) {
    return implementation.applyTheme(isDark: isDark);
  }
}
