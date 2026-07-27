import 'dart:convert';

import 'package:universal_html/html.dart' as html;

class AiDocumentDownloadService {
  AiDocumentDownloadService._();

  static void downloadWordCompatible({
    required String title,
    required String body,
    required String fileBaseName,
  }) {
    final safeTitle = _escapeHtml(title);
    final safeBody = _escapeHtml(body).replaceAll('\n', '<br>');
    final document = '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>$safeTitle</title>
<style>
body { font-family: Arial, sans-serif; font-size: 12pt; line-height: 1.45; margin: 2cm; }
</style>
</head>
<body>$safeBody</body>
</html>
''';

    final bytes = utf8.encode(document);
    final blob = html.Blob(
      <Object>[bytes],
      'application/msword;charset=utf-8',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      html.AnchorElement(href: url)
        ..download = '$fileBaseName.doc'
        ..click();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
