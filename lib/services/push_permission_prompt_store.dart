import 'package:shared_preferences/shared_preferences.dart';

class PushPermissionPromptStore {
  PushPermissionPromptStore._();

  static const String keyPrefix =
      'appstroy_push_permission_prompt_shown_v1_';

  static String _keyFor(String userId) => '$keyPrefix$userId';

  static Future<bool> wasShown(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keyFor(userId)) == true;
  }

  static Future<bool> markShown(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setBool(_keyFor(userId), true);
  }
}
