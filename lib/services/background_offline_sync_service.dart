import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/supabase_config.dart';
import '../data/offline_sync_service.dart';

const String _backgroundOfflineSyncTaskName = 'appstroy.backgroundOfflineSync';
const String _androidOfflineSyncUniqueName = 'appstroy-offline-sync';
const String _iosOfflineSyncIdentifier = 'ru.appstroy.mobile.offlineSync';
const String _backgroundScopeUserKey = 'appstroy_background_sync_user_id';
const String _backgroundScopeCompanyKey = 'appstroy_background_sync_company_id';

@pragma('vm:entry-point')
void backgroundOfflineSyncDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _backgroundOfflineSyncTaskName &&
        taskName != _iosOfflineSyncIdentifier) {
      return true;
    }
    return BackgroundOfflineSyncService.runScheduledFlush();
  });
}

class BackgroundOfflineSyncService {
  BackgroundOfflineSyncService._();

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
      await Workmanager().initialize(backgroundOfflineSyncDispatcher);
    } catch (_) {
      // Foreground sync remains the fallback if the OS scheduler is unavailable.
    }
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
    ]);

    await initialize();

    try {
      final connected = Constraints(networkType: NetworkType.connected);
      if (_isAndroid) {
        await Workmanager().registerOneOffTask(
          _androidOfflineSyncUniqueName,
          _backgroundOfflineSyncTaskName,
          constraints: connected,
          tag: _androidOfflineSyncUniqueName,
        );
        return;
      }

      if (_isIos) {
        await Workmanager().registerProcessingTask(
          _iosOfflineSyncIdentifier,
          _iosOfflineSyncIdentifier,
          constraints: connected,
        );
      }
    } catch (_) {
      // The durable queue stays intact. Foreground/resume sync will retry too.
    }
  }

  static Future<bool> runScheduledFlush() async {
    WidgetsFlutterBinding.ensureInitialized();

    String userId = '';
    String companyId = '';
    try {
      final preferences = await SharedPreferences.getInstance();
      userId = preferences.getString(_backgroundScopeUserKey)?.trim() ?? '';
      companyId =
          preferences.getString(_backgroundScopeCompanyKey)?.trim() ?? '';
      if (userId.isEmpty || companyId.isEmpty) return true;

      if (!Supabase.instance.isInitialized) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabasePublishableKey,
        );
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        return false;
      }

      await OfflineSyncService.configure(userId: userId, companyId: companyId);
      if (OfflineSyncService.pendingCount == 0) return true;

      await OfflineSyncService.flush();
      final complete = OfflineSyncService.pendingCount == 0;
      if (!complete && _isIos) {
        await schedule(userId: userId, companyId: companyId);
      }
      return complete;
    } catch (_) {
      if (_isIos && userId.isNotEmpty && companyId.isNotEmpty) {
        unawaited(schedule(userId: userId, companyId: companyId));
      }
      return false;
    }
  }
}
