import 'dart:convert';
import 'dart:js_interop';

@JS('appstroyWebPushStatus')
external JSString _webPushStatus();

@JS('appstroyWebPushExisting')
external JSPromise<JSString> _webPushExisting();

@JS('appstroyWebPushSubscribe')
external JSPromise<JSString> _webPushSubscribe(JSString publicKey);

@JS('appstroyWebPushUnsubscribe')
external JSPromise<JSString> _webPushUnsubscribe();

class WebPushBridge {
  WebPushBridge._();

  static Map<String, dynamic> _decode(String value) {
    if (value.trim().isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> get status => _decode(_webPushStatus().toDart);

  static bool get isSupported => status['supported'] == true;
  static bool get isStandalone => status['standalone'] == true;
  static String get permission => status['permission']?.toString() ?? 'default';

  static Future<Map<String, dynamic>> existing() async {
    final value = await _webPushExisting().toDart;
    return _decode(value.toDart);
  }

  static Future<Map<String, dynamic>> subscribe(String publicKey) async {
    final value = await _webPushSubscribe(publicKey.toJS).toDart;
    return _decode(value.toDart);
  }

  static Future<Map<String, dynamic>> unsubscribe() async {
    final value = await _webPushUnsubscribe().toDart;
    return _decode(value.toDart);
  }
}
