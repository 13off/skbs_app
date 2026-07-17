from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


screen = "lib/features/recruitment/presentation/recruitment_application_detail_screen.dart"

replace_once(
    screen,
    """  final TextEditingController messageController = TextEditingController();
  late Future<List<RecruitmentDocument>> documentsFuture;
""",
    """  final TextEditingController messageController = TextEditingController();
  final ScrollController messageScrollController = ScrollController();
  late Future<List<RecruitmentDocument>> documentsFuture;
""",
    "message scroll controller",
)

replace_once(
    screen,
    """  String? openingId;
  final Set<String> downloadingIds = <String>{};
""",
    """  String? openingId;
  int renderedMessageCount = -1;
  final Set<String> downloadingIds = <String>{};
""",
    "message count state",
)

replace_once(
    screen,
    """    changesSubscription?.cancel();
    messageController.dispose();
    super.dispose();
""",
    """    changesSubscription?.cancel();
    messageController.dispose();
    messageScrollController.dispose();
    super.dispose();
""",
    "dispose scroll controller",
)

replace_once(
    screen,
    """  Future<void> refresh() async {
    final documents = loadDocuments();
    final messages = loadMessages();
    if (mounted) {
      setState(() {
        documentsFuture = documents;
        messagesFuture = messages;
      });
    }
    await Future.wait(<Future<Object?>>[documents, messages]);
  }
""",
    """  Future<void> refresh() async {
    final documents = loadDocuments();
    final messages = loadMessages();
    if (mounted) {
      setState(() {
        documentsFuture = documents;
        messagesFuture = messages;
      });
    }
    await Future.wait(<Future<Object?>>[documents, messages]);
  }

  void scrollMessagesToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !messageScrollController.hasClients) return;
      final target = messageScrollController.position.maxScrollExtent;
      if (animate) {
        messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else {
        messageScrollController.jumpTo(target);
      }
    });
  }
""",
    "scroll helper",
)

replace_once(
    screen,
    """  Future<void> downloadDocument(RecruitmentDocument document) async {
    if (!document.isStored || downloadingIds.contains(document.id)) return;
    setState(() => downloadingIds.add(document.id));
    try {
      final url = await RecruitmentRepository.createDownloadFileUrl(
        bucket: document.storageBucket,
        path: document.storagePath,
        fileName: downloadName(document),
      );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось начать скачивание');
    } catch (error) {
      showError('Не удалось скачать файл: $error');
    } finally {
      if (mounted) setState(() => downloadingIds.remove(document.id));
    }
  }
""",
    """  Future<void> downloadDocument(RecruitmentDocument document) async {
    if (!document.isStored || downloadingIds.contains(document.id)) return;
    setState(() => downloadingIds.add(document.id));
    try {
      final url = await RecruitmentRepository.createDownloadFileUrl(
        bucket: document.storageBucket,
        path: document.storagePath,
        fileName: downloadName(document),
      );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось начать скачивание');
    } catch (error) {
      showError('Не удалось скачать файл: $error');
    } finally {
      if (mounted) setState(() => downloadingIds.remove(document.id));
    }
  }

  String messageAttachmentExtension(RecruitmentMessage message) {
    final original = message.originalName.trim().toLowerCase();
    final dot = original.lastIndexOf('.');
    if (dot >= 0 && dot < original.length - 1) {
      final extension = original.substring(dot + 1);
      if (<String>{'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(extension)) {
        return extension == 'jpeg' ? 'jpg' : extension;
      }
    }
    switch (message.mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  String messageAttachmentName(RecruitmentMessage message) {
    final original = message.originalName.trim();
    if (original.isNotEmpty) return original;
    final candidate = safeFilePart(widget.application.fullName);
    final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
    return 'Вложение_${suffix}_${message.id.substring(0, 8)}.${messageAttachmentExtension(message)}';
  }

  Future<void> downloadMessageAttachment(RecruitmentMessage message) async {
    if (!message.isStoredAttachment || downloadingIds.contains(message.id)) {
      return;
    }
    setState(() => downloadingIds.add(message.id));
    try {
      final url = await RecruitmentRepository.createDownloadFileUrl(
        bucket: message.storageBucket,
        path: message.storagePath,
        fileName: messageAttachmentName(message),
      );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось начать скачивание');
    } catch (error) {
      showError('Не удалось скачать вложение: $error');
    } finally {
      if (mounted) setState(() => downloadingIds.remove(message.id));
    }
  }
""",
    "message attachment download",
)

old_bubble = """  Widget messageBubble(RecruitmentMessage message) {
    final inbound = message.isInbound;
    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
        decoration: BoxDecoration(
          color: inbound ? Colors.white : const Color(0xFFE8ECEF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: const TextStyle(
                  color: _detailText,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (message.hasAttachment) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              TextButton.icon(
                onPressed: message.isStoredAttachment && openingId == null
                    ? () => openStoredFile(
                        id: message.id,
                        bucket: message.storageBucket,
                        path: message.storagePath,
                        title: message.originalName.isEmpty
                            ? 'Вложение кандидата'
                            : message.originalName,
                        isImage: message.mimeType.startsWith('image/'),
                      )
                    : null,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  message.isStoredAttachment
                      ? (message.originalName.isEmpty
                            ? 'Открыть вложение'
                            : message.originalName)
                      : 'Вложение обрабатывается',
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${inbound ? 'Кандидат' : 'HR'} · ${formatDate(message.createdAt)}',
              style: const TextStyle(
                color: _detailMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
"""

