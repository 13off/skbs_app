from pathlib import Path

notification_path = Path('lib/data/notification_repository.dart')
notification_text = notification_path.read_text(encoding='utf-8')
client_anchor = """class NotificationRepository {
  static final SupabaseClient _client = Supabase.instance.client;

"""
client_replacement = """class NotificationRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> _refreshOperationalNotifications() async {
    try {
      await _client.rpc<void>('refresh_operational_notifications');
    } catch (_) {
      // Список уведомлений остаётся доступным даже при временной ошибке обновления.
    }
  }

"""
if client_anchor not in notification_text:
    raise SystemExit('notification client anchor not found')
notification_text = notification_text.replace(client_anchor, client_replacement, 1)
load_anchor = """    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('Пользователь не авторизован');
    }

    final results = await Future.wait<dynamic>([
"""
load_replacement = """    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('Пользователь не авторизован');
    }

    await _refreshOperationalNotifications();

    final results = await Future.wait<dynamic>([
"""
if load_anchor not in notification_text:
    raise SystemExit('notification load anchor not found')
notification_text = notification_text.replace(load_anchor, load_replacement, 1)
notification_path.write_text(notification_text, encoding='utf-8')

ai_path = Path('lib/features/ai/data/ai_assistant_repository.dart')
ai_text = ai_path.read_text(encoding='utf-8')
result_anchor = """    return AiAssistantResult.fromMap(data);
  }

  static String _dateKey(DateTime value) {
"""
result_replacement = """    final result = AiAssistantResult.fromMap(data);
    final action = result.action;
    if (action != null && action.id.trim().isNotEmpty) {
      try {
        await _client.rpc<void>(
          'create_ai_draft_ready_notification',
          params: <String, dynamic>{
            'p_title': result.title,
            'p_action_type': action.type,
            'p_action_id': action.id,
          },
        );
      } catch (_) {
        // Черновик остаётся доступен в чате даже при временной ошибке уведомления.
      }
    }

    return result;
  }

  static String _dateKey(DateTime value) {
"""
if result_anchor not in ai_text:
    raise SystemExit('AI result anchor not found')
ai_text = ai_text.replace(result_anchor, result_replacement, 1)
ai_path.write_text(ai_text, encoding='utf-8')
