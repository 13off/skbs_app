import 'dart:js_interop';

@JS('appstroyApplyTheme')
external void _appstroyApplyTheme(JSString mode);

Future<void> applyTheme({required bool isDark}) async {
  try {
    _appstroyApplyTheme((isDark ? 'dark' : 'light').toJS);
  } catch (_) {
    // Веб-обвязка не должна блокировать применение темы внутри Flutter.
  }
}
