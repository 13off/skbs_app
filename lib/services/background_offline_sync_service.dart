import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/supabase_config.dart';
import '../data/offline_sync_service.dart';

const String iosBackgroundSyncChannelName =
    'ru.appstroy.skbs/offline_background_sync';
const String _backgroundOfflineSyncTaskName = 'appstroy.backgroundOfflineSync';
const String _androidOfflineSyncUniqueName = 'appstroy-offline-sync';
const String _backgroundScopeUserKey = 'appstroy_background_sync_user_id';
const String _backgroundScopeCompanyKey =
    'appstroy_background_sync_company_id';
const String _lastScheduleAtKey = 'appstroy_background_sync_last_schedule_at';
const String _lastWakeAtKey = 'appstroy_background_sync_last_wake_at';
const String _lastResultKey = 'appstroy_background_sync_last_result';
const String _lastErrorKey = 'appstroy_background_sync_last_error';

@pragma('vm:entry-point')
void backgroundOfflineSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _backgroundOfflineSyncTaskName) return true;
    return BackgroundOfflineSyncService.runScheduledFlush();
  });
}

class BackgroundOfflineSyncService {
  BackgroundOfflineSyncService._();

  static const MethodChannel _iosChannel = MethodChannel(
    iosBackgroundSyncChannelName,
  );

  static Future<void>? _initializeFuture;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isSupported => _isAndroid || _isIos;

  static Future<void> initialize() {
    if (!isSupported) return Future<void>.value();
    return _initializeFuture ??= _initializeSafely();
  }

  static Future<void> _initializeSafely() async {
    try {
      if (_isAndroid) {
        await Workmanager().initialize(backgroundOfflineSyncDispatcher);
        return;
      }
      if (_isIos) {
        _iosChannel.setMethodCallHandler(_handleIosNativeCall);
      }
    } catch (error) {
      await _recordError('initialize: $error');
    }
  }

  static Future<dynamic> _handleIosNativeCall(MethodCall call) async {
    if (call.method != 'networkWake') return null;
    await _recordWake('ios-background-url-session');
    return runScheduledFlush();
  }

  static Future<void> schedule({
    required String userId,
    required String companyId,
  }) async {
    if (!isSupported) return;

    final cleanUserId = userId.trim();
    final cleanCompanyId = companyId.trim();
    if (cleanUserId.isEmpty || cleanCompanyId.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    await Future.wait<bool>([
      preferences.setString(_backgroundScopeUserKey, cleanUserId),
      preferences.setString(_backgroundScopeCompanyKey, cleanCompanyId),
      preferences.setString(_lastScheduleAtKey, DateTime.now().toIso8601String()),
    ]);

    await initialize();

    try {
      if (_isAndroid) {
        await Workmanager().registerOneOffTask(
          _androidOfflineSyncUniqueName,
          _backgroundOfflineSyncTaskName,
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.keep,
          tag: _androidOfflineSyncUniqueName,
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(seconds: 30),
        );
        await _recordResult('android-network-wake-scheduled');
        return;
      }

      if (_isIos) {
        final baseUrl = supabaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
        final scheduled = await _iosChannel.invokeMethod<bool>(
          'scheduleWake',
          <String, dynamic>{'probeUrl': '$baseUrl/auth/v1/health'},
        );
        if (scheduled != true) {
          throw StateError('native iOS wake was not scheduled');
        }
        await _recordResult('ios-background-transfer-scheduled');
      }
    } catch (error) {
      await _recordError('schedule: $error');
      // The durable queue stays intact. Foreground/resume sync will retry too.
    }
  }

  static Future<bool> runScheduledFlush() async {
    WidgetsFlutterBinding.ensureInitialized();

    // A native iOS relaunch starts a fresh headless Flutter engine. Give its
    // generated plugins a brief moment to register before reading preferences.
    if (_isIos && !Supabase.instance.isInitialized) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      // Workmanager/headless engines live in a different isolate. Reload the
      // shared cache so scope and queue writes made by the UI isolate are
      // visible before the background worker decides whether there is work.
      await preferences.reload();
      final userId = preferences.getString(_backgroundScopeUserKey)?.trim() ?? '';
      final companyId =
          preferences.getString(_backgroundScopeCompanyKey)?.trim() ?? '';
      if (userId.isEmpty || companyId.isEmpty) {
        await _recordResult('no-active-offline-scope');
        return true;
      }

      if (!Supabase.instance.isInitialized) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabasePublishableKey,
        );
      }

      await OfflineSyncService.configure(userId: userId, companyId: companyId);
      if (OfflineSyncService.pendingCount == 0) {
        await _recordResult('queue-already-empty');
        return true;
      }

      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;
      if (session == null || session.user.id != userId) {
        await _recordError('flush: no matching restored Supabase session');
        return false;
      }
      if (session.isExpired) {
        final refreshed = await auth.refreshSession();
        session = refreshed.session;
        if (session == null || session.user.id != userId) {
          await _recordError('flush: Supabase session refresh failed');
          return false;
        }
      }

      await OfflineSyncService.flush();
      final complete = OfflineSyncService.pendingCount == 0;
      await _recordResult(
        complete
            ? 'background-flush-complete'
            : 'background-flush-pending-${OfflineSyncService.pendingCount}',
      );
      return complete;
    } catch (error) {
      await _recordError('flush: $error');
      return false;
    }
  }

  static Future<void> reportIosHeadlessFlushResult(bool success) async {
    if (!_isIos) return;
    try {
      await _iosChannel.invokeMethod<void>(
        'backgroundFlushFinished',
        <String, dynamic>{'success': success},
      );
    } catch (error) {
      await _recordError('ios-headless-result: $error');
    }
  }

  static Future<void> _recordWake(String source) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait<bool>([
        preferences.setString(_lastWakeAtKey, DateTime.now().toIso8601String()),
        preferences.setString(_lastResultKey, 'wake:$source'),
        preferences.remove(_lastErrorKey),
      ]);
    } catch (_) {}
  }

  static Future<void> _recordResult(String result) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait<bool>([
        preferences.setString(_lastResultKey, result),
        preferences.remove(_lastErrorKey),
      ]);
    } catch (_) {}
  }

  static Future<void> _recordError(String error) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_lastErrorKey, error);
    } catch (_) {}
  }
}
