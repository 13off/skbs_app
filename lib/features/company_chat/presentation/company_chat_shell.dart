import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/app_user_profile.dart';
import '../data/company_chat_repository.dart';
import '../models/company_chat_models.dart';

class CompanyChatShell extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const CompanyChatShell({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  State<CompanyChatShell> createState() => _CompanyChatShellState();
}

class _PendingChatFile {
  final XFile file;
  final int size;

  const _PendingChatFile({required this.file, required this.size});
}

class _CompanyChatShellState extends State<CompanyChatShell> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<CompanyChatMessage> messages = <CompanyChatMessage>[];
  final List<CompanyChatThread> threads = <CompanyChatThread>[];
  final List<_PendingChatFile> pendingFiles = <_PendingChatFile>[];

  StreamSubscription<void>? changesSubscription;
  Timer? refreshTimer;
  CompanyChatUnreadState unread = const CompanyChatUnreadState.empty();
  CompanyChatThread? selectedThread;
  bool panelOpen = false;
  bool loading = true;
  bool refreshing = false;
  bool sending = false;
  bool askingAi = false;
  String? errorText;
  double panelWidth = 760;
  double panelHeight = 560;
  int threadRequestSerial = 0;

  String get companyId => widget.profile.activeCompanyId.trim();

  String? get objectName {
    final clean = widget.profile.objectName.trim();
    return clean.isEmpty ? null : clean;
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant CompanyChatShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.id != widget.profile.id) {
      CompanyChatRepository.stopRealtime(
        companyId: oldWidget.profile.activeCompanyId,
      );
      refreshTimer?.cancel();
      changesSubscription?.cancel();
      messages.clear();
      threads.clear();
      pendingFiles.clear();
      unread = const CompanyChatUnreadState.empty();
      selectedThread = null;
      panelOpen = false;
      loading = true;
      refreshing = false;
      sending = false;
      askingAi = false;
      errorText = null;
      messageController.clear();
      threadRequestSerial += 1;
      start();
    }
  }

  void start() {
    if (companyId.isEmpty) {
      loading = false;
      errorText = 'Компания не выбрана';
      return;
    }
    CompanyChatRepository.startRealtime(companyId);
    changesSubscription = CompanyChatRepository.changes.listen((_) {
      refreshTimer?.cancel();
      refreshTimer = Timer(
        const Duration(milliseconds: 220),
        () => unawaited(refreshWorkspace(markAsRead: panelOpen)),
      );
    });
    unawaited(loadInitial());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    changesSubscription?.cancel();
    CompanyChatRepository.stopRealtime(companyId: companyId);
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadInitial() async {
    final request = ++threadRequestSerial;
    if (mounted) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }
    try {
      final values = await Future.wait<dynamic>([
        CompanyChatRepository.fetchThreads(),
        CompanyChatRepository.fetchUnreadState(),
      ]);
      if (!mounted || request != threadRequestSerial) return;
      final nextThreads = values[0] as List<CompanyChatThread>;
      final nextUnread = values[1] as CompanyChatUnreadState;
      final nextSelected = _resolveSelected(nextThreads, selectedThread?.threadKey);
      final nextMessages = nextSelected == null
          ? const <CompanyChatMessage>[]
          : await _fetchThreadMessages(nextSelected);
      if (!mounted || request != threadRequestSerial) return;
      setState(() {
        threads
          ..clear()
          ..addAll(nextThreads);
        unread = nextUnread;
        selectedThread = nextSelected;
        messages
          ..clear()
          ..addAll(nextMessages);
        loading = false;
        errorText = null;
      });
      if (panelOpen && nextSelected != null) {
        await markThreadRead(nextSelected, nextMessages);
      }
      scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted || request != threadRequestSerial) return;
      setState(() {
        loading = false;
        errorText = _error(error);
      });
    }
  }

  Future<void> refreshWorkspace({bool markAsRead = false}) async {
    if (refreshing || companyId.isEmpty) return;
    refreshing = true;
    final active = selectedThread;
    try {
      final values = await Future.wait<dynamic>([
        CompanyChatRepository.fetchThreads(),
        CompanyChatRepository.fetchUnreadState(),
        if (panelOpen && active != null) _fetchThreadMessages(active),
      ]);
      if (!mounted) return;
      final nextThreads = values[0] as List<CompanyChatThread>;
      var nextUnread = values[1] as CompanyChatUnreadState;
      final nextSelected = _resolveSelected(nextThreads, active?.threadKey);
      final nextMessages = panelOpen && active != null
          ? values[2] as List<CompanyChatMessage>
          : null;
      if (nextMessages != null &&
          nextSelected != null &&
          nextSelected.threadKey == active?.threadKey &&
          markAsRead) {
        await markThreadRead(nextSelected, nextMessages);
        final refreshed = await Future.wait<dynamic>([
          CompanyChatRepository.fetchThreads(),
          CompanyChatRepository.fetchUnreadState(),
        ]);
        if (!mounted) return;
        nextThreads
          ..clear()
          ..addAll(refreshed[0] as List<CompanyChatThread>);
        nextUnread = refreshed[1] as CompanyChatUnreadState;
      }
      if (!mounted) return;
      final resolved = _resolveSelected(nextThreads, nextSelected?.threadKey);
      setState(() {
        threads
          ..clear()
          ..addAll(nextThreads);
        unread = nextUnread;
        selectedThread = resolved;
        if (nextMessages != null && resolved?.threadKey == active?.threadKey) {
          messages
            ..clear()
            ..addAll(nextMessages);
        }
        errorText = null;
        loading = false;
      });
      if (panelOpen && nextMessages != null) scrollToBottom();
    } catch (_) {
      // Следующее realtime-событие повторит обновление.
    } finally {
      refreshing = false;
    }
  }

  CompanyChatThread? _resolveSelected(
    List<CompanyChatThread> values,
    String? preferredKey,
  ) {
    if (values.isEmpty) return null;
    if (preferredKey != null) {
      for (final item in values) {
        if (item.threadKey == preferredKey) return item;
      }
    }
    for (final item in values) {
      if (item.isGeneral) return item;
    }
    return values.first;
  }

  Future<List<CompanyChatMessage>> _fetchThreadMessages(
    CompanyChatThread thread,
  ) {
    return CompanyChatRepository.fetchFeed(
      limit: 120,
      channelKind: thread.channelKind,
      peerUserId: thread.peerUserId,
    );
  }

  Future<void> markThreadRead(
    CompanyChatThread thread,
    List<CompanyChatMessage> values,
  ) async {
    await CompanyChatRepository.markRead(
      at: values.isEmpty ? DateTime.now() : values.last.createdAt,
      channelKind: thread.channelKind,
      peerUserId: thread.peerUserId,
    );
  }

  Future<void> selectThread(CompanyChatThread thread) async {
    if (selectedThread?.threadKey == thread.threadKey || sending) return;
    final request = ++threadRequestSerial;
    setState(() {
      selectedThread = thread;
      messages.clear();
      pendingFiles.clear();
      messageController.clear();
      loading = true;
      errorText = null;
    });
    try {
      final next = await _fetchThreadMessages(thread);
      if (!mounted || request != threadRequestSerial) return;
      await markThreadRead(thread, next);
      final summaries = await Future.wait<dynamic>([
        CompanyChatRepository.fetchThreads(),
        CompanyChatRepository.fetchUnreadState(),
      ]);
      if (!mounted || request != threadRequestSerial) return;
      final nextThreads = summaries[0] as List<CompanyChatThread>;
      setState(() {
        threads
          ..clear()
          ..addAll(nextThreads);
        selectedThread = _resolveSelected(nextThreads, thread.threadKey);
        unread = summaries[1] as CompanyChatUnreadState;
        messages
          ..clear()
          ..addAll(next);
        loading = false;
      });
      scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted || request != threadRequestSerial) return;
      setState(() {
        loading = false;
        errorText = _error(error);
      });
    }
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
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void openPanel() {
    if (panelOpen) return;
    setState(() => panelOpen = true);
    unawaited(refreshWorkspace(markAsRead: true));
  }

  void collapsePanel() {
    setState(() => panelOpen = false);
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

  Future<void> sendMessage() async {
    final thread = selectedThread;
    final text = messageController.text.trim();
    if (thread == null || sending || (text.isEmpty && pendingFiles.isEmpty)) {
      return;
    }
    final files = List<_PendingChatFile>.from(pendingFiles);
    setState(() => sending = true);
    String? messageId;
    try {
      messageId = await CompanyChatRepository.createMessage(
        body: text,
        mentionedUserIds: const <String>[],
        clientNonce:
            '${widget.profile.id}-${DateTime.now().microsecondsSinceEpoch}',
        channelKind: thread.channelKind,
        peerUserId: thread.peerUserId,
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
      if (selectedThread?.threadKey == thread.threadKey) {
        messageController.clear();
        setState(() => pendingFiles.clear());
      }
      await refreshWorkspace(markAsRead: true);
      if (failed.isNotEmpty) {
        showMessage('Не загрузились: ${failed.join(', ')}');
      }

      if (thread.isAssistant) {
        setState(() => askingAi = true);
        try {
          await CompanyChatRepository.askAi(
            companyId: companyId,
            sourceMessageId: messageId,
            objectName: objectName,
          );
          await refreshWorkspace(markAsRead: true);
        } catch (error) {
          showMessage('ИИ не ответил: ${_error(error)}');
        } finally {
          if (mounted) setState(() => askingAi = false);
        }
      }
    } catch (error) {
      showMessage('Не удалось отправить: ${_error(error)}');
    } finally {
      if (mounted) setState(() => sending = false);
      scrollToBottom();
    }
  }

  Future<void> openAttachment(CompanyChatAttachment attachment) async {
    try {
      final url = await CompanyChatRepository.createSignedAttachmentUrl(
        attachment,
      );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось открыть файл');
    } catch (error) {
      showMessage('Не удалось открыть файл: ${_error(error)}');
    }
  }

  void resizePanel(
    DragUpdateDetails details, {
    required double minWidth,
    required double maxWidth,
    required double minHeight,
    required double maxHeight,
  }) {
    setState(() {
      panelWidth = (panelWidth - details.delta.dx)
          .clamp(minWidth, maxWidth)
          .toDouble();
      panelHeight = (panelHeight - details.delta.dy)
          .clamp(minHeight, maxHeight)
          .toDouble();
    });
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _error(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '').trim();
    return value.isEmpty ? 'Не удалось загрузить чат' : value;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final bottomOffset = padding.bottom + 92;
    final maxWidth = math.max(280.0, size.width - 24).toDouble();
    final maxHeight = math
        .max(300.0, size.height - bottomOffset - padding.top - 12)
        .toDouble();
    final minWidth = math.min(560.0, maxWidth).toDouble();
    final minHeight = math.min(380.0, maxHeight).toDouble();
    final shownWidth = panelWidth.clamp(minWidth, maxWidth).toDouble();
    final shownHeight = panelHeight.clamp(minHeight, maxHeight).toDouble();

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 12,
          bottom: bottomOffset,
          child: SafeArea(
            top: false,
            left: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: panelOpen
                  ? SizedBox(
                      key: const ValueKey<String>('company-chat-workspace'),
                      width: shownWidth,
                      height: shownHeight,
                      child: _ChatWorkspacePanel(
                        currentUserId: widget.profile.id,
                        threads: threads,
                        selectedThread: selectedThread,
                        messages: messages,
                        unread: unread,
                        loading: loading,
                        errorText: errorText,
                        sending: sending,
                        askingAi: askingAi,
                        pendingFiles: pendingFiles,
                        messageController: messageController,
                        scrollController: scrollController,
                        onSelectThread: selectThread,
                        onCollapse: collapsePanel,
                        onRetry: loadInitial,
                        onPickFiles: pickFiles,
                        onRemovePending: (item) {
                          setState(() => pendingFiles.remove(item));
                        },
                        onSend: sendMessage,
                        onOpenAttachment: openAttachment,
                        onResize: (details) => resizePanel(
                          details,
                          minWidth: minWidth,
                          maxWidth: maxWidth,
                          minHeight: minHeight,
                          maxHeight: maxHeight,
                        ),
                      ),
                    )
                  : _ChatLauncherButton(
                      key: const ValueKey<String>('company-chat-launcher'),
                      unread: unread,
                      onPressed: openPanel,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatWorkspacePanel extends StatelessWidget {
  final String currentUserId;
  final List<CompanyChatThread> threads;
  final CompanyChatThread? selectedThread;
  final List<CompanyChatMessage> messages;
  final CompanyChatUnreadState unread;
  final bool loading;
  final String? errorText;
  final bool sending;
  final bool askingAi;
  final List<_PendingChatFile> pendingFiles;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final ValueChanged<CompanyChatThread> onSelectThread;
  final VoidCallback onCollapse;
  final VoidCallback onRetry;
  final VoidCallback onPickFiles;
  final ValueChanged<_PendingChatFile> onRemovePending;
  final VoidCallback onSend;
  final ValueChanged<CompanyChatAttachment> onOpenAttachment;
  final ValueChanged<DragUpdateDetails> onResize;

  const _ChatWorkspacePanel({
    required this.currentUserId,
    required this.threads,
    required this.selectedThread,
    required this.messages,
    required this.unread,
    required this.loading,
    required this.errorText,
    required this.sending,
    required this.askingAi,
    required this.pendingFiles,
    required this.messageController,
    required this.scrollController,
    required this.onSelectThread,
    required this.onCollapse,
    required this.onRetry,
    required this.onPickFiles,
    required this.onRemovePending,
    required this.onSend,
    required this.onOpenAttachment,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Material(
          elevation: 18,
          shadowColor: Colors.black.withValues(alpha: 0.28),
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _ThreadSidebar(
                  threads: threads,
                  selectedThread: selectedThread,
                  onSelectThread: onSelectThread,
                ),
                VerticalDivider(width: 1, color: scheme.outlineVariant),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(context),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Expanded(child: _body(context)),
                      _composer(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: onResize,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thread = selectedThread;
    final subtitle = thread == null
        ? 'Выберите диалог слева'
        : thread.isGeneral
        ? 'Общий чат сотрудников'
        : thread.isAssistant
        ? 'Личный диалог с ИИ-помощником'
        : AppUserProfile.titleForRole(thread.role);
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(16, 9, 7, 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: thread?.isAssistant == true
                  ? scheme.tertiaryContainer
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              thread?.isAssistant == true
                  ? Icons.auto_awesome_rounded
                  : thread?.isDirect == true
                  ? Icons.person_rounded
                  : Icons.forum_rounded,
              color: thread?.isAssistant == true
                  ? scheme.onTertiaryContainer
                  : scheme.onPrimaryContainer,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread?.title ?? 'Чаты',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (unread.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _UnreadBadge(count: unread.unreadCount),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Свернуть',
            onPressed: onCollapse,
            icon: const Icon(Icons.remove_rounded, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (loading && messages.isEmpty) {
      return const Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (errorText != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              const Text(
                'Чаты пока не загрузились',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                errorText!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (selectedThread == null) {
      return const Center(child: Text('Выберите диалог слева'));
    }
    if (messages.isEmpty) {
      final assistant = selectedThread!.isAssistant;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: assistant
                      ? scheme.tertiaryContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  assistant
                      ? Icons.auto_awesome_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: assistant
                      ? scheme.onTertiaryContainer
                      : scheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                assistant ? 'Спроси ИИ-помощника' : 'Сообщений пока нет',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                assistant
                    ? 'Помощник работает в отдельном личном диалоге и не отправляет ответы в общий чат.'
                    : 'Напишите первое сообщение или прикрепите фото и файл.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.5),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: messages.length,
        itemBuilder: (context, index) => _messageBubble(
          context,
          messages[index],
        ),
      ),
    );
  }

  Widget _messageBubble(BuildContext context, CompanyChatMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final own = message.senderUserId == currentUserId;
    final assistant = message.isAssistant;
    final alignment = own ? Alignment.centerRight : Alignment.centerLeft;
    final color = assistant
        ? scheme.tertiaryContainer
        : own
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final body = message.isDeleted ? 'Сообщение удалено' : message.body.trim();

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!own || selectedThread?.isGeneral == true || assistant) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    assistant
                        ? Icons.auto_awesome_rounded
                        : Icons.person_rounded,
                    size: 12,
                    color: assistant
                        ? scheme.tertiary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      assistant ? 'ИИ-помощник' : message.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (body.isNotEmpty)
              SelectableText(
                body,
                style: TextStyle(
                  color: message.isDeleted
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                  fontSize: 12.5,
                  height: 1.35,
                  fontStyle: message.isDeleted
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (message.attachments.isNotEmpty) ...[
              if (body.isNotEmpty) const SizedBox(height: 7),
              ...message.attachments.map(
                (attachment) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Material(
                    color: scheme.surface.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onOpenAttachment(attachment),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              attachment.isImage
                                  ? Icons.image_outlined
                                  : Icons.attach_file_rounded,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                attachment.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _fileSize(attachment.sizeBytes),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _time(message.createdAt),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assistant = selectedThread?.isAssistant == true;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingFiles.isNotEmpty)
            SizedBox(
              height: 47,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
                itemCount: pendingFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final item = pendingFiles[index];
                  return InputChip(
                    avatar: Icon(
                      _isImageName(item.file.name)
                          ? Icons.image_outlined
                          : Icons.attach_file_rounded,
                      size: 16,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        item.file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onDeleted: sending ? null : () => onRemovePending(item),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Прикрепить фото или файл',
                  onPressed: sending || selectedThread == null
                      ? null
                      : onPickFiles,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: !sending && selectedThread != null,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: assistant
                          ? 'Сообщение ИИ-помощнику…'
                          : 'Сообщение…',
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.62,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: assistant ? 'Отправить ИИ' : 'Отправить',
                  onPressed: sending || askingAi || selectedThread == null
                      ? null
                      : onSend,
                  icon: sending || askingAi
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          assistant
                              ? Icons.auto_awesome_rounded
                              : Icons.send_rounded,
                          size: 19,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
}

class _ThreadSidebar extends StatelessWidget {
  final List<CompanyChatThread> threads;
  final CompanyChatThread? selectedThread;
  final ValueChanged<CompanyChatThread> onSelectThread;

  const _ThreadSidebar({
    required this.threads,
    required this.selectedThread,
    required this.onSelectThread,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final general = threads.where((item) => item.isGeneral).toList();
    final direct = threads.where((item) => item.isDirect).toList();
    final assistant = threads.where((item) => item.isAssistant).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(230.0, math.max(150.0, constraints.maxWidth * 0.31));
        return SizedBox(
          width: width,
          child: ColoredBox(
            color: scheme.surfaceContainerLowest.withValues(alpha: 0.72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 15, 12, 8),
                  child: Text(
                    'Чаты',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (general.isNotEmpty)
                  _ThreadTile(
                    thread: general.first,
                    selected: selectedThread?.threadKey == general.first.threadKey,
                    onTap: () => onSelectThread(general.first),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Text(
                    'СОТРУДНИКИ',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: direct.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Нет других пользователей компании',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: direct.length,
                          itemBuilder: (context, index) {
                            final item = direct[index];
                            return _ThreadTile(
                              thread: item,
                              selected:
                                  selectedThread?.threadKey == item.threadKey,
                              onTap: () => onSelectThread(item),
                            );
                          },
                        ),
                ),
                if (assistant.isNotEmpty) ...[
                  Divider(height: 1, color: scheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _ThreadTile(
                      thread: assistant.first,
                      selected:
                          selectedThread?.threadKey == assistant.first.threadKey,
                      onTap: () => onSelectThread(assistant.first),
                      assistant: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final CompanyChatThread thread;
  final bool selected;
  final VoidCallback onTap;
  final bool assistant;

  const _ThreadTile({
    required this.thread,
    required this.selected,
    required this.onTap,
    this.assistant = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = thread.lastMessagePreview.isNotEmpty
        ? thread.lastMessagePreview
        : thread.isDirect
        ? AppUserProfile.titleForRole(thread.role)
        : thread.isAssistant
        ? 'Помощник AppСтрой'
        : 'Для всей компании';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? (assistant
                  ? scheme.tertiaryContainer
                  : scheme.primaryContainer)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: assistant
                      ? scheme.tertiaryContainer
                      : selected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  foregroundColor: assistant
                      ? scheme.onTertiaryContainer
                      : selected
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  child: assistant
                      ? const Icon(Icons.auto_awesome_rounded, size: 17)
                      : thread.isGeneral
                      ? const Icon(Icons.groups_rounded, size: 18)
                      : Text(
                          _initials(thread.title),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (thread.unreadCount > 0) ...[
                  const SizedBox(width: 5),
                  _UnreadBadge(count: thread.unreadCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatLauncherButton extends StatelessWidget {
  final CompanyChatUnreadState unread;
  final VoidCallback onPressed;

  const _ChatLauncherButton({
    super.key,
    required this.unread,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = unread.unreadCount;
    return Semantics(
      button: true,
      label: count > 0 ? 'Открыть чат, непрочитанных: $count' : 'Открыть чат',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: scheme.primary,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.24),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 54,
                child: Icon(
                  count > 0
                      ? Icons.mark_chat_unread_rounded
                      : Icons.chat_bubble_rounded,
                  color: scheme.onPrimary,
                  size: 24,
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -5,
              child: _UnreadBadge(count: count),
            ),
        ],
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  return parts.map((item) => item.characters.first.toUpperCase()).join();
}

bool _isImageName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic');
}

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  return 'application/octet-stream';
}
