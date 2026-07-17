class WebPushBridge {
  WebPushBridge._();

  static Map<String, dynamic> get status => const <String, dynamic>{
        'supported': false,
        'standalone': false,
        'permission': 'unsupported',
        'registered': false,
      };

  static bool get isSupported => false;
  static bool get isStandalone => false;
  static String get permission => 'unsupported';

  static Future<Map<String, dynamic>> existing() async => status;

  static Future<Map<String, dynamic>> subscribe(String publicKey) async => status;

  static Future<Map<String, dynamic>> unsubscribe() async => status;
}
