import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_data_sync.dart';
import 'web_push_bridge.dart';

enum PushPermissionState {
  unknown,
  notDetermined,
  denied,
  authorized,
  provisional,
}

class PushNotificationSnapshot {
  final bool configured;
  final bool enabled;
  final bool registered;
  final bool busy;
  final PushPermissionState permission;
  final String message;

  const PushNotificationSnapshot({
    required this.configured,
    required this.enabled,
    required this.registered,
    required this.busy,
    required this.permission,
    required this.message,
  });

  static const initial = PushNotificationSnapshot(
    configured: false,
    enabled: true,
    registered: false,
    busy: false,
    permission: PushPermissionState.unknown,
    message: 'Push-уведомления ещё не проверены',
  );
}

class PushNavigationRequest {
  final String? notificationId;
  final String? entityType;
  final String? entityId;

  const PushNavigationRequest({
    this.notificationId,
    this.entityType,
    this.entityId,
  });
}

class FirebaseRuntimeConfiguration {
  FirebaseRuntimeConfiguration._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static String get currentAppId {
    if (kIsWeb) return webAppId;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidAppId;
      case TargetPlatform.iOS:
        return iosAppId;
      default:
        return '';
    }
  }

  static bool get isConfigured {
    return apiKey.isNotEmpty &&
        projectId.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        currentAppId.isNotEmpty &&
        (!kIsWeb || vapidKey.isNotEmpty);
  }

  static FirebaseOptions? get options {
    if (!isConfigured) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: currentAppId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? 'ru.appstroy.mobile'
          : null,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = FirebaseRuntimeConfiguration.options;
  if (options == null) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static const _deviceIdKey = 'appstroy_push_device_id';
  static const _enabledKey = 'appstroy_push_enabled';
  static const _webPushPublicKey =
      'BMozm-Z22RK4cHcHgiGd8JdbIiOPdRgpHdC7_wG7HpF4UvKCQ5vQmN4HbjXyE8SX2PVrsqfS31BnvY0I21h4CxY';

  static final ValueNotifier<PushNotificationSnapshot> state =
      ValueNotifier<PushNotificationSnapshot>(PushNotificationSnapshot.initial);
  static final ValueNotifier<PushNavigationRequest?> navigationRequest =
      ValueNotifier<PushNavigationRequest?>(null);

  static bool _initialized = false;
  static Future<void>? _webSyncInFlight;
  static bool _webSyncInFlightRequestsPermission = false;
  static Future<void>? _webRegistrationInFlight;
  static String _webRegistrationEndpoint = '';
  static final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  static SupabaseClient get _client => Supabase.instance.client;
  static bool get _isConfigured =>
      kIsWeb ? WebPushBridge.isSupported : FirebaseRuntimeConfiguration.isConfigured;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_enabledKey) ?? true;

    _subscriptions.add(
      _client.auth.onAuthStateChange.listen((authState) {
        if (authState.event == AuthChangeEvent.signedOut) {
          _publish(
            configured: _isConfigured,
            enabled: enabled,
            registered: false,
            permission: state.value.permission,
            message: 'Войдите, чтобы подключить push-уведомления',
          );
          return;
        }
        if (authState.event == AuthChangeEvent.signedIn ||
            authState.event == AuthChangeEvent.tokenRefreshed ||
            authState.event == AuthChangeEvent.userUpdated ||
            authState.event == AuthChangeEvent.initialSession) {
          unawaited(syncForCurrentSession());
        }
      }),
    );

    if (kIsWeb) {
      await _initializeWebPush(enabled);
      return;
    }

    final options = FirebaseRuntimeConfiguration.options;
    if (options == null) {
      _publish(
        configured: false,
        enabled: enabled,
        registered: false,
        permission: PushPermissionState.unknown,
        message: 'Нужно добавить публичную конфигурацию Firebase',
      );
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen(
          (token) => unawaited(_registerToken(token)),
        ),
      );

      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      _publish(
        configured: true,
        enabled: enabled,
        registered: false,
        permission: _mapPermission(settings.authorizationStatus),
        message: enabled
            ? 'Push-сервис готов к регистрации устройства'
            : 'Push-уведомления отключены на этом устройстве',
      );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      if (_client.auth.currentUser != null && enabled) {
        unawaited(syncForCurrentSession());
      }
    } catch (error) {
      _publish(
        configured: true,
        enabled: enabled,
        registered: false,
        permission: PushPermissionState.unknown,
        message: 'Push временно недоступен: $error',
      );
    }
  }

  static Future<void> _initializeWebPush(bool enabled) async {
    final browserStatus = WebPushBridge.status;
    final permission = _mapWebPermission(
      browserStatus['permission']?.toString() ?? 'default',
    );
    if (!WebPushBridge.isSupported) {
      _publish(
        configured: false,
        enabled: enabled,
        registered: false,
        permission: permission,
        message: browserStatus['requires_home_screen'] == true
            ? 'На iPhone сначала добавьте AppСтрой на экран «Домой»'
            : 'Этот браузер не поддерживает системные Web Push',
      );
      return;
    }

    if (!enabled) {
      _publish(
        configured: true,
        enabled: false,
        registered: false,
        permission: permission,
        message: 'Push-уведомления отключены на этом устройстве',
      );
      return;
    }

    try {
      final existing = await WebPushBridge.existing();
      final registered = existing['registered'] == true;
      if (registered && _client.auth.currentUser != null) {
        await _registerWebSubscription(existing);
      }
      _publish(
        configured: true,
        enabled: true,
        registered: registered,
        permission: _mapWebPermission(
          existing['permission']?.toString() ?? 'default',
        ),
        message: registered
            ? 'Устройство подключено к push-уведомлениям'
            : 'Нажмите «Разрешить и подключить»',
      );
    } catch (error) {
      _publish(
        configured: true,
        enabled: true,
        registered: false,
        permission: permission,
        message: 'Web Push временно недоступен: $error',
      );
    }
  }

  static Future<void> syncForCurrentSession({
    bool requestPermission = false,
  }) async {
    if (_client.auth.currentUser == null) return;
    if (kIsWeb) {
      await _syncWebPushSerialized(requestPermission: requestPermission);
      return;
    }
    if (!FirebaseRuntimeConfiguration.isConfigured) return;

    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_enabledKey) ?? true;
    if (!enabled) {
      _publish(
        configured: true,
        enabled: false,
        registered: false,
        permission: state.value.permission,
        message: 'Push-уведомления отключены на этом устройстве',
      );
      return;
    }

    _publish(
      configured: true,
      enabled: true,
      registered: state.value.registered,
      permission: state.value.permission,
      busy: true,
      message: 'Проверяем разрешение и токен устройства…',
    );

    try {
      var settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (requestPermission &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }

      final permission = _mapPermission(settings.authorizationStatus);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _publish(
          configured: true,
          enabled: true,
          registered: false,
          permission: permission,
          message: 'Разрешение на уведомления отключено в системе',
        );
        return;
      }
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        _publish(
          configured: true,
          enabled: true,
          registered: false,
          permission: permission,
          message: 'Нужно разрешить уведомления на этом устройстве',
        );
        return;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (var attempt = 0; attempt < 6 && apnsToken == null; attempt += 1) {
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken == null) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
        }
        if (apnsToken == null) {
          _publish(
            configured: true,
            enabled: true,
            registered: false,
            permission: permission,
            message: 'iPhone ещё получает APNs-токен. Повторите проверку.',
          );
          return;
        }
      }

      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? FirebaseRuntimeConfiguration.vapidKey : null,
        serviceWorkerScriptPath: kIsWeb
            ? 'firebase-messaging-sw.js'
            : null,
      );
      if (token == null || token.trim().isEmpty) {
        _publish(
          configured: true,
          enabled: true,
          registered: false,
          permission: permission,
          message: 'Firebase не вернул токен устройства',
        );
        return;
      }

      await _registerToken(token, permission: permission);
    } catch (error) {
      _publish(
        configured: true,
        enabled: true,
        registered: false,
        permission: state.value.permission,
        message: 'Не удалось зарегистрировать устройство: $error',
      );
    }
  }

  static Future<void> _syncWebPushSerialized({
    required bool requestPermission,
  }) async {
    final running = _webSyncInFlight;
    if (running != null) {
      final requestCovered =
          !requestPermission || _webSyncInFlightRequestsPermission;
      await running;
      if (!requestCovered) {
        await _syncWebPushSerialized(requestPermission: true);
      }
      return;
    }

    final operation = _syncWebPush(requestPermission: requestPermission);
    _webSyncInFlight = operation;
    _webSyncInFlightRequestsPermission = requestPermission;
    try {
      await operation;
    } finally {
      if (identical(_webSyncInFlight, operation)) {
        _webSyncInFlight = null;
        _webSyncInFlightRequestsPermission = false;
      }
    }
  }

  static Future<void> _syncWebPush({required bool requestPermission}) async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_enabledKey) ?? true;
    final browserStatus = WebPushBridge.status;

    if (!enabled) {
      _publish(
        configured: WebPushBridge.isSupported,
        enabled: false,
        registered: false,
        permission: _mapWebPermission(
          browserStatus['permission']?.toString() ?? 'default',
        ),
        message: 'Push-уведомления отключены на этом устройстве',
      );
      return;
    }

    if (browserStatus['requires_home_screen'] == true) {
      _publish(
        configured: true,
        enabled: true,
        registered: false,
        permission: PushPermissionState.notDetermined,
        message: 'На iPhone добавьте AppСтрой на экран «Домой» и откройте с иконки',
      );
      return;
    }

    if (!WebPushBridge.isSupported) {
      _publish(
        configured: false,
        enabled: true,
        registered: false,
        permission: PushPermissionState.unknown,
        message: 'Этот браузер не поддерживает системные Web Push',
      );
      return;
    }

    _publish(
      configured: true,
      enabled: true,
      registered: state.value.registered,
      permission: state.value.permission,
      busy: true,
      message: 'Проверяем разрешение и подписку устройства…',
    );

    try {
      final result = requestPermission
          ? await WebPushBridge.subscribe(_webPushPublicKey)
          : await WebPushBridge.existing();
      final permission = _mapWebPermission(
        result['permission']?.toString() ?? 'default',
      );
      final resultStatus = result['status']?.toString() ?? '';

      if (resultStatus == 'needs_install') {
        _publish(
          configured: true,
          enabled: true,
          registered: false,
          permission: permission,
          message: 'На iPhone добавьте AppСтрой на экран «Домой» и откройте с иконки',
        );
        return;
      }
      if (permission == PushPermissionState.denied || resultStatus == 'denied') {
        _publish(
          configured: true,
          enabled: true,
          registered: false,
          permission: PushPermissionState.denied,
          message: 'Разрешение на уведомления отключено в системе',
        );
        return;
      }

      final registered = result['registered'] == true;
      if (!registered) {
        _publish(
          configured: true,
          enabled: true,
          registered: false,
          permission: permission,
          message: requestPermission
              ? 'Браузер не создал подписку Web Push'
              : 'Нажмите «Разрешить и подключить»',
        );
        return;
      }

      await _registerWebSubscription(result);
      _publish(
        configured: true,
        enabled: true,
        registered: true,
        permission: permission,
        message: 'Устройство подключено к push-уведомлениям',
      );
    } catch (error) {
      _publish(
        configured: true,
        enabled: true,
        registered: false,
        permission: state.value.permission,
        message: 'Не удалось зарегистрировать Web Push: $error',
      );
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);

    if (!enabled) {
      try {
        if (_client.auth.currentUser != null) {
          if (kIsWeb) {
            await WebPushBridge.unsubscribe();
            await _manageWebDevice(<String, dynamic>{
              'action': 'unregister',
              'device_id': await _deviceId(),
            });
          } else {
            await _manageDevice(<String, dynamic>{
              'action': 'set_enabled',
              'device_id': await _deviceId(),
              'enabled': false,
            });
          }
        }
      } catch (_) {
        // Настройка push не должна влиять на рабочие функции приложения.
      }
      _publish(
        configured: _isConfigured,
        enabled: false,
        registered: false,
        permission: state.value.permission,
        message: 'Push-уведомления отключены на этом устройстве',
      );
      return;
    }

    await syncForCurrentSession(requestPermission: true);
  }

  static Future<void> unregisterCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      if (kIsWeb) {
        await WebPushBridge.unsubscribe();
        await _manageWebDevice(<String, dynamic>{
          'action': 'unregister',
          'device_id': await _deviceId(),
        });
      } else {
        await _manageDevice(<String, dynamic>{
          'action': 'unregister',
          'device_id': await _deviceId(),
        });
      }
    } catch (_) {
      // Выход из аккаунта продолжится даже при недоступности push-сервиса.
    }

    if (!kIsWeb && FirebaseRuntimeConfiguration.isConfigured) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        // Серверная запись уже удалена; ошибка Firebase не блокирует выход.
      }
    }

    _publish(
      configured: _isConfigured,
      enabled: state.value.enabled,
      registered: false,
      permission: state.value.permission,
      message: 'Устройство отключено от push-уведомлений',
    );
  }

  static Future<void> dispatchNotification(String notificationId) async {
    if (notificationId.trim().isEmpty || _client.auth.currentUser == null) {
      return;
    }
    try {
      await _client.functions.invoke(
        'dispatch-push-notification',
        body: <String, dynamic>{'notification_id': notificationId},
      );
    } catch (_) {
      // Push идёт поверх внутреннего колокольчика и не влияет на запись данных.
    }
  }

  static PushNavigationRequest? takeNavigationRequest() {
    final request = navigationRequest.value;
    navigationRequest.value = null;
    return request;
  }

  static Future<void> _registerWebSubscription(
    Map<String, dynamic> result,
  ) async {
    final subscriptionValue = result['subscription'];
    if (subscriptionValue is! Map) {
      throw Exception('Браузер не вернул данные подписки');
    }
    final subscription = Map<String, dynamic>.from(subscriptionValue);
    final keysValue = subscription['keys'];
    if (keysValue is! Map) {
      throw Exception('Браузер не вернул ключи подписки');
    }
    final keys = Map<String, dynamic>.from(keysValue);
    final endpoint = subscription['endpoint']?.toString().trim() ?? '';
    final p256dh = keys['p256dh']?.toString().trim() ?? '';
    final auth = keys['auth']?.toString().trim() ?? '';
    if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) {
      throw Exception('Подписка Web Push заполнена не полностью');
    }

    final running = _webRegistrationInFlight;
    if (running != null && _webRegistrationEndpoint == endpoint) {
      await running;
      return;
    }

    final operation = _manageWebDevice(<String, dynamic>{
      'action': 'register',
      'device_id': await _deviceId(),
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'expiration_time': subscription['expirationTime'],
      'user_agent': result['user_agent']?.toString() ?? '',
      'enabled': true,
    });
    _webRegistrationEndpoint = endpoint;
    _webRegistrationInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_webRegistrationInFlight, operation)) {
        _webRegistrationInFlight = null;
        _webRegistrationEndpoint = '';
      }
    }
  }

  static Future<void> _registerToken(
    String token, {
    PushPermissionState? permission,
  }) async {
    if (_client.auth.currentUser == null || token.trim().isEmpty) return;

    await _manageDevice(<String, dynamic>{
      'action': 'register',
      'token': token.trim(),
      'device_id': await _deviceId(),
      'platform': _platform,
      'enabled': true,
    });

    _publish(
      configured: true,
      enabled: true,
      registered: true,
      permission: permission ?? state.value.permission,
      message: 'Устройство подключено к push-уведомлениям',
    );
  }

  static Future<void> _manageDevice(Map<String, dynamic> body) async {
    await _client.functions.invoke('manage-push-device', body: body);
  }

  static Future<void> _manageWebDevice(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      'manage-web-push-device',
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Сервер не принял подписку Web Push');
    }
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'].toString());
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.notifications},
      context: <String, dynamic>{
        'source': 'push_foreground',
        'notification_id': message.data['notification_id'],
      },
    );
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    navigationRequest.value = PushNavigationRequest(
      notificationId: message.data['notification_id']?.toString(),
      entityType: message.data['entity_type']?.toString(),
      entityId: message.data['entity_id']?.toString(),
    );
  }

  static Future<String> _deviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final generated = List<int>.generate(24, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await preferences.setString(_deviceIdKey, generated);
    return generated;
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }

  static PushPermissionState _mapPermission(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.notDetermined:
        return PushPermissionState.notDetermined;
      case AuthorizationStatus.denied:
        return PushPermissionState.denied;
      case AuthorizationStatus.authorized:
        return PushPermissionState.authorized;
      case AuthorizationStatus.provisional:
        return PushPermissionState.provisional;
    }
  }

  static PushPermissionState _mapWebPermission(String permission) {
    switch (permission) {
      case 'granted':
        return PushPermissionState.authorized;
      case 'denied':
        return PushPermissionState.denied;
      case 'default':
        return PushPermissionState.notDetermined;
      default:
        return PushPermissionState.unknown;
    }
  }

  static void _publish({
    required bool configured,
    required bool enabled,
    required bool registered,
    required PushPermissionState permission,
    required String message,
    bool busy = false,
  }) {
    state.value = PushNotificationSnapshot(
      configured: configured,
      enabled: enabled,
      registered: registered,
      busy: busy,
      permission: permission,
      message: message,
    );
  }
}
