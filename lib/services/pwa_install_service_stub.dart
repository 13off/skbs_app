bool get isSupported => false;

bool get isInstalled => false;

bool get canPrompt => false;

String get browserName => 'браузер';

bool get isYandexBrowser => false;

String get platformName => 'устройстве';

String get manualInstruction =>
    'Откройте веб-версию AppСтрой в поддерживаемом браузере.';

Future<String> install() async => 'unsupported';
