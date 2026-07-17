import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

@JS('navigator')
external JSObject get _navigator;

@JS('Notification')
external JSObject get _notification;

@JS('Uint8Array')
external JSFunction get _uint8ArrayConstructor;

class WebPushBridge {
  WebPushBridge._();

  static const String _workerPath = 'appstroy-push-sw.js';
  static const String _workerScope = 'push-scope/';
  static const String _publicKeyEndpoint = 'appstroy-push-config.json';

  static bool get _hasServiceWorker => _navigator.has('serviceWorker');
  static bool get _hasPushManager => _window.has('PushManager');
  static bool get _hasNotification => _window.has('Notification');

  static bool get isSupported {
    final secure = _window.has('isSecureContext') &&
        _window
            .getProperty<JSBoolean>('isSecureContext'.toJS)
            .toDart;
    return secure &&
        _hasServiceWorker &&
        _hasPushManager &&
        _hasNotification;
  }

  static bool get isStandalone {
    final media = _window.callMethod<JSObject>(
      'matchMedia'.toJS,
      '(display-mode: standalone)'.toJS,
    );
    final mediaStandalone = media.getProperty<JSBoolean>('matches'.toJS).toDart;
    final navigatorStandalone = _navigator.has('standalone') &&
        _navigator.getProperty<JSBoolean>('standalone'.toJS).toDart;
    return mediaStandalone || navigatorStandalone;
  }

  static String get permission {
    if (!_hasNotification) return 'unsupported';
    return _notification.getProperty<JSString>('permission'.toJS).toDart;
  }

  static String get _userAgent =>
      _navigator.getProperty<JSString>('userAgent'.toJS).toDart;

  static bool get _isAppleMobile {
    final userAgent = _userAgent.toLowerCase();
    return userAgent.contains('iphone') || userAgent.contains('ipad');
  }

  static Map<String, dynamic> get status => <String, dynamic>{
        'supported': isSupported,
        'standalone': isStandalone,
        'permission': permission,
        'requires_home_screen': _isAppleMobile && !isStandalone,
      };

  static Future<JSObject> _registration() async {
    if (!isSupported) {
      throw UnsupportedError('Стандартный Web Push не поддерживается');
    }
    final container = _navigator.getProperty<JSObject>('serviceWorker'.toJS);
    final options = JSObject()..setProperty('scope'.toJS, _workerScope.toJS);
    final promise = container.callMethod<JSPromise<JSObject>>(
      'register'.toJS,
      _workerPath.toJS,
      options,
    );
    return promise.toDart;
  }

  static Future<JSObject?> _currentSubscription(JSObject registration) async {
    final pushManager = registration.getProperty<JSObject>('pushManager'.toJS);
    final promise = pushManager.callMethod<JSPromise<JSAny?>>(
      'getSubscription'.toJS,
    );
    final value = await promise.toDart;
    return value == null ? null : value as JSObject;
  }

  static Map<String, dynamic> _subscriptionMap(JSObject subscription) {
    final jsonValue = subscription.callMethod<JSObject>('toJSON'.toJS);
    final keys = jsonValue.getProperty<JSObject>('keys'.toJS);
    return <String, dynamic>{
      'endpoint': jsonValue.getProperty<JSString>('endpoint'.toJS).toDart,
      'expirationTime': null,
      'keys': <String, dynamic>{
        'p256dh': keys.getProperty<JSString>('p256dh'.toJS).toDart,
        'auth': keys.getProperty<JSString>('auth'.toJS).toDart,
      },
    };
  }

  static JSObject _applicationServerKey(String publicKey) {
    final normalized = publicKey.padRight(
      publicKey.length + ((4 - publicKey.length % 4) % 4),
      '=',
    );
    final bytes = base64Url.decode(normalized);
    final values = bytes.map((value) => value.toJS).toList().toJS;
    return _uint8ArrayConstructor.callAsConstructor<JSObject>(values);
  }

  static Future<String> _resolvePublicKey(String fallback) async {
    try {
      final fetchPromise = _window.callMethod<JSPromise<JSObject>>(
        'fetch'.toJS,
        _publicKeyEndpoint.toJS,
        (JSObject()..setProperty('cache'.toJS, 'no-store'.toJS)),
      );
      final response = await fetchPromise.toDart;
      final jsonPromise = response.callMethod<JSPromise<JSObject>>('json'.toJS);
      final payload = await jsonPromise.toDart;
      if (payload.has('public_key')) {
        final value = payload.getProperty<JSString>('public_key'.toJS).toDart.trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {
      // На случай краткой недоступности конфигурации используем ключ сборки.
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
      'user_agent': _userAgent,
    };
  }

  static Future<Map<String, dynamic>> subscribe(String publicKey) async {
    if (!isSupported) {
      return <String, dynamic>{...status, 'status': 'unsupported'};
    }
    if (_isAppleMobile && !isStandalone) {
      return <String, dynamic>{...status, 'status': 'needs_install'};
    }

    var currentPermission = permission;
    if (currentPermission == 'default') {
      final promise = _notification.callMethod<JSPromise<JSString>>(
        'requestPermission'.toJS,
      );
      currentPermission = (await promise.toDart).toDart;
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
      final pushManager = registration.getProperty<JSObject>('pushManager'.toJS);
      final options = JSObject()
        ..setProperty('userVisibleOnly'.toJS, true.toJS)
        ..setProperty(
          'applicationServerKey'.toJS,
          _applicationServerKey(resolvedPublicKey),
        );
      final promise = pushManager.callMethod<JSPromise<JSObject>>(
        'subscribe'.toJS,
        options,
      );
      subscription = await promise.toDart;
    }

    return <String, dynamic>{
      ...status,
      'permission': currentPermission,
      'registered': true,
      'status': 'subscribed',
      'subscription': _subscriptionMap(subscription),
      'user_agent': _userAgent,
    };
  }

  static Future<Map<String, dynamic>> unsubscribe() async {
    if (!isSupported) return status;
    final registration = await _registration();
    final subscription = await _currentSubscription(registration);
    if (subscription != null) {
      final promise = subscription.callMethod<JSPromise<JSBoolean>>(
        'unsubscribe'.toJS,
      );
      await promise.toDart;
    }
    return <String, dynamic>{...status, 'registered': false};
  }
}
