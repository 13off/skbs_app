from pathlib import Path

INDEX_PATH = Path('web/index.html')
TEST_PATH = Path('test/web_locale_startup_contract_test.dart')

source = INDEX_PATH.read_text(encoding='utf-8')
marker = '  <meta charset="UTF-8">\n'
if marker not in source:
    raise SystemExit('Не найден маркер charset в web/index.html')
if 'id="appstroy-locale-guard"' in source:
    raise SystemExit('Защита локали уже существует')

locale_guard = '''  <meta charset="UTF-8">\n\n  <script id="appstroy-locale-guard">\n    (function () {\n      var fallbackLocale = 'ru-RU';\n      var normalizeLocale = function (value) {\n        if (typeof value !== 'string') return fallbackLocale;\n\n        var clean = value\n          .trim()\n          .replace(/_/g, '-')\n          .replace(/@.*$/, '');\n        if (!clean) return fallbackLocale;\n\n        try {\n          return new Intl.Locale(clean).toString();\n        } catch (_) {\n          var language = clean.split('-')[0].toLowerCase();\n          return /^[a-z]{2,3}$/.test(language) ? language : fallbackLocale;\n        }\n      };\n\n      var sourceLanguages = Array.isArray(navigator.languages)\n        ? navigator.languages\n        : [navigator.language];\n      var normalizedLanguages = sourceLanguages\n        .map(normalizeLocale)\n        .filter(function (value, index, values) {\n          return values.indexOf(value) === index;\n        });\n      var normalizedLanguage = normalizeLocale(navigator.language);\n      if (normalizedLanguages.length === 0) {\n        normalizedLanguages = [normalizedLanguage];\n      }\n\n      var overrideNavigatorValue = function (target, key, value) {\n        if (!target) return false;\n        try {\n          Object.defineProperty(target, key, {\n            configurable: true,\n            get: function () { return value; }\n          });\n          return true;\n        } catch (_) {\n          return false;\n        }\n      };\n\n      var navigatorPrototype = window.Navigator && window.Navigator.prototype;\n      overrideNavigatorValue(navigatorPrototype, 'language', normalizedLanguage);\n      overrideNavigatorValue(navigatorPrototype, 'languages', normalizedLanguages);\n      overrideNavigatorValue(navigator, 'language', normalizedLanguage);\n      overrideNavigatorValue(navigator, 'languages', normalizedLanguages);\n\n      window.appstroyBrowserLocale = normalizedLanguage;\n    })();\n  </script>\n'''

INDEX_PATH.write_text(source.replace(marker, locale_guard, 1), encoding='utf-8')

TEST_PATH.write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup normalizes browser locales before Flutter bootstrap', () {
    final source = File('web/index.html').readAsStringSync();

    expect(source, contains('id=\"appstroy-locale-guard\"'));
    expect(source, contains(".replace(/_/g, '-')"));
    expect(source, contains(".replace(/@.*\$/, '')"));
    expect(source, contains('new Intl.Locale(clean)'));
    expect(source, contains('Object.defineProperty(target, key'));
    expect(source, contains('window.appstroyBrowserLocale'));

    final guardIndex = source.indexOf('id=\"appstroy-locale-guard\"');
    final bootstrapIndex = source.indexOf('flutter_bootstrap.js');
    expect(guardIndex, greaterThanOrEqualTo(0));
    expect(bootstrapIndex, greaterThan(guardIndex));
  });
}
""",
    encoding='utf-8',
)
