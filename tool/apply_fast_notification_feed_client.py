from pathlib import Path
import re

path = Path('lib/data/notification_repository.dart')
text = path.read_text(encoding='utf-8')

pattern = re.compile(
    r"  static DateTime\? _parseDate\(dynamic value\) \{.*?\n"
    r"  static Future<bool> hasUnread\(",
    re.DOTALL,
)

replacement = """  static Future<List<AppNotification>> fetchLatest({
    String? objectName,
    int limit = 40,
    bool refreshOperational = false,
  }) async {
    final cleanObject = cleanObjectName(objectName);
    if (refreshOperational) await _refreshOperationalNotifications();
    try {
      final response = await _client.rpc<dynamic>(
        'get_notification_feed_fast',
        params: <String, dynamic>{
          'p_object_name': cleanObject,
          'p_limit': limit,
        },
      );
      if (response is! List) return <AppNotification>[];

      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(
            (row) => AppNotification.fromSupabase(
              row,
              isRead: row['is_read'] == true,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) {
        return <AppNotification>[];
      }
      rethrow;
    }
  }

  static Future<bool> hasUnread("""

updated, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('notification fetch pipeline anchor not found')

path.write_text(updated, encoding='utf-8')
