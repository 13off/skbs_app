import 'package:shared_preferences/shared_preferences.dart';

class NavigationSession {
  static const String _prefix = 'appstroy.navigation.v1';

  static SharedPreferences? _preferences;
  static String _scope = 'anonymous';

  static Future<void> configure({
    required String userId,
    required String companyId,
  }) async {
    final cleanUserId = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    final cleanCompanyId = companyId.trim().isEmpty ? 'none' : companyId.trim();

    _scope = '$cleanUserId.$cleanCompanyId';
    _preferences = await SharedPreferences.getInstance();
  }

  static String _key(String suffix) => '$_prefix.$_scope.$suffix';

  static SharedPreferences? get _prefs => _preferences;

  static int? readTabIndex(String platform) {
    return _prefs?.getInt(_key('tab.$platform'));
  }

  static Future<void> writeTabIndex(String platform, int index) async {
    if (index < 0) return;
    await _prefs?.setInt(_key('tab.$platform'), index);
  }

  static String? readPreviewRole() {
    return _prefs?.getString(_key('preview.role'));
  }

  static String readPreviewObjectName() {
    return _prefs?.getString(_key('preview.object'))?.trim() ?? '';
  }

  static Future<void> writePreview({
    required String role,
    String objectName = '',
  }) async {
    final preferences = _prefs;
    if (preferences == null) return;

    await preferences.setString(_key('preview.role'), role);
    if (objectName.trim().isEmpty) {
      await preferences.remove(_key('preview.object'));
    } else {
      await preferences.setString(
        _key('preview.object'),
        objectName.trim(),
      );
    }
  }

  static Future<void> clearPreview() async {
    final preferences = _prefs;
    if (preferences == null) return;

    await preferences.remove(_key('preview.role'));
    await preferences.remove(_key('preview.object'));
  }
}
