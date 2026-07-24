import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../data/company_chat_repository.dart';
import '../models/company_chat_models.dart';
import 'company_chat_screen.dart';

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

class _CompanyChatShellState extends State<CompanyChatShell> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<CompanyChatMessage> messages = <CompanyChatMessage>[];

  StreamSubscription<void>? changesSubscription;
  Timer? refreshTimer;
  CompanyChatUnreadState unread = const CompanyChatUnreadState.empty();
  bool panelOpen = true;
  bool loading = true;
  bool refreshing = false;
  bool sending = false;
  String? errorText;

  String get companyId => widget.profile.activeCompanyId.trim();

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
      unread = const CompanyChatUnreadState.empty();
      panelOpen = true;
      loading = true;
      refreshing = false;
      sending = false;
      errorText = null;
      messageController.clear();
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
        () => refreshChat(markAsRead: panelOpen),
      );
    });
    unawaited(refreshChat(markAsRead: panelOpen));
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

  Future<void> refreshChat({bool markAsRead = false}) async {
    if (refreshing || companyId.isEmpty) return;
    refreshing = true;
    try {
      final values = await Future.wait<dynamic>([
        CompanyChatRepository.fetchUnreadState(),
        CompanyChatRepository.fetchFeed(limit: 24),
      ]);
      if (!mounted) return;

      final nextMessages = values[1] as List<CompanyChatMessage>;
      var nextUnread = values[0] as CompanyChatUnreadState;
      if (markAsRead && nextMessages.isNotEmpty) {
        try {
          await CompanyChatRepository.markRead(
            at: nextMessages.last.createdAt,
          );
          nextUnread = const CompanyChatUnreadState.empty();
        } catch (_) {
          // Чат остаётся доступным, даже если отметка прочтения временно не прошла.
        }
      }
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(nextMessages);
        unread = nextUnread;
        loading = false;
        errorText = null;
      });
      if (panelOpen) scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = _error(error);
      });
    } finally {
      refreshing = false;
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void openPanel() {
    if (panelOpen) return;
    setState(() => panelOpen = true);
    unawaited(refreshChat(markAsRead: true));
    scrollToBottom();
  }

  void collapsePanel() {
    setState(() => panelOpen = false);
  }

  Future<void> openChat() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => CompanyChatScreen(profile: widget.profile),
      ),
    );
    if (!mounted) return;
    await refreshChat(markAsRead: panelOpen);
  }

  Future<void> sendCompactMessage() async {
    final text = messageController.text.trim();
    if (sending || text.isEmpty || companyId.isEmpty) return;
    setState(() => sending = true);
    try {
      await CompanyChatRepository.createMessage(
        body: text,
        mentionedUserIds: const <String>[],
        clientNonce:
            '${widget.profile.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      messageController.clear();
      await refreshChat(markAsRead: true);
      scrollToBottom();
    } catch (error) {
      showMessage('Не удалось отправить: ${_error(error)}');
    } finally {
      if (mounted) setState(() => sending = false);
    }
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
    final panelWidth = math.min(386.0, math.max(300.0, size.width - 24)).toDouble();
    final availableHeight = size.height - bottomOffset - padding.top - 12;
    final panelHeight = math
        .min(520.0, math.max(310.0, availableHeight))
        .toDouble();

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
                      key: const ValueKey<String>('company-chat-panel'),
                      width: panelWidth,
                      height: panelHeight,
                      child: _CompactChatPanel(
                        currentUserId: widget.profile.id,
                        messages: messages,
                        unread: unread,
                        loading: loading,
                        errorText: errorText,
                        sending: sending,
                        messageController: messageController,
                        scrollController: scrollController,
                        onCollapse: collapsePanel,
                        onOpenFull: openChat,
                        onRetry: () => refreshChat(markAsRead: true),
                        onSend: sendCompactMessage,
                      ),
                    )
                  : _ChatLauncherPill(
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

class _CompactChatPanel extends StatelessWidget {
  final String currentUserId;
  final List<CompanyChatMessage> messages;
  final CompanyChatUnreadState unread;
  final bool loading;
  final String? errorText;
  final bool sending;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onCollapse;
  final VoidCallback onOpenFull;
  final VoidCallback onRetry;
  final VoidCallback onSend;

  const _CompactChatPanel({
    required this.currentUserId,
    required this.messages,
    required this.unread,
    required this.loading,
    required this.errorText,
    required this.sending,
    required this.messageController,
    required this.scrollController,
    required this.onCollapse,
    required this.onOpenFull,
    required this.onRetry,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
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
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(13, 9, 7, 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: scheme.onPrimaryContainer,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Чат компании',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (unread.unreadCount > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: unread.mentionCount > 0
                              ? scheme.error
                              : scheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          unread.unreadCount > 99
                              ? '99+'
                              : '${unread.unreadCount}',
                          style: TextStyle(
                            color: unread.mentionCount > 0
                                ? scheme.onError
                                : scheme.onPrimary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Общий чат · ИИ-помощник внутри',
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
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Открыть на весь экран',
            onPressed: onOpenFull,
            icon: const Icon(Icons.open_in_full_rounded, size: 18),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Свернуть чат',
            onPressed: onCollapse,
            icon: const Icon(Icons.remove_rounded, size: 21),
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
                'Чат пока не загрузился',
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
    if (messages.isEmpty) {
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
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.waving_hand_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Сообщений пока нет',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                'Напиши первое сообщение. Файлы, упоминания и ИИ доступны в полном чате.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              TextButton.icon(
                onPressed: onOpenFull,
                icon: const Icon(Icons.open_in_full_rounded, size: 17),
                label: const Text('Открыть полный чат'),
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
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
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
    final alignment = assistant
        ? Alignment.center
        : own
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = assistant
        ? scheme.tertiaryContainer
        : own
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final body = message.isDeleted
        ? 'Сообщение удалено'
        : message.body.trim().isEmpty
        ? (message.attachments.isEmpty
              ? 'Сообщение'
              : 'Вложений: ${message.attachments.length}')
        : message.body.trim();

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
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
                  size: 12,
                  color: assistant
                      ? scheme.tertiary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    assistant ? 'ИИ-помощник AppСтрой' : message.senderName,
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
            Text(
              body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: message.isDeleted
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
                fontSize: 12,
                height: 1.3,
                fontStyle: message.isDeleted
                    ? FontStyle.italic
                    : FontStyle.normal,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Файлы, упоминания и ИИ',
            onPressed: onOpenFull,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          Expanded(
            child: TextField(
              controller: messageController,
              enabled: !sending,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Сообщение в чат…',
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
                  vertical: 9,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Отправить',
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatLauncherPill extends StatelessWidget {
  final CompanyChatUnreadState unread;
  final VoidCallback onPressed;

  const _ChatLauncherPill({
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
      label: count > 0 ? 'Чат компании, непрочитанных: $count' : 'Чат компании',
      child: Material(
        color: scheme.primary,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unread.mentionCount > 0
                      ? Icons.mark_chat_unread_rounded
                      : Icons.forum_rounded,
                  color: scheme.onPrimary,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Text(
                  'Чат компании',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: unread.mentionCount > 0
                          ? scheme.error
                          : scheme.tertiary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: unread.mentionCount > 0
                            ? scheme.onError
                            : scheme.onTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
