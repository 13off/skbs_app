from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


path = "lib/features/recruitment/presentation/recruitment_application_detail_screen.dart"

replace_once(
    path,
    """  bool sending = false;
  String? openingId;
""",
    """  bool sending = false;
  bool downloadingArchive = false;
  String? openingId;
  final Set<String> downloadingIds = <String>{};
  final Map<String, Future<String>> previewUrlFutures =
      <String, Future<String>>{};
""",
    "detail state",
)

replace_once(
    path,
    """    if (mounted) {
      setState(() {
        documentsFuture = documents;
        messagesFuture = messages;
      });
    }
""",
    """    if (mounted) {
      setState(() {
        previewUrlFutures.clear();
        documentsFuture = documents;
        messagesFuture = messages;
      });
    }
""",
    "clear preview cache",
)

replace_once(
    path,
    """  Future<void> sendMessage() async {
""",
    """  Future<String> previewUrl(RecruitmentDocument document) {
    return previewUrlFutures.putIfAbsent(
      document.id,
      () => RecruitmentRepository.createSignedFileUrl(
        bucket: document.storageBucket,
        path: document.storagePath,
        expiresInSeconds: 900,
      ),
    );
  }

  String downloadName(RecruitmentDocument document) {
    final original = document.originalName.trim();
    if (original.isNotEmpty) return original;
    final extension = document.mimeType == 'application/pdf' ? 'pdf' : 'jpg';
    return '${document.title}.$extension';
  }

  Future<void> downloadDocument(RecruitmentDocument document) async {
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

  Future<void> downloadAllDocuments() async {
    if (downloadingArchive) return;
    setState(() => downloadingArchive = true);
    try {
      final url = await RecruitmentRepository.createDocumentsArchiveUrl(
        applicationId: widget.application.id,
      );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось начать скачивание ZIP');
    } catch (error) {
      showError('Не удалось скачать архив: $error');
    } finally {
      if (mounted) setState(() => downloadingArchive = false);
    }
  }

  Future<void> showImagePreview(RecruitmentDocument document) async {
    try {
      final url = await previewUrl(document);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (dialogContext) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 6,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'Не удалось показать изображение',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton.filled(
                          tooltip: 'Скачать',
                          onPressed: () => downloadDocument(document),
                          icon: const Icon(Icons.download_rounded),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      showError('Не удалось открыть изображение: $error');
    }
  }

  Widget imagePreview(RecruitmentDocument document) {
    return FutureBuilder<String>(
      future: previewUrl(document),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AspectRatio(
            aspectRatio: 4 / 3,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const AspectRatio(
            aspectRatio: 4 / 3,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 42),
            ),
          );
        }
        return GestureDetector(
          onTap: () => showImagePreview(document),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 42),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 17),
                        SizedBox(width: 5),
                        Text(
                          'Увеличить',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> sendMessage() async {
""",
    "download and preview methods",
)

start = """  Widget documentCard(RecruitmentDocument document) {
    final waiting = !document.isStored;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: waiting
                    ? const Color(0xFFFFF4E2)
                    : const Color(0xFFE8F4ED),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                document.mimeType == 'application/pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
                color: waiting ? const Color(0xFF9A6816) : _detailSuccess,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      color: _detailText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    waiting
                        ? 'Файл обрабатывается'
                        : <String>[
                            if (document.originalName.isNotEmpty)
                              document.originalName,
                            if (formatBytes(document.sizeBytes).isNotEmpty)
                              formatBytes(document.sizeBytes),
                          ].join(' · '),
                    style: const TextStyle(
                      color: _detailMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: waiting ? 'Файл ещё загружается' : 'Открыть документ',
              onPressed: waiting || openingId != null
                  ? null
                  : () => openStoredFile(
                      id: document.id,
                      bucket: document.storageBucket,
                      path: document.storagePath,
                    ),
              icon: openingId == document.id
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ),
      ),
    );
  }
"""

replacement = """  Widget documentCard(RecruitmentDocument document) {
    final waiting = !document.isStored;
    final downloading = downloadingIds.contains(document.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!waiting && document.isImage) imagePreview(document),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: waiting
                              ? const Color(0xFFFFF4E2)
                              : const Color(0xFFE8F4ED),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          document.mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          color: waiting
                              ? const Color(0xFF9A6816)
                              : _detailSuccess,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.title,
                              style: const TextStyle(
                                color: _detailText,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              waiting
                                  ? 'Файл обрабатывается'
                                  : <String>[
                                      if (document.originalName.isNotEmpty)
                                        document.originalName,
                                      if (formatBytes(document.sizeBytes).isNotEmpty)
                                        formatBytes(document.sizeBytes),
                                    ].join(' · '),
                              style: const TextStyle(
                                color: _detailMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: waiting || openingId != null
                              ? null
                              : document.isImage
                              ? () => showImagePreview(document)
                              : () => openStoredFile(
                                  id: document.id,
                                  bucket: document.storageBucket,
                                  path: document.storagePath,
                                ),
                          icon: Icon(
                            document.isImage
                                ? Icons.visibility_outlined
                                : Icons.open_in_new_rounded,
                          ),
                          label: Text(document.isImage ? 'Открыть' : 'Просмотр'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: waiting || downloading
                              ? null
                              : () => downloadDocument(document),
                          icon: downloading
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Скачать'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
"""
replace_once(path, start, replacement, "document card")

replace_once(
    path,
    """        final documents = snapshot.data ?? const <RecruitmentDocument>[];
        if (documents.isEmpty) {
          return const _DetailMessage(
            icon: Icons.folder_open_outlined,
            text: 'Кандидат пока не прислал документы.',
          );
        }
        return Column(children: documents.map(documentCard).toList());
""",
    """        final documents = snapshot.data ?? const <RecruitmentDocument>[];
        if (documents.isEmpty) {
          return const _DetailMessage(
            icon: Icons.folder_open_outlined,
            text: 'Кандидат пока не прислал документы.',
          );
        }
        final storedCount = documents.where((item) => item.isStored).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (storedCount > 0) ...[
              SizedBox(
                height: 50,
                child: FilledButton.tonalIcon(
                  onPressed: downloadingArchive ? null : downloadAllDocuments,
                  icon: downloadingArchive
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_zip_outlined),
                  label: Text(
                    downloadingArchive
                        ? 'Собираем архив...'
                        : 'Скачать все ZIP · $storedCount',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...documents.map(documentCard),
          ],
        );
""",
    "download all documents",
)
