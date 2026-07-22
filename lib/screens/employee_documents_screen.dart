import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/employee_documents_repository.dart';
import '../models/employee.dart';

class EmployeeDocumentsScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDocumentsScreen({super.key, required this.employee});

  @override
  State<EmployeeDocumentsScreen> createState() =>
      _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends State<EmployeeDocumentsScreen> {
  List<EmployeeDocument> documents = [];

  bool isLoading = false;
  bool isUploading = false;
  String? errorText;

  int _loadToken = 0;

  @override
  void initState() {
    super.initState();

    loadDocuments();
  }

  @override
  void dispose() {
    _loadToken++;
    super.dispose();
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Дата неизвестна';

    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  void sortDocuments() {
    documents.sort((a, b) {
      final aDate = a.updatedAt ?? DateTime(1970);
      final bDate = b.updatedAt ?? DateTime(1970);

      return bDate.compareTo(aDate);
    });
  }

  Future<void> loadDocuments({bool showLoader = true}) async {
    final employeeId = widget.employee.id;

    if (employeeId == null || employeeId.isEmpty) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    final requestToken = ++_loadToken;

    if (showLoader) {
      setState(() {
        isLoading = true;
        errorText = null;
      });
    } else {
      setState(() {
        errorText = null;
      });
    }

    try {
      final result = await EmployeeDocumentsRepository.listDocuments(
        employeeId,
      );

      if (!mounted || requestToken != _loadToken) return;

      setState(() {
        documents = result;
      });
    } catch (e) {
      if (!mounted || requestToken != _loadToken) return;

      setState(() {
        errorText = 'Ошибка загрузки документов: $e';
      });
    } finally {
      if (mounted && requestToken == _loadToken && showLoader) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> uploadDocuments() async {
    final employeeId = widget.employee.id;

    if (employeeId == null || employeeId.isEmpty) {
      setState(() {
        errorText = 'У сотрудника нет ID';
      });
      return;
    }

    setState(() {
      isUploading = true;
      errorText = null;
    });

    try {
      final uploadedDocuments =
          await EmployeeDocumentsRepository.pickAndUploadDocuments(employeeId);

      if (!mounted) return;

      if (uploadedDocuments.isEmpty) {
        setState(() {
          isUploading = false;
        });
        return;
      }

      setState(() {
        documents = [...uploadedDocuments, ...documents];
        sortDocuments();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Документы загружены')));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки файла: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  Future<void> openDocument(EmployeeDocument document) async {
    try {
      await EmployeeDocumentsRepository.openDocument(document);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка открытия файла: $e')));
    }
  }

  Widget buildDocumentsList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (documents.isEmpty) {
      return const Center(child: Text('Документы пока не загружены'));
    }

    return Column(
      children: documents.map((document) {
        return Card(
          elevation: 0,
          color: const Color(0xFFFFEEE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(
              document.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(formatDate(document.updatedAt)),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              openDocument(document);
            },
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Документы')),
      body: RefreshIndicator(
        onRefresh: () => loadDocuments(showLoader: false),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              widget.employee.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text('${widget.employee.position} • ${widget.employee.objectName}'),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Загрузка файлов',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Можно загрузить PDF, Word, Excel, JPG, PNG, WEBP, TXT.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isUploading ? null : uploadDocuments,
                      icon: isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: const Text('Загрузить документы'),
                    ),
                  ),
                ],
              ),
            ),

            if (errorText != null) ...[
              const SizedBox(height: 12),
              Text(errorText!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 18),

            buildDocumentsList(),
          ],
        ),
      ),
    );
  }
}
