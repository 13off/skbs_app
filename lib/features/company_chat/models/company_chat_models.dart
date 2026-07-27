class CompanyChatThread {
  final String threadKey;
  final String channelKind;
  final String? peerUserId;
  final String title;
  final String role;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String lastMessagePreview;

  const CompanyChatThread({
    required this.threadKey,
    required this.channelKind,
    required this.peerUserId,
    required this.title,
    required this.role,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.lastMessagePreview,
  });

  factory CompanyChatThread.fromMap(Map<String, dynamic> map) {
    return CompanyChatThread(
      threadKey: map['thread_key']?.toString().trim() ?? 'general',
      channelKind: map['channel_kind']?.toString().trim() ?? 'general',
      peerUserId: _nullableText(map['peer_user_id']),
      title: map['title']?.toString().trim() ?? 'Чат',
      role: map['role']?.toString().trim() ?? '',
      unreadCount: _intValue(map['unread_count']),
      lastMessageAt: DateTime.tryParse(
        map['last_message_at']?.toString() ?? '',
      )?.toLocal(),
      lastMessagePreview:
          map['last_message_preview']?.toString().trim() ?? '',
    );
  }

  bool get isGeneral => channelKind == 'general';
  bool get isDirect => channelKind == 'direct';
  bool get isAssistant => channelKind == 'assistant';
}

class CompanyChatMember {
  final String userId;
  final String fullName;
  final String role;

  const CompanyChatMember({
    required this.userId,
    required this.fullName,
    required this.role,
  });

  factory CompanyChatMember.fromMap(Map<String, dynamic> map) {
    return CompanyChatMember(
      userId: map['user_id']?.toString().trim() ?? '',
      fullName: map['full_name']?.toString().trim() ?? 'Сотрудник AppСтрой',
      role: map['role']?.toString().trim() ?? '',
    );
  }
}

class CompanyChatAttachment {
  final String id;
  final String storageBucket;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  const CompanyChatAttachment({
    required this.id,
    required this.storageBucket,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory CompanyChatAttachment.fromMap(Map<String, dynamic> map) {
    return CompanyChatAttachment(
      id: map['id']?.toString().trim() ?? '',
      storageBucket: map['storage_bucket']?.toString().trim() ?? '',
      storagePath: map['storage_path']?.toString().trim() ?? '',
      fileName: map['file_name']?.toString().trim() ?? 'Файл',
      mimeType:
          map['mime_type']?.toString().trim() ?? 'application/octet-stream',
      sizeBytes: _intValue(map['size_bytes']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  bool get isImage => mimeType.startsWith('image/');
}

class CompanyChatReplyPreview {
  final String id;
  final String senderName;
  final String kind;
  final String body;
  final bool deleted;

  const CompanyChatReplyPreview({
    required this.id,
    required this.senderName,
    required this.kind,
    required this.body,
    required this.deleted,
  });

  factory CompanyChatReplyPreview.fromMap(Map<String, dynamic> map) {
    return CompanyChatReplyPreview(
      id: map['id']?.toString().trim() ?? '',
      senderName: map['sender_name']?.toString().trim() ?? '',
      kind: map['kind']?.toString().trim() ?? 'user',
      body: map['body']?.toString().trim() ?? '',
      deleted: map['deleted'] == true,
    );
  }
}

class CompanyChatMessage {
  final String id;
  final String companyId;
  final String? senderUserId;
  final String senderName;
  final String senderRole;
  final String kind;
  final String channelKind;
  final String? peerUserId;
  final String threadKey;
  final String body;
  final String? replyToId;
  final List<String> mentionedUserIds;
  final Map<String, dynamic> aiPayload;
  final String? aiRequesterUserId;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final CompanyChatReplyPreview? reply;
  final List<CompanyChatAttachment> attachments;

  const CompanyChatMessage({
    required this.id,
    required this.companyId,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.kind,
    this.channelKind = 'general',
    this.peerUserId,
    this.threadKey = 'general',
    required this.body,
    required this.replyToId,
    required this.mentionedUserIds,
    required this.aiPayload,
    required this.aiRequesterUserId,
    required this.createdAt,
    required this.editedAt,
    required this.deletedAt,
    required this.reply,
    required this.attachments,
  });

  factory CompanyChatMessage.fromMap(Map<String, dynamic> map) {
    final rawReply = map['reply'];
    final rawAttachments = map['attachments'];
    final rawMentions = map['mentioned_user_ids'];
    final rawAi = map['ai_payload'];
    return CompanyChatMessage(
      id: map['id']?.toString().trim() ?? '',
      companyId: map['company_id']?.toString().trim() ?? '',
      senderUserId: _nullableText(map['sender_user_id']),
      senderName: map['sender_name']?.toString().trim() ?? 'Сотрудник AppСтрой',
      senderRole: map['sender_role']?.toString().trim() ?? '',
      kind: map['kind']?.toString().trim() ?? 'user',
      channelKind: map['channel_kind']?.toString().trim() ?? 'general',
      peerUserId: _nullableText(map['peer_user_id']),
      threadKey: map['thread_key']?.toString().trim() ?? 'general',
      body: map['body']?.toString() ?? '',
      replyToId: _nullableText(map['reply_to_id']),
      mentionedUserIds: rawMentions is List
          ? rawMentions
                .map((value) => value?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      aiPayload: rawAi is Map
          ? Map<String, dynamic>.from(rawAi)
          : const <String, dynamic>{},
      aiRequesterUserId: _nullableText(map['ai_requester_user_id']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      editedAt: DateTime.tryParse(
        map['edited_at']?.toString() ?? '',
      )?.toLocal(),
      deletedAt: DateTime.tryParse(
        map['deleted_at']?.toString() ?? '',
      )?.toLocal(),
      reply: rawReply is Map
          ? CompanyChatReplyPreview.fromMap(Map<String, dynamic>.from(rawReply))
          : null,
      attachments: rawAttachments is List
          ? rawAttachments
                .whereType<Map>()
                .map(
                  (value) => CompanyChatAttachment.fromMap(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .where((value) => value.id.isNotEmpty)
                .toList(growable: false)
          : const <CompanyChatAttachment>[],
    );
  }

  bool get isAssistant => kind == 'assistant';
  bool get isSystem => kind == 'system';
  bool get isDeleted => deletedAt != null;
  bool get hasAiAction => aiPayload['action'] is Map;
}

class CompanyChatUnreadState {
  final int unreadCount;
  final int mentionCount;
  final DateTime? lastMessageAt;

  const CompanyChatUnreadState({
    required this.unreadCount,
    required this.mentionCount,
    required this.lastMessageAt,
  });

  const CompanyChatUnreadState.empty()
    : unreadCount = 0,
      mentionCount = 0,
      lastMessageAt = null;

  factory CompanyChatUnreadState.fromMap(Map<String, dynamic> map) {
    return CompanyChatUnreadState(
      unreadCount: _intValue(map['unread_count']),
      mentionCount: _intValue(map['mention_count']),
      lastMessageAt: DateTime.tryParse(
        map['last_message_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

String? _nullableText(dynamic value) {
  final clean = value?.toString().trim() ?? '';
  return clean.isEmpty ? null : clean;
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
