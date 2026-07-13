import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_data_sync.dart';

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

  static final ValueNotifier<PushNotificationSnapshot> state =
      ValueNotifier<PushNotificationSnapshot>(PushNotificationSnapshot.initial);
  static final ValueNotifier<PushNavigationRequest?> navigationRequest =
      ValueNotifier<PushNavigationRequest?>(null);

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<AuthState>? _authSubscription;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_enabledKey) ?? true;
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

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
      );
      _authSubscription = _client.auth.onAuthStateChange.listen((authState) {
        if (authState.event == AuthChangeEvent.signedOut) {
          _publish(
            configured: true,
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
      });

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

  static Future<void> syncForCurrentSession({
    bool requestPermission = false,
  }) async {
    if (!FirebaseRuntimeConfiguration.isConfigured ||
        _client.auth.currentUser == null) {
      return;
    }

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

  static Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);

    if (!enabled) {
      try {
        if (_client.auth.currentUser != null) {
          await _client.rpc(
            'set_current_push_device_enabled',
            params: {
              'p_device_id': await _deviceId(),
              'p_enabled': false,
            },
          );
        }
      } catch (_) {
        // Настройка push не должна влиять на рабочие функции приложения.
      }
      _publish(
        configured: FirebaseRuntimeConfiguration.isConfigured,
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
      await _client.rpc(
        'unregister_current_push_device',
        params: {'p_device_id': await _deviceId()},
      );
    } catch (_) {
      // Выход из аккаунта продолжится даже при недоступности push-сервиса.
    }

    if (FirebaseRuntimeConfiguration.isConfigured) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        // Токен в базе уже удалён; ошибка Firebase не блокирует выход.
      }
    }

    _publish(
      configured: FirebaseRuntimeConfiguration.isConfigured,
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
        body: {'notification_id': notificationId},
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

  static Future<void> _registerToken(
    String token, {
    PushPermissionState? permission,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || token.trim().isEmpty) return;

    final profile = await _client
        .from('user_profiles')
        .select('active_company_id')
        .eq('id', user.id)
        .maybeSingle();
    final companyId = profile?['active_company_id']?.toString().trim() ?? '';
    if (companyId.isEmpty) return;

    await _client.rpc(
      'register_current_push_device',
      params: {
        'p_token': token.trim(),
        'p_device_id': await _deviceId(),
        'p_platform': _platform,
        'p_enabled': true,
      },
    );

    _publish(
      configured: true,
      enabled: true,
      registered: true,
      permission: permission ?? state.value.permission,
      message: 'Устройство подключено к push-уведомлениям',
    );
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
