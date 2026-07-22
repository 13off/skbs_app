import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/employee_documents_repository.dart';
import '../models/employee.dart';
import '../widgets/adaptive_detail_body.dart';

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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(
          child: Text(
            'Документы пока не загружены',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: documents.map((document) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppAdaptivePalette.border),
          ),
          child: ListTile(
            leading: Icon(
              Icons.description_outlined,
              color: AppAdaptivePalette.accent,
            ),
            title: Text(
              document.name,
              style: TextStyle(
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              formatDate(document.updatedAt),
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            ),
            trailing: Icon(
              Icons.open_in_new,
              color: AppAdaptivePalette.textMuted,
            ),
            onTap: () => openDocument(document),
          ),
        );
      }).toList(),
    );
  }

  Widget buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Загрузка файлов',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Можно загрузить PDF, Word, Excel, JPG, PNG, WEBP, TXT.',
            style: TextStyle(color: AppAdaptivePalette.textMuted),
          ),
          const SizedBox(height: 14),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Документы'),
      ),
      body: AdaptiveDetailBody(
        onRefresh: () => loadDocuments(showLoader: false),
        desktopMaxWidth: 1180,
        children: [
          Text(
            widget.employee.name,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.employee.position} • ${widget.employee.objectName}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final upload = buildUploadCard();
              final list = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorText != null) ...[
                    Text(
                      errorText!,
                      style: TextStyle(color: AppAdaptivePalette.danger),
                    ),
                    const SizedBox(height: 12),
                  ],
                  buildDocumentsList(),
                ],
              );

              if (!desktop) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [upload, const SizedBox(height: 18), list],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 380, child: upload),
                  const SizedBox(width: 20),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
