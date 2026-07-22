import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';

Color get _detailText => AppAdaptivePalette.textPrimary;
Color get _detailMuted => AppAdaptivePalette.textMuted;
Color get _detailSoft => AppAdaptivePalette.surfaceSoft;
Color get _detailSuccess => AppAdaptivePalette.success;
Color get _detailSurface => AppAdaptivePalette.surfaceElevated;
Color get _detailBorder => AppAdaptivePalette.border;
Color get _detailInput => AppAdaptivePalette.inputSurface;
Color get _detailWarning => AppAdaptivePalette.warning;

class RecruitmentApplicationDetailScreen extends StatefulWidget {
  final AppUserProfile profile;
  final RecruitmentApplication application;

  const RecruitmentApplicationDetailScreen({
    super.key,
    required this.profile,
    required this.application,
  });

  @override
  State<RecruitmentApplicationDetailScreen> createState() =>
      _RecruitmentApplicationDetailScreenState();
}

class _RecruitmentApplicationDetailScreenState
    extends State<RecruitmentApplicationDetailScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController messageScrollController = ScrollController();
  late Future<List<RecruitmentDocument>> documentsFuture;
  late Future<List<RecruitmentMessage>> messagesFuture;
  StreamSubscription<AppDataChange>? changesSubscription;
  bool sending = false;
  bool downloadingArchive = false;
  String? openingId;
  int renderedMessageCount = -1;
  final Set<String> downloadingIds = <String>{};

  @override
  void initState() {
    super.initState();
    documentsFuture = loadDocuments();
    messagesFuture = loadMessages();
    changesSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.recruitment) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    changesSubscription?.cancel();
    messageController.dispose();
    messageScrollController.dispose();
    super.dispose();
  }

  Future<List<RecruitmentDocument>> loadDocuments() {
    return RecruitmentRepository.fetchDocuments(
      companyId: widget.profile.activeCompanyId,
      applicationId: widget.application.id,
    );
  }

  Future<List<RecruitmentMessage>> loadMessages() {
    return RecruitmentRepository.fetchMessages(
      companyId: widget.profile.activeCompanyId,
      applicationId: widget.application.id,
    );
  }

  Future<void> refresh() async {
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

  void showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> copyPhone() async {
    final phone = widget.application.phone.trim();
    if (phone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Номер телефона скопирован')));
  }

  Future<void> callCandidate() async {
    final phone = widget.application.phone.trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showError('Не удалось открыть приложение для звонка');
    }
  }

  Future<void> openStoredFile({
    required String id,
    required String bucket,
    required String path,
    required String title,
    required bool isImage,
  }) async {
    if (openingId != null) return;
    setState(() => openingId = id);
    try {
      if (isImage) {
        final bytes = await RecruitmentRepository.downloadStoredFile(
          bucket: bucket,
          path: path,
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _RecruitmentImageViewer(title: title, bytes: bytes),
          ),
        );
        return;
      }

      final signedUrl = await RecruitmentRepository.createSignedFileUrl(
        bucket: bucket,
        path: path,
      );
      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось открыть файл');
    } catch (error) {
      showError(error.toString());
    } finally {
      if (mounted) setState(() => openingId = null);
    }
  }

  String documentFilePrefix(String documentType) {
    switch (documentType) {
      case 'passport_main':
        return 'Паспорт';
      case 'registration':
        return 'Прописка';
      case 'snils':
        return 'СНИЛС';
      case 'inn':
        return 'ИНН';
      case 'policy':
        return 'Полис';
      default:
        return 'Документ';
    }
  }

  String safeFilePart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String documentExtension(RecruitmentDocument document) {
    final original = document.originalName.trim().toLowerCase();
    final dot = original.lastIndexOf('.');
    if (dot >= 0 && dot < original.length - 1) {
      final extension = original.substring(dot + 1);
      if (<String>{'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(extension)) {
        return extension == 'jpeg' ? 'jpg' : extension;
      }
    }
    switch (document.mimeType) {
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

  String downloadName(RecruitmentDocument document) {
    final candidate = safeFilePart(widget.application.fullName);
    final prefix = documentFilePrefix(document.documentType);
    final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
    return '${prefix}_$suffix.${documentExtension(document)}';
  }

  int documentOrder(String documentType) {
    switch (documentType) {
      case 'passport_main':
        return 0;
      case 'registration':
        return 1;
      case 'snils':
        return 2;
      case 'inn':
        return 3;
      case 'policy':
        return 4;
      default:
        return 100;
    }
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

  Future<void> downloadAllDocuments(List<RecruitmentDocument> documents) async {
    if (downloadingArchive) return;
    final stored = documents.where((item) => item.isStored).toList()
      ..sort((first, second) {
        final order = documentOrder(
          first.documentType,
        ).compareTo(documentOrder(second.documentType));
        if (order != 0) return order;
        return first.createdAt.compareTo(second.createdAt);
      });
    if (stored.isEmpty) {
      showError('У кандидата пока нет загруженных документов');
      return;
    }

    setState(() => downloadingArchive = true);
    try {
      final archive = Archive();
      final pdfImages = <Uint8List>[];
      for (final document in stored) {
        final bytes = await RecruitmentRepository.downloadStoredFile(
          bucket: document.storageBucket,
          path: document.storagePath,
        );
        archive.addFile(
          ArchiveFile(downloadName(document), bytes.length, bytes),
        );
        if (document.isImage) pdfImages.add(bytes);
      }

      final candidate = safeFilePart(widget.application.fullName);
      final suffix = candidate.isEmpty ? 'Кандидат' : candidate;
      if (pdfImages.isNotEmpty) {
        final pdf = pw.Document(
          title: 'Документы ${widget.application.fullName}',
          author: 'AppСтрой',
        );
        for (final bytes in pdfImages) {
          final image = pw.MemoryImage(bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(24),
              build: (_) =>
                  pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
            ),
          );
        }
        final pdfBytes = await pdf.save();
        archive.addFile(
          ArchiveFile('Документы_$suffix.pdf', pdfBytes.length, pdfBytes),
        );
      }

      final encoded = ZipEncoder().encode(archive);
      if (encoded == null || encoded.isEmpty) {
        throw Exception('Не удалось собрать ZIP');
      }
      await FileSaver.instance.saveFile(
        name: 'Документы_$suffix',
        bytes: Uint8List.fromList(encoded),
        ext: 'zip',
        mimeType: MimeType.zip,
      );
    } catch (error) {
      showError('Не удалось скачать архив: $error');
    } finally {
      if (mounted) setState(() => downloadingArchive = false);
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (sending || text.isEmpty) return;
    setState(() => sending = true);
    try {
      await RecruitmentRepository.sendCandidateMessage(
        applicationId: widget.application.id,
        message: text,
      );
      messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сообщение отправлено кандидату')),
        );
      }
      await refresh();
    } catch (error) {
      showError('Не удалось отправить сообщение: $error');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  String formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes Б';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} КБ';
    return '${(kb / 1024).toStringAsFixed(1)} МБ';
  }

  Widget sectionTitle(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _detailText,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _detailMuted),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _detailMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _detailText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget summaryCard() {
    final application = widget.application;
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailPill(
                icon: Icons.flag_outlined,
                label: application.statusTitle,
              ),
              _DetailPill(
                icon: Icons.send_outlined,
                label: application.sourceTitle,
              ),
              if (application.citizenship.isNotEmpty)
                _DetailPill(
                  icon: Icons.public_outlined,
                  label: application.citizenship,
                ),
            ],
          ),
          SizedBox(height: 16),
          infoRow(Icons.work_outline_rounded, 'Вакансия', application.vacancy),
          infoRow(Icons.apartment_outlined, 'Объект', application.objectName),
          infoRow(Icons.badge_outlined, 'Опыт', application.experience),
          if (application.comment.isNotEmpty)
            infoRow(Icons.notes_rounded, 'Комментарий HR', application.comment),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: application.phone.isEmpty ? null : callCandidate,
                  icon: Icon(Icons.phone_outlined),
                  label: const Text('Позвонить'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: application.phone.isEmpty ? null : copyPhone,
                  icon: Icon(Icons.copy_rounded),
                  label: const Text('Копировать номер'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget documentCard(RecruitmentDocument document) {
    final waiting = !document.isStored;
    final downloading = downloadingIds.contains(document.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _detailSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _detailBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                              ? _detailWarning.withValues(alpha: 0.14)
                              : _detailSuccess.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          document.mimeType == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          color: waiting ? _detailWarning : _detailSuccess,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.title,
                              style: TextStyle(
                                color: _detailText,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              waiting
                                  ? 'Файл обрабатывается'
                                  : <String>[
                                      downloadName(document),
                                      if (formatBytes(
                                        document.sizeBytes,
                                      ).isNotEmpty)
                                        formatBytes(document.sizeBytes),
                                    ].join(' · '),
                              style: TextStyle(
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: waiting || openingId != null
                              ? null
                              : () => openStoredFile(
                                  id: document.id,
                                  bucket: document.storageBucket,
                                  path: document.storagePath,
                                  title: downloadName(document),
                                  isImage: document.isImage,
                                ),
                          icon: Icon(Icons.open_in_new_rounded),
                          label: const Text('Открыть'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: waiting || downloading
                              ? null
                              : () => downloadDocument(document),
                          icon: downloading
                              ? SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.download_rounded),
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

  Widget documentsSection() {
    return FutureBuilder<List<RecruitmentDocument>>(
      future: documentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DetailMessage(
            icon: Icons.error_outline_rounded,
            text: 'Не удалось загрузить документы: ${snapshot.error}',
          );
        }
        final documents = snapshot.data ?? const <RecruitmentDocument>[];
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
                  onPressed: downloadingArchive
                      ? null
                      : () => downloadAllDocuments(documents),
                  icon: downloadingArchive
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.folder_zip_outlined),
                  label: Text(
                    downloadingArchive
                        ? 'Собираем архив...'
                        : 'Скачать все ZIP · $storedCount',
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],
            ...documents.map(documentCard),
          ],
        );
      },
    );
  }

  Widget messageBubble(RecruitmentMessage message) {
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
          color: inbound ? _detailSurface : AppAdaptivePalette.selectedSurface,
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
                style: TextStyle(
                  color: _detailText,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (message.hasAttachment) ...[
              if (message.text.isNotEmpty) SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _detailSoft,
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
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            message.isStoredAttachment
                                ? attachmentTitle
                                : 'Вложение обрабатывается',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _detailText,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
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
                                    isImage: message.mimeType.startsWith(
                                      'image/',
                                    ),
                                  )
                                : null,
                            icon: Icon(Icons.visibility_outlined, size: 18),
                            label: const Text('Открыть'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed:
                                message.isStoredAttachment && !downloading
                                ? () => downloadMessageAttachment(message)
                                : null,
                            icon: downloading
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.download_rounded, size: 18),
                            label: const Text('Скачать'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${inbound ? 'Кандидат' : 'HR'} · ${formatDate(message.createdAt)}',
                style: TextStyle(
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

  Widget conversationSection() {
    return Container(
      height: 470,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _detailBorder),
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
                        text:
                            'Не удалось загрузить переписку: ${snapshot.error}',
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
                    reverse: false,
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
            decoration: BoxDecoration(
              color: _detailSurface,
              border: Border(top: BorderSide(color: _detailBorder)),
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
                            prefixIcon: Icon(Icons.telegram),
                            filled: true,
                            fillColor: _detailInput,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
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
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.send_rounded),
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

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Кандидат',
      showBackButton: true,
      subtitle: '',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Изменить данные',
        onPressed: () => Navigator.pop(context, 'edit'),
        icon: Icon(Icons.edit_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.application.fullName,
            style: TextStyle(
              color: _detailText,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          summaryCard(),
          SizedBox(height: 24),
          sectionTitle(
            'Документы',
            trailing: IconButton(
              tooltip: 'Обновить',
              onPressed: refresh,
              icon: Icon(Icons.refresh_rounded),
            ),
          ),
          documentsSection(),
          SizedBox(height: 24),
          sectionTitle('Переписка'),
          conversationSection(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RecruitmentImageViewer extends StatelessWidget {
  final String title;
  final Uint8List bytes;

  const _RecruitmentImageViewer({required this.title, required this.bytes});

  @override
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
                  icon: Icon(
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: <Shadow>[Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _detailSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _detailMuted),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _detailMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _detailSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _detailBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _detailMuted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _detailMuted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
