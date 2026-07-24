import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../features/ai/actions/ai_action_execution_coordinator.dart';
import '../../../features/ai/models/ai_assistant_result.dart';
import '../../../models/app_user_profile.dart';
import '../data/company_chat_repository.dart';
import '../models/company_chat_models.dart';

class CompanyChatScreen extends StatefulWidget {
  final AppUserProfile profile;

  const CompanyChatScreen({super.key, required this.profile});

  @override
  State<CompanyChatScreen> createState() => _CompanyChatScreenState();
}

class _PendingChatFile {
  final XFile file;
  final int size;

  const _PendingChatFile({required this.file, required this.size});
}

class _CompanyChatScreenState extends State<CompanyChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final DateFormat timeFormat = DateFormat('HH:mm');
  final DateFormat dayFormat = DateFormat('d MMMM', 'ru');

  final List<CompanyChatMessage> messages = <CompanyChatMessage>[];
  final List<CompanyChatMember> members = <CompanyChatMember>[];
  final List<_PendingChatFile> pendingFiles = <_PendingChatFile>[];
  final Set<String> selectedMentionIds = <String>{};
  final Set<String> runningActionIds = <String>{};

  StreamSubscription<void>? changesSubscription;
  Timer? refreshTimer;
  CompanyChatMessage? replyTo;
  bool loading = true;
  bool refreshing = false;
  bool sending = false;
  bool askingAi = false;
  bool canUseAi = false;
  String? errorText;

  String get companyId => widget.profile.activeCompanyId.trim();

  String? get objectName {
    final clean = widget.profile.objectName.trim();
    return clean.isEmpty ? null : clean;
  }

  @override
  void initState() {
    super.initState();
    CompanyChatRepository.startRealtime(companyId);
    changesSubscription = CompanyChatRepository.changes.listen((_) {
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 180), refresh);
    });
    unawaited(loadInitial());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    changesSubscription?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadInitial() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final values = await Future.wait<dynamic>([
        CompanyChatRepository.fetchFeed(limit: 150),
        CompanyChatRepository.fetchMembers(),
        CompanyChatRepository.canUseAi(),
      ]);
      if (!mounted) return;
      messages
        ..clear()
        ..addAll(values[0] as List<CompanyChatMessage>);
      members
        ..clear()
        ..addAll(values[1] as List<CompanyChatMember>);
      canUseAi = values[2] == true;
      await markRead();
      if (!mounted) return;
      setState(() => loading = false);
      scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = _error(error);
      });
    }
  }

  Future<void> refresh() async {
    if (refreshing || !mounted) return;
    refreshing = true;
    try {
      final next = await CompanyChatRepository.fetchFeed(limit: 150);
      if (!mounted) return;
      final hadNewMessages =
          next.isNotEmpty &&
          (messages.isEmpty || next.last.id != messages.last.id);
      setState(() {
        messages
          ..clear()
          ..addAll(next);
        errorText = null;
      });
      await markRead();
      if (hadNewMessages) scrollToBottom();
    } catch (_) {
      // Realtime обновится снова; временная ошибка не перекрывает чат.
    } finally {
      refreshing = false;
    }
  }

  Future<void> markRead() async {
    if (messages.isEmpty) return;
    await CompanyChatRepository.markRead(at: messages.last.createdAt);
  }

  void scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final target = scrollController.position.maxScrollExtent;
      if (jump) {
        scrollController.jumpTo(target);
      } else {
        scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> pickFiles() async {
    if (sending) return;
    try {
      final picked = await openFiles();
      if (picked.isEmpty) return;
      final next = <_PendingChatFile>[];
      var total = pendingFiles.fold<int>(0, (sum, item) => sum + item.size);
      for (final file in picked) {
        if (pendingFiles.length + next.length >= 5) break;
        final size = await file.length();
        if (size <= 0) continue;
        if (size > 20 * 1024 * 1024) {
          showMessage('${file.name}: файл больше 20 МБ');
          continue;
        }
        if (total + size > 40 * 1024 * 1024) {
          showMessage('Общий размер вложений больше 40 МБ');
          break;
        }
        total += size;
        next.add(_PendingChatFile(file: file, size: size));
      }
      if (!mounted || next.isEmpty) return;
      setState(() => pendingFiles.addAll(next));
    } catch (error) {
      showMessage('Не удалось выбрать файл: ${_error(error)}');
    }
  }

  Future<void> chooseMention() async {
    if (members.isEmpty) return;
    final member = await showModalBottomSheet<CompanyChatMember>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Упомянуть сотрудника',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final item = members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(_initials(item.fullName)),
                        ),
                        title: Text(item.fullName),
                        subtitle: Text(AppUserProfile.titleForRole(item.role)),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (member == null || !mounted) return;
    final current = messageController.text;
    final separator = current.isEmpty || current.endsWith(' ') ? '' : ' ';
    messageController.text = '$current$separator@${member.fullName} ';
    messageController.selection = TextSelection.collapsed(
      offset: messageController.text.length,
    );
    setState(() => selectedMentionIds.add(member.userId));
  }

  bool get composerAsksAi {
    if (askingAi) return true;
    final normalized = messageController.text.toLowerCase().replaceAll(
      'ё',
      'е',
    );
    return normalized.contains('@appстрой') ||
        normalized.contains('@ии') ||
        normalized.startsWith('/ai ');
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (sending || (text.isEmpty && pendingFiles.isEmpty)) return;
    final files = List<_PendingChatFile>.from(pendingFiles);
    final mentions = selectedMentionIds.toList(growable: false);
    final replyId = replyTo?.id;
    final shouldAskAi = canUseAi && (askingAi || composerAsksAi);

    setState(() => sending = true);
    String? messageId;
    try {
      messageId = await CompanyChatRepository.createMessage(
        body: text,
        replyToId: replyId,
        mentionedUserIds: mentions,
        clientNonce:
            '${widget.profile.id}-${DateTime.now().microsecondsSinceEpoch}',
      );

      final failed = <String>[];
      for (final item in files) {
        try {
          final bytes = await item.file.readAsBytes();
          await CompanyChatRepository.uploadAttachment(
            companyId: companyId,
            messageId: messageId,
            fileName: item.file.name,
            mimeType: item.file.mimeType ?? _mimeFromName(item.file.name),
            bytes: bytes,
          );
        } catch (_) {
          failed.add(item.file.name);
        }
      }
      if (text.isEmpty && files.isNotEmpty && failed.length == files.length) {
        await CompanyChatRepository.deleteMessage(messageId);
        throw Exception('Ни один файл не загрузился');
      }

      if (!mounted) return;
      messageController.clear();
      setState(() {
        replyTo = null;
        pendingFiles.clear();
        selectedMentionIds.clear();
        askingAi = false;
      });
      await refresh();
      if (failed.isNotEmpty) {
        showMessage('Не загрузились: ${failed.join(', ')}');
      }

      if (shouldAskAi) {
        try {
          await CompanyChatRepository.askAi(
            companyId: companyId,
            sourceMessageId: messageId,
            objectName: objectName,
          );
        } catch (error) {
          showMessage('ИИ не ответил: ${_error(error)}');
        }
      }
    } catch (error) {
      showMessage('Не удалось отправить: ${_error(error)}');
    } finally {
      if (mounted) setState(() => sending = false);
      scrollToBottom();
    }
  }

  Future<void> downloadAttachment(CompanyChatAttachment attachment) async {
    try {
      final url = await SupabaseSignedUrl.create(attachment);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Браузер не открыл файл');
    } catch (error) {
      showMessage('Не удалось открыть файл: ${_error(error)}');
    }
  }

  Future<void> deleteMessage(CompanyChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('В чате останется отметка об удалённом сообщении.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CompanyChatRepository.deleteMessage(message.id);
      await refresh();
    } catch (error) {
      showMessage('Не удалось удалить: ${_error(error)}');
    }
  }

  Future<void> runAiAction(CompanyChatMessage message) async {
    final rawAction = message.aiPayload['action'];
    if (rawAction is! Map) return;
    final action = AiAssistantAction.fromMap(
      Map<String, dynamic>.from(rawAction),
    );
    if (action.id.isEmpty || runningActionIds.contains(action.id)) return;
    setState(() => runningActionIds.add(action.id));
    try {
      final result = await AiActionExecutionCoordinator.execute(
        context: context,
        profile: widget.profile,
        action: action,
      );
      showMessage(result.message);
    } catch (error) {
      showMessage('Действие не выполнено: ${_error(error)}');
    } finally {
      if (mounted) setState(() => runningActionIds.remove(action.id));
    }
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Чат компании'),
            Text(
              '${members.length} участников · ИИ-помощник внутри',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refreshing ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: buildBody()),
          buildComposer(),
        ],
      ),
    );
  }

  Widget buildBody() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 44),
              const SizedBox(height: 12),
              Text(errorText!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: loadInitial,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_rounded, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Общий чат компании',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                canUseAi
                    ? 'Напиши коллегам или включи ИИ-помощника перед отправкой.'
                    : 'Напиши первое сообщение коллегам.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final showDay =
            previous == null ||
            !_sameDay(previous.createdAt, message.createdAt);
        return Column(
          children: [
            if (showDay) dayDivider(message.createdAt),
            messageBubble(message),
          ],
        );
      },
    );
  }

  Widget dayDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            dayFormat.format(date),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget messageBubble(CompanyChatMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final own = message.senderUserId == widget.profile.id;
    final mentioned = message.mentionedUserIds.contains(widget.profile.id);
    final assistant = message.isAssistant;
    final alignment = assistant
        ? Alignment.center
        : own
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bubbleColor = assistant
        ? scheme.tertiaryContainer
        : own
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final maxWidth = MediaQuery.sizeOf(context).width >= 760 ? 620.0 : 340.0;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onLongPress: message.isDeleted ? null : () => showMessageMenu(message),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: mentioned ? scheme.primary : scheme.outlineVariant,
              width: mentioned ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    assistant
                        ? Icons.auto_awesome_rounded
                        : Icons.person_rounded,
                    size: 15,
                    color: assistant
                        ? scheme.tertiary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.senderName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (!assistant && message.senderRole.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      AppUserProfile.titleForRole(message.senderRole),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              if (message.reply != null) ...[
                const SizedBox(height: 8),
                replyPreview(message.reply!),
              ],
              const SizedBox(height: 7),
              if (message.isDeleted)
                Text(
                  'Сообщение удалено',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else ...[
                if (message.body.trim().isNotEmpty)
                  SelectableText(
                    message.body,
                    style: const TextStyle(
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (message.attachments.isNotEmpty) ...[
                  if (message.body.trim().isNotEmpty) const SizedBox(height: 9),
                  for (final attachment in message.attachments)
                    attachmentTile(attachment),
                ],
                if (assistant && message.hasAiAction) ...[
                  const SizedBox(height: 10),
                  aiActionButton(message),
                ],
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeFormat.format(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message.editedAt != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      'изменено',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (mentioned) ...[
                    const SizedBox(width: 7),
                    Icon(
                      Icons.alternate_email_rounded,
                      size: 13,
                      color: scheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget replyPreview(CompanyChatReplyPreview reply) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.kind == 'assistant'
                ? 'ИИ-помощник AppСтрой'
                : reply.senderName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            reply.deleted
                ? 'Сообщение удалено'
                : (reply.body.isEmpty ? 'Вложение' : reply.body),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget attachmentTile(CompanyChatAttachment attachment) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => downloadAttachment(attachment),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                attachment.isImage
                    ? Icons.image_outlined
                    : Icons.attach_file_rounded,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _fileSize(attachment.sizeBytes),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget aiActionButton(CompanyChatMessage message) {
    final rawAction = message.aiPayload['action'];
    if (rawAction is! Map) return const SizedBox.shrink();
    final action = AiAssistantAction.fromMap(
      Map<String, dynamic>.from(rawAction),
    );
    final running = runningActionIds.contains(action.id);
    return FilledButton.icon(
      onPressed: running ? null : () => runAiAction(message),
      icon: running
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.fact_check_outlined),
      label: Text(action.buttonLabel),
    );
  }

  Future<void> showMessageMenu(CompanyChatMessage message) async {
    final own = message.senderUserId == widget.profile.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Ответить'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (own || widget.profile.isAdmin)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Удалить'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'reply') {
      setState(() => replyTo = message);
    } else if (action == 'delete') {
      await deleteMessage(message);
    }
  }

  Widget buildComposer() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Ответ: ${replyTo!.senderName} — ${replyTo!.body.isEmpty ? 'вложение' : replyTo!.body}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => replyTo = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            if (pendingFiles.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pendingFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = pendingFiles[index];
                    return InputChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 17),
                      label: Text(
                        item.file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: sending
                          ? null
                          : () => setState(() => pendingFiles.removeAt(index)),
                    );
                  },
                ),
              ),
            if (askingAi)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'ИИ ответит в общий чат. Изменения останутся черновиком до подтверждения.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Прикрепить файл',
                  onPressed: sending ? null : pickFiles,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                IconButton(
                  tooltip: 'Упомянуть сотрудника',
                  onPressed: sending ? null : chooseMention,
                  icon: const Icon(Icons.alternate_email_rounded),
                ),
                if (canUseAi)
                  IconButton.filledTonal(
                    tooltip: askingAi ? 'Отключить ответ ИИ' : 'Спросить ИИ',
                    onPressed: sending
                        ? null
                        : () => setState(() => askingAi = !askingAi),
                    icon: Icon(
                      Icons.auto_awesome_rounded,
                      color: askingAi ? scheme.tertiary : null,
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: askingAi ? 'Спроси коллег и ИИ…' : 'Сообщение…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 7),
                IconButton.filled(
                  tooltip: 'Отправить',
                  onPressed: sending ? null : sendMessage,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _error(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    return '$bytes Б';
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}

class SupabaseSignedUrl {
  SupabaseSignedUrl._();

  static Future<String> create(CompanyChatAttachment attachment) {
    return CompanyChatRepository.createSignedAttachmentUrl(attachment);
  }
}
