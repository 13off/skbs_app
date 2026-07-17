import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class WebPushBridge {
  WebPushBridge._();

  static const String _workerPath = 'appstroy-push-sw.js';
  static const String _workerScope = 'push-scope/';
  static const String _publicKeyEndpoint =
      'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/web-push-public-key';

  static bool get _hasServiceWorker =>
      js_util.hasProperty(html.window.navigator, 'serviceWorker');

  static bool get _hasPushManager =>
      js_util.hasProperty(html.window, 'PushManager');

  static bool get _hasNotification =>
      js_util.hasProperty(html.window, 'Notification');

  static bool get isSupported =>
      html.window.isSecureContext == true &&
      _hasServiceWorker &&
      _hasPushManager &&
      _hasNotification;

  static bool get isStandalone {
    final mediaStandalone =
        html.window.matchMedia('(display-mode: standalone)').matches;
    final navigatorStandalone =
        js_util.getProperty<Object?>(html.window.navigator, 'standalone') == true;
    return mediaStandalone || navigatorStandalone;
  }

  static String get permission {
    if (!_hasNotification) return 'unsupported';
    return html.Notification.permission ?? 'default';
  }

  static bool get _isAppleMobile {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return userAgent.contains('iphone') || userAgent.contains('ipad');
  }

  static Map<String, dynamic> get status => <String, dynamic>{
        'supported': isSupported,
        'standalone': isStandalone,
        'permission': permission,
        'requires_home_screen': _isAppleMobile && !isStandalone,
      };

  static Future<html.ServiceWorkerRegistration> _registration() async {
    if (!isSupported) {
      throw UnsupportedError('Стандартный Web Push не поддерживается');
    }
    final container = html.window.navigator.serviceWorker;
    if (container == null) {
      throw UnsupportedError('Service Worker недоступен');
    }
    return container.register(_workerPath, scope: _workerScope);
  }

  static Future<Object?> _currentSubscription(
    html.ServiceWorkerRegistration registration,
  ) async {
    final pushManager = js_util.getProperty<Object>(registration, 'pushManager');
    final promise = js_util.callMethod<Object>(
      pushManager,
      'getSubscription',
      const <Object>[],
    );
    return js_util.promiseToFuture<Object?>(promise);
  }

  static Map<String, dynamic> _subscriptionMap(Object subscription) {
    final jsonValue = js_util.callMethod<Object>(
      subscription,
      'toJSON',
      const <Object>[],
    );
    final dartValue = js_util.dartify(jsonValue);
    if (dartValue is Map) {
      return Map<String, dynamic>.from(dartValue);
    }
    return const <String, dynamic>{};
  }

  static Object _applicationServerKey(String publicKey) {
    final normalized = publicKey.padRight(
      publicKey.length + ((4 - publicKey.length % 4) % 4),
      '=',
    );
    final bytes = base64Url.decode(normalized);
    final constructor = js_util.getProperty<Object>(html.window, 'Uint8Array');
    return js_util.callConstructor<Object>(constructor, <Object>[bytes.toList()]);
  }

  static Future<String> _resolvePublicKey(String fallback) async {
    try {
      final raw = await html.HttpRequest.getString(_publicKeyEndpoint);
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final value = decoded['public_key']?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    } catch (_) {
      // На случай краткой недоступности сервера используем ключ сборки.
    }
    return fallback;
  }

  static Future<Map<String, dynamic>> existing() async {
    if (!isSupported) return status;
    if (_isAppleMobile && !isStandalone) return status;
    final registration = await _registration();
    final subscription = await _currentSubscription(registration);
    return <String, dynamic>{
      ...status,
      'registered': subscription != null,
      if (subscription != null) 'subscription': _subscriptionMap(subscription),
      'user_agent': html.window.navigator.userAgent,
    };
  }

  static Future<Map<String, dynamic>> subscribe(String publicKey) async {
    if (!isSupported) return <String, dynamic>{...status, 'status': 'unsupported'};
    if (_isAppleMobile && !isStandalone) {
      return <String, dynamic>{...status, 'status': 'needs_install'};
    }

    var currentPermission = permission;
    if (currentPermission == 'default') {
      currentPermission = await html.Notification.requestPermission();
    }
    if (currentPermission != 'granted') {
      return <String, dynamic>{
        ...status,
        'permission': currentPermission,
        'status': 'denied',
      };
    }

    final registration = await _registration();
    var subscription = await _currentSubscription(registration);
    if (subscription == null) {
      final resolvedPublicKey = await _resolvePublicKey(publicKey);
      final pushManager = js_util.getProperty<Object>(registration, 'pushManager');
      final options = js_util.newObject();
      js_util.setProperty(options, 'userVisibleOnly', true);
      js_util.setProperty(
        options,
        'applicationServerKey',
        _applicationServerKey(resolvedPublicKey),
      );
      final promise = js_util.callMethod<Object>(
        pushManager,
        'subscribe',
        <Object>[options],
      );
      subscription = await js_util.promiseToFuture<Object>(promise);
    }

    return <String, dynamic>{
      ...status,
      'permission': currentPermission,
      'registered': true,
      'status': 'subscribed',
      'subscription': _subscriptionMap(subscription),
      'user_agent': html.window.navigator.userAgent,
    };
  }

  static Future<Map<String, dynamic>> unsubscribe() async {
    if (!isSupported) return status;
    final registration = await _registration();
    final subscription = await _currentSubscription(registration);
    if (subscription != null) {
      final promise = js_util.callMethod<Object>(
        subscription,
        'unsubscribe',
        const <Object>[],
      );
      await js_util.promiseToFuture<Object?>(promise);
    }
    return <String, dynamic>{...status, 'registered': false};
  }
}
