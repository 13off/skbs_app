import 'dart:async';
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
  static const String _canonicalPublicKey =
      'BEDeIMiSvfz3KavkGnr8UKRZkfE0Ix3PmG8HGNWcm20b70Zh_cWBmNR3crMxi5nYHk4KHbf_frABXuQDontdYn8';

  static const Duration _workerTimeout = Duration(seconds: 12);
  static const Duration _subscriptionTimeout = Duration(seconds: 20);
  static const Duration _permissionTimeout = Duration(seconds: 45);
  static const Duration _configurationTimeout = Duration(seconds: 8);

  static bool get _hasServiceWorker => _navigator.has('serviceWorker');
  static bool get _hasPushManager => _window.has('PushManager');
  static bool get _hasNotification => _window.has('Notification');

  static bool get isSupported {
    final secure =
        _window.has('isSecureContext') &&
        _window.getProperty<JSBoolean>('isSecureContext'.toJS).toDart;
    return secure && _hasServiceWorker && _hasPushManager && _hasNotification;
  }

  static bool get isStandalone {
    final media = _window.callMethod<JSObject>(
      'matchMedia'.toJS,
      '(display-mode: standalone)'.toJS,
    );
    final mediaStandalone = media.getProperty<JSBoolean>('matches'.toJS).toDart;
    final navigatorStandalone =
        _navigator.has('standalone') &&
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

  static Future<T> _bounded<T>(
    Future<T> operation,
    Duration timeout,
    String stage,
  ) {
    return operation.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Web Push не ответил на этапе «$stage»',
        timeout,
      ),
    );
  }

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
    final registration = await _bounded(
      promise.toDart,
      _workerTimeout,
      'запуск службы уведомлений',
    );
    await _waitUntilActive(registration);
    return registration;
  }

  static Future<void> _waitUntilActive(JSObject registration) async {
    final deadline = DateTime.now().add(_workerTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final active = registration.getProperty<JSAny?>('active'.toJS);
      if (active != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    throw TimeoutException(
      'Служба уведомлений не успела запуститься',
      _workerTimeout,
    );
  }

  static Future<JSObject?> _currentSubscription(JSObject registration) async {
    final pushManager = registration.getProperty<JSObject>('pushManager'.toJS);
    final promise = pushManager.callMethod<JSPromise<JSAny?>>(
      'getSubscription'.toJS,
    );
    final value = await _bounded(
      promise.toDart,
      _workerTimeout,
      'проверка подписки',
    );
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
      final response = await _bounded(
        fetchPromise.toDart,
        _configurationTimeout,
        'получение ключа',
      );
      final jsonPromise = response.callMethod<JSPromise<JSObject>>('json'.toJS);
      final payload = await _bounded(
        jsonPromise.toDart,
        _configurationTimeout,
        'чтение ключа',
      );
      if (payload.has('public_key')) {
        final value = payload
            .getProperty<JSString>('public_key'.toJS)
            .toDart
            .trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {
      // Ключ в PWA может быть временно недоступен при обновлении/плохой сети.
    }

    // Старые сборки содержали другой fallback. Никогда не создаём новую
    // подписку с ним: сервер подписывает Web Push только этим VAPID-ключом.
    return fallback == _canonicalPublicKey ? fallback : _canonicalPublicKey;
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
      currentPermission = (await _bounded(
        promise.toDart,
        _permissionTimeout,
        'разрешение уведомлений',
      ))
          .toDart;
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

    // Ручное «Разрешить и подключить / Обновить регистрацию» всегда пересоздаёт
    // браузерную подписку. Это автоматически лечит устройства, которые успели
    // подписаться на старый VAPID-ключ.
    if (subscription != null) {
      final unsubscribePromise = subscription.callMethod<JSPromise<JSBoolean>>(
        'unsubscribe'.toJS,
      );
      await _bounded(
        unsubscribePromise.toDart,
        _workerTimeout,
        'обновление старой подписки',
      );
      subscription = null;
    }

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
    subscription = await _bounded(
      promise.toDart,
      _subscriptionTimeout,
      'создание подписки',
    );

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
      await _bounded(
        promise.toDart,
        _workerTimeout,
        'отключение подписки',
      );
    }
    return <String, dynamic>{...status, 'registered': false};
  }
}