new_bubble = """  Widget messageBubble(RecruitmentMessage message) {
    final inbound = message.isInbound;
    final downloading = downloadingIds.contains(message.id);
    final attachmentTitle = messageAttachmentName(message);
    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(
          color: inbound ? Colors.white : const Color(0xFFDCEEFF),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(inbound ? 5 : 17),
            bottomRight: Radius.circular(inbound ? 17 : 5),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: const TextStyle(
                  color: _detailText,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (message.hasAttachment) ...[
              if (message.text.isNotEmpty) const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          message.mimeType.startsWith('image/')
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 20,
                          color: _detailMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            message.isStoredAttachment
                                ? attachmentTitle
                                : 'Вложение обрабатывается',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _detailText,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed:
                                message.isStoredAttachment && openingId == null
                                ? () => openStoredFile(
                                    id: message.id,
                                    bucket: message.storageBucket,
                                    path: message.storagePath,
                                    title: attachmentTitle,
                                    isImage: message.mimeType.startsWith('image/'),
                                  )
                                : null,
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('Открыть'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: message.isStoredAttachment && !downloading
                                ? () => downloadMessageAttachment(message)
                                : null,
                            icon: downloading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Скачать'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${inbound ? 'Кандидат' : 'HR'} · ${formatDate(message.createdAt)}',
                style: const TextStyle(
                  color: _detailMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
"""
replace_once(screen, old_bubble, new_bubble, "telegram style bubbles")

old_conversation = """  Widget conversationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<List<RecruitmentMessage>>(
          future: messagesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _DetailMessage(
                icon: Icons.error_outline_rounded,
                text: 'Не удалось загрузить переписку: ${snapshot.error}',
              );
            }
            final messages = snapshot.data ?? const <RecruitmentMessage>[];
            if (messages.isEmpty) {
              return const _DetailMessage(
                icon: Icons.forum_outlined,
                text: 'Переписка пока не начата.',
              );
            }
            return Column(children: messages.map(messageBubble).toList());
          },
        ),
        const SizedBox(height: 10),
        if (widget.application.canMessageInTelegram)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Сообщение кандидату через бота',
                    prefixIcon: Icon(Icons.telegram),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 52,
                height: 52,
                child: FilledButton(
                  onPressed: sending ? null : sendMessage,
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          )
        else
          const _DetailMessage(
            icon: Icons.info_outline_rounded,
            text:
                'Эта заявка создана не через Telegram-бота. Для связи используйте номер телефона.',
          ),
      ],
    );
  }
"""

new_conversation = """  Widget conversationSection() {
    return Container(
      height: 470,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<RecruitmentMessage>>(
              future: messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _DetailMessage(
                        icon: Icons.error_outline_rounded,
                        text: 'Не удалось загрузить переписку: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                final messages = snapshot.data ?? const <RecruitmentMessage>[];
                if (messages.length != renderedMessageCount) {
                  final animate = renderedMessageCount >= 0;
                  renderedMessageCount = messages.length;
                  scrollMessagesToBottom(animate: animate);
                }
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: _DetailMessage(
                        icon: Icons.forum_outlined,
                        text: 'Переписка пока не начата.',
                      ),
                    ),
                  );
                }
                return Scrollbar(
                  controller: messageScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: messageScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, index) => messageBubble(messages[index]),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE1E4E8))),
            ),
            child: widget.application.canMessageInTelegram
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          enabled: !sending,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Сообщение',
                            prefixIcon: const Icon(Icons.telegram),
                            filled: true,
                            fillColor: const Color(0xFFF3F5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          onPressed: sending ? null : sendMessage,
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ),
                    ],
                  )
                : const _DetailMessage(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Эта заявка создана не через Telegram-бота. Для связи используйте номер телефона.',
                  ),
          ),
        ],
      ),
    );
  }
"""
replace_once(screen, old_conversation, new_conversation, "fixed chat window")

old_viewer = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
"""

new_viewer = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Material(
                color: Colors.white,
                elevation: 8,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Назад',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.black,
                    size: 27,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 68,
              right: 16,
              top: 17,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
"""
replace_once(screen, old_viewer, new_viewer, "visible image back button")


test = "test/recruitment_documents_chat_contract_test.dart"
replace_once(
    test,
    """    expect(detail, contains('class _RecruitmentImageViewer'));
    expect(detail, contains('InteractiveViewer('));
    expect(detail, contains('Image.memory('));
""",
    """    expect(detail, contains('class _RecruitmentImageViewer'));
    expect(detail, contains('InteractiveViewer('));
    expect(detail, contains('Image.memory('));
    expect(detail, contains("tooltip: 'Назад'"));
    expect(detail, contains('Icons.arrow_back_rounded'));
""",
    "image viewer back contract",
)

replace_once(
    test,
    """    expect(detail, contains('sendCandidateMessage'));
    expect(detail, contains('createSignedFileUrl'));
""",
    """    expect(detail, contains('sendCandidateMessage'));
    expect(detail, contains('createSignedFileUrl'));
    expect(detail, contains('height: 470'));
    expect(detail, contains('ListView.builder('));
    expect(detail, contains('messageScrollController'));
    expect(detail, contains('scrollMessagesToBottom'));
    expect(detail, contains('downloadMessageAttachment'));
    expect(detail, contains("label: const Text('Скачать')"));
""",
    "chat window contract",
)
