import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company_chat_models.dart';

class CompanyChatRepository {
  CompanyChatRepository._();

  static const String storageBucket = 'company-chat-files';
  static final SupabaseClient _client = Supabase.instance.client;
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static RealtimeChannel? _channel;
  static String? _companyId;
  static List<CompanyChatThread> _lastThreads = const <CompanyChatThread>[];

  static Stream<void> get changes => _changesController.stream;

  static void _notifyChanges({bool delayedRetry = false}) {
    if (!_changesController.isClosed) _changesController.add(null);
    if (!delayedRetry) return;

    for (final delay in <Duration>[
      Duration(milliseconds: 180),
      Duration(milliseconds: 450),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1600),
      Duration(milliseconds: 2800),
      Duration(milliseconds: 4500),
      Duration(milliseconds: 7000),
    ]) {
      Timer(delay, () {
        if (!_changesController.isClosed) _changesController.add(null);
      });
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> _list(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  static void startRealtime(String companyId) {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return;
    if (_companyId == cleanCompanyId && _channel != null) return;

    stopRealtime();
    _companyId = cleanCompanyId;
    _lastThreads = const <CompanyChatThread>[];
    final channel = _client.channel(
      'company:$cleanCompanyId:chat',
      opts: const RealtimeChannelConfig(private: true),
    );
    channel
        .onBroadcast(
          event: 'company_chat_changed',
          callback: (payload) {
            final nested = payload['payload'];
            final data = nested is Map
                ? Map<String, dynamic>.from(nested)
                : Map<String, dynamic>.from(payload);
            final table = data['table']?.toString().trim() ?? '';
            if (table == 'company_chat_messages' ||
                table == 'company_chat_attachments') {
              _notifyChanges(delayedRetry: true);
            }
          },
        )
        .subscribe();
    _channel = channel;
  }

  static void stopRealtime({String? companyId}) {
    final cleanCompanyId = companyId?.trim() ?? '';
    if (cleanCompanyId.isNotEmpty && cleanCompanyId != _companyId) return;
    final channel = _channel;
    _channel = null;
    _companyId = null;
    _lastThreads = const <CompanyChatThread>[];
    if (channel != null) unawaited(_client.removeChannel(channel));
  }

  static Future<List<CompanyChatMessage>> fetchFeed({
    int limit = 100,
    DateTime? before,
    String channelKind = 'general',
    String? peerUserId,
  }) async {
    final data = await _client.rpc<dynamic>(
      'get_company_chat_feed',
      params: <String, dynamic>{
        'p_limit': limit,
        'p_before': before?.toUtc().toIso8601String(),
        'p_channel_kind': channelKind.trim().isEmpty
            ? 'general'
            : channelKind.trim(),
        'p_peer_user_id': _nullIfEmpty(peerUserId),
      },
    );
    return _list(data)
        .whereType<Map>()
        .map(
          (value) =>
              CompanyChatMessage.fromMap(Map<String, dynamic>.from(value)),
        )
        .where((value) => value.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<CompanyChatThread>> fetchThreads() async {
    try {
      final data = await _client.rpc<dynamic>('get_company_chat_threads');
      final result = _list(data)
          .whereType<Map>()
          .map(
            (value) =>
                CompanyChatThread.fromMap(Map<String, dynamic>.from(value)),
          )
          .where((value) => value.threadKey.isNotEmpty)
          .toList(growable: false);
      _lastThreads = List<CompanyChatThread>.from(result);
      return result;
    } catch (_) {
      // После отправки сообщения ленту всё равно можно обновить по уже известному
      // треду. Временный сбой списка чатов не должен оставлять сообщение до F5.
      return List<CompanyChatThread>.from(_lastThreads);
    }
  }

  static Future<List<CompanyChatMember>> fetchMembers() async {
    final data = await _client.rpc<dynamic>('get_company_chat_members');
    return _list(data)
        .whereType<Map>()
        .map(
          (value) =>
              CompanyChatMember.fromMap(Map<String, dynamic>.from(value)),
        )
        .where((value) => value.userId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<CompanyChatUnreadState> fetchUnreadState() async {
    try {
      final data = await _client.rpc<dynamic>('get_company_chat_unread_state');
      return CompanyChatUnreadState.fromMap(_map(data));
    } catch (_) {
      // Служебный счётчик не должен отменять обновление видимых сообщений.
      return const CompanyChatUnreadState.empty();
    }
  }

  static Future<void> markRead({
    DateTime? at,
    String channelKind = 'general',
    String? peerUserId,
  }) async {
    try {
      await _client.rpc<void>(
        'mark_company_chat_read',
        params: <String, dynamic>{
          'p_read_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
          'p_channel_kind': channelKind.trim().isEmpty
              ? 'general'
              : channelKind.trim(),
          'p_peer_user_id': _nullIfEmpty(peerUserId),
        },
      );
    } catch (_) {
      // Статус прочтения не должен ломать отображение переписки.
    }
  }

  // В экспериментальном режиме старый ИИ в общем чате скрыт.
  // Новый ChatGPT живёт в отдельном assistant-треде и вызывается через askAi().
  static Future<bool> canUseAi() async => false;

  static Future<String> createMessage({
    required String body,
    String? replyToId,
    List<String> mentionedUserIds = const <String>[],
    required String clientNonce,
    String channelKind = 'general',
    String? peerUserId,
  }) async {
    final data = await _client.rpc<dynamic>(
      'create_company_chat_message',
      params: <String, dynamic>{
        'p_body': body,
        'p_reply_to_id': _nullIfEmpty(replyToId),
        'p_mentioned_user_ids': mentionedUserIds,
        'p_client_nonce': clientNonce,
        'p_channel_kind': channelKind.trim().isEmpty
            ? 'general'
            : channelKind.trim(),
        'p_peer_user_id': _nullIfEmpty(peerUserId),
      },
    );
    final id = data?.toString().trim() ?? '';
    if (id.isEmpty) throw Exception('Не удалось создать сообщение');
    _notifyChanges(delayedRetry: true);
    return id;
  }

  static Future<CompanyChatAttachment> uploadAttachment({
    required String companyId,
    required String messageId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final cleanCompanyId = companyId.trim();
    final cleanMessageId = messageId.trim();
    final cleanName = _safeFileName(fileName);
    if (bytes.isEmpty) throw Exception('Файл пуст');
    if (bytes.length > 20 * 1024 * 1024) {
      throw Exception('Файл больше 20 МБ');
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '$cleanCompanyId/$cleanMessageId/${stamp}_$cleanName';
    await _client.storage
        .from(storageBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: mimeType.trim().isEmpty
                ? 'application/octet-stream'
                : mimeType.trim(),
          ),
        );

    try {
      final row = await _client
          .from('company_chat_attachments')
          .insert(<String, dynamic>{
            'company_id': cleanCompanyId,
            'message_id': cleanMessageId,
            'storage_bucket': storageBucket,
            'storage_path': path,
            'file_name': cleanName,
            'mime_type': mimeType.trim().isEmpty
                ? 'application/octet-stream'
                : mimeType.trim(),
            'size_bytes': bytes.length,
            'uploaded_by': _client.auth.currentUser?.id,
          })
          .select()
          .single();
      _notifyChanges(delayedRetry: true);
      return CompanyChatAttachment.fromMap(_map(row));
    } catch (_) {
      await _client.storage.from(storageBucket).remove(<String>[path]);
      rethrow;
    }
  }

  static Future<void> deleteMessage(String messageId) async {
    await _client.rpc<dynamic>(
      'delete_company_chat_message',
      params: <String, dynamic>{'p_message_id': messageId.trim()},
    );
    _notifyChanges(delayedRetry: true);
  }

  static Future<void> askAi({
    required String companyId,
    required String sourceMessageId,
    String? objectName,
  }) async {
    final body = <String, dynamic>{
      'company_id': companyId.trim(),
      'source_message_id': sourceMessageId.trim(),
      'object_name': _nullIfEmpty(objectName),
    };

    final response = await _client.functions.invoke(
      'company-chat-gpt',
      body: body,
    );
    final data = _map(response.data);
    final error = data['error']?.toString().trim() ?? '';
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw Exception(
        error.isEmpty ? 'ChatGPT временно недоступен' : error,
      );
    }

    // Ответ уже записан в БД — просим UI показать его до подготовки кнопки.
    _notifyChanges(delayedRetry: true);

    try {
      await _client.functions.invoke(
        'company-chat-action-preparer',
        body: body,
      );
    } catch (_) {
      // Ответ ChatGPT остаётся доступным даже при ошибке моста действий.
    }

    _notifyChanges(delayedRetry: true);
  }

  static Future<String> createSignedAttachmentUrl(
    CompanyChatAttachment attachment, {
    int expiresInSeconds = 300,
  }) async {
    if (attachment.storageBucket.isEmpty || attachment.storagePath.isEmpty) {
      throw Exception('Файл недоступен');
    }
    final signed = await _client.storage
        .from(attachment.storageBucket)
        .createSignedUrl(attachment.storagePath, expiresInSeconds);
    final uri = Uri.parse(signed);
    return uri
        .replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'download': attachment.fileName,
          },
        )
        .toString();
  }

  static Future<Uint8List> downloadAttachment(
    CompanyChatAttachment attachment,
  ) async {
    if (attachment.storageBucket.isEmpty || attachment.storagePath.isEmpty) {
      throw Exception('Файл недоступен');
    }
    return _client.storage
        .from(attachment.storageBucket)
        .download(attachment.storagePath);
  }

  static String? _nullIfEmpty(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  static String _safeFileName(String value) {
    final clean = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'file';
    return clean.length <= 180 ? clean : clean.substring(clean.length - 180);
  }
}
