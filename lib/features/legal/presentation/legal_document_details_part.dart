part of 'legal_documents_screen.dart';

class LegalDocumentDetailsScreen extends StatefulWidget {
  final LegalDocument document;

  const LegalDocumentDetailsScreen({super.key, required this.document});

  @override
  State<LegalDocumentDetailsScreen> createState() => _LegalDocumentDetailsScreenState();
}

class _LegalDocumentDetailsScreenState extends State<LegalDocumentDetailsScreen> {
  late LegalDocument document;
  late Future<List<LegalFile>> filesFuture;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    filesFuture = LegalRepository.fetchDocumentFiles(document.id);
  }

  String date(DateTime? value) {
    if (value == null) return 'Не указано';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Widget line(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Color(0xFF6B7075), fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(builder: (_) => LegalDocumentEditorScreen(document: document)),
    );
    if (saved == true) {
      final fresh = await LegalRepository.fetchDocument(document.id);
      if (mounted) setState(() => document = fresh);
    }
  }

  Future<void> upload() async {
    final companyId = UserRepository.cachedProfile?.activeCompanyId ?? '';
    if (companyId.isEmpty || uploading) return;
    setState(() => uploading = true);
    try {
      await LegalRepository.pickAndUploadFiles(companyId: companyId, documentId: document.id);
      if (mounted) setState(() => filesFuture = LegalRepository.fetchDocumentFiles(document.id));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $error')));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка документа'),
        actions: [IconButton(onPressed: edit, icon: const Icon(Icons.edit_outlined))],
      ),
      body: AppPage(
        title: document.title,
        subtitle: '${document.statusTitle} • ${document.expiryTitle}',
        child: Column(
          children: [
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  line('Тип', document.documentType),
                  line('Номер', document.documentNumber),
                  line('Дата', date(document.createdOn)),
                  line('Подписан', date(document.signedOn)),
                  line('Действует до', date(document.expiresOn)),
                  line('Ответственный', document.responsibleName),
                  line('Сотрудник', document.employeeName),
                  line('Объект', document.objectName),
                  line('Контрагент', document.counterpartyName),
                  line('Следующий шаг', document.nextAction),
                  line('Срок действия', document.expiryTitle),
                  line('Комментарий', document.comment),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Файлы и версии', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FutureBuilder<List<LegalFile>>(
                    future: filesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final files = snapshot.data!;
                      if (files.isEmpty) return const Text('Файлы пока не добавлены');
                      return Column(
                        children: files.map((file) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file_rounded),
                          title: Text(file.originalName),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: () => LegalRepository.openFile(file),
                        )).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: uploading ? null : upload,
                    icon: uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('Добавить файлы'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
