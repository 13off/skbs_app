part of 'legal_repository.dart';

abstract final class _LegalDocuments {
  static Future<List<LegalDocument>> fetchDocuments({
    String search = '',
    String? status,
    bool attentionOnly = false,
  }) async {
    final values = await Future.wait<dynamic>([
      _client
          .from('legal_documents')
          .select(
            'id, title, document_type, document_number, status, created_on, signed_on, valid_from, expires_on, responsible_user_id, employee_id, object_id, counterparty_id, task_id, legal_matter_id, comment, next_action, next_action_due_at, requires_foreman_action, requires_manager_approval, approval_status, created_at, updated_at, employees(fio), objects(name), legal_counterparties(name)',
          )
          .isFilter('archived_at', null)
          .order('updated_at', ascending: false),
      _LegalDirectories.responsibleNames(),
    ]);

    final rows = values[0] as List<dynamic>;
    final responsibleNames = values[1] as Map<String, String>;
    var documents = rows.map<LegalDocument>((value) {
      final row = _map(value);
      final responsibleId = row['responsible_user_id']?.toString() ?? '';
      return LegalDocument.fromMap(
        row,
        responsibleName: responsibleNames[responsibleId] ?? '',
      );
    }).toList();

    final cleanStatus = status?.trim() ?? '';
    if (cleanStatus.isNotEmpty) {
      documents = documents.where((item) => item.status == cleanStatus).toList();
    }
    if (attentionOnly) {
      documents = documents.where((item) => item.needsAttention).toList();
    }
    final query = search.trim().toLowerCase();
    if (query.isNotEmpty) {
      documents = documents.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.documentType.toLowerCase().contains(query) ||
            item.documentNumber.toLowerCase().contains(query) ||
            item.employeeName.toLowerCase().contains(query) ||
            item.objectName.toLowerCase().contains(query) ||
            item.counterpartyName.toLowerCase().contains(query);
      }).toList();
    }
    return documents;
  }

  static Future<LegalDocument> fetchDocument(String id) async {
    final documents = await fetchDocuments();
    return documents.firstWhere(
      (item) => item.id == id,
      orElse: () => throw Exception('Документ не найден'),
    );
  }

  static Future<LegalDocument> saveDocument({
    String? id,
    required String title,
    required String documentType,
    required String documentNumber,
    required String status,
    required DateTime createdOn,
    DateTime? signedOn,
    DateTime? validFrom,
    DateTime? expiresOn,
    String? responsibleUserId,
    String? employeeId,
    String? objectId,
    String? counterpartyId,
    String? taskId,
    String? legalMatterId,
    required String comment,
    required String nextAction,
    DateTime? nextActionDueAt,
    required bool requiresForemanAction,
    required bool requiresManagerApproval,
    required String approvalStatus,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'document_type': documentType.trim(),
      'document_number': documentNumber.trim(),
      'status': status,
      'created_on': _dateOnly(createdOn),
      'signed_on': _optionalDate(signedOn),
      'valid_from': _optionalDate(validFrom),
      'expires_on': _optionalDate(expiresOn),
      'responsible_user_id': _clean(responsibleUserId).isEmpty
          ? null
          : responsibleUserId,
      'employee_id': _clean(employeeId).isEmpty ? null : employeeId,
      'object_id': _clean(objectId).isEmpty ? null : objectId,
      'counterparty_id': _clean(counterpartyId).isEmpty
          ? null
          : counterpartyId,
      'task_id': _clean(taskId).isEmpty ? null : taskId,
      'legal_matter_id': _clean(legalMatterId).isEmpty ? null : legalMatterId,
      'comment': comment.trim(),
      'next_action': nextAction.trim(),
      'next_action_due_at': _optionalDateTime(nextActionDueAt),
      'requires_foreman_action': requiresForemanAction,
      'requires_manager_approval': requiresManagerApproval,
      'approval_status': requiresManagerApproval
          ? (approvalStatus == 'none' ? 'pending' : approvalStatus)
          : 'none',
      'updated_by': userId,
    };

    final String documentId;
    if (_clean(id).isEmpty) {
      payload['created_by'] = userId;
      final row = await _client
          .from('legal_documents')
          .insert(payload)
          .select('id')
          .single();
      documentId = row['id']?.toString() ?? '';
    } else {
      await _client.from('legal_documents').update(payload).eq('id', id!);
      documentId = id;
    }

    _notifyLegalChanged('legal_documents', entityId: documentId);

    if (requiresManagerApproval) {
      unawaited(
        NotificationRepository.add(
          title: 'Документ требует согласования',
          body: title.trim(),
          entityType: 'legal_document',
          entityId: documentId,
          targetRole: 'admin',
          requiresAction: true,
          dueAt: nextActionDueAt,
          priority: 'high',
        ),
      );
    } else if (requiresForemanAction && _clean(objectId).isNotEmpty) {
      final objects = await _LegalDirectories.fetchObjectDirectory();
      final objectName = objects
          .where((item) => item.id == objectId)
          .map((item) => item.title)
          .firstOrNull;
      unawaited(
        NotificationRepository.add(
          title: 'Требуется действие по документу',
          body: title.trim(),
          objectName: objectName,
          entityType: 'legal_document',
          entityId: documentId,
          targetRole: 'foreman',
          requiresAction: true,
          dueAt: nextActionDueAt,
        ),
      );
    }

    return fetchDocument(documentId);
  }

  static Future<void> approveDocument({
    required String documentId,
    required bool approved,
  }) async {
    await _client
        .from('legal_documents')
        .update(<String, dynamic>{
          'approval_status': approved ? 'approved' : 'rejected',
        })
        .eq('id', documentId);
    _notifyLegalChanged('legal_documents', entityId: documentId);
  }

  static Future<List<LegalFile>> fetchDocumentFiles(String documentId) async {
    final rows = await _client
        .from('legal_document_files')
        .select(
          'file_id, is_primary, app_files(id, original_name, bucket_name, storage_path, mime_type, size_bytes, created_at)',
        )
        .eq('document_id', documentId)
        .order('created_at', ascending: false);

    return rows.map<LegalFile>((value) {
      final row = _map(value);
      return LegalFile.fromMap(_map(row['app_files']));
    }).where((file) => file.id.isNotEmpty).toList();
  }

  static Future<List<LegalFile>> pickAndUploadFiles({
    required String companyId,
    required String documentId,
  }) async {
    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Документы',
          extensions: <String>[
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'txt',
          ],
        ),
      ],
    );
    if (files.isEmpty) return const <LegalFile>[];

    final uploaded = <LegalFile>[];
    final userId = _client.auth.currentUser?.id;
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final bytes = await file.readAsBytes();
      final originalName = file.name.trim().isEmpty ? 'document' : file.name.trim();
      final dot = originalName.lastIndexOf('.');
      final extension = dot >= 0 ? originalName.substring(dot).toLowerCase() : '';
      final safeName =
          '${DateTime.now().microsecondsSinceEpoch}_${index + 1}$extension';
      final path = '$companyId/$documentId/$safeName';

      await _client.storage.from(legalBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: file.mimeType,
              upsert: false,
            ),
          );

      try {
        final row = await _client
            .from('app_files')
            .insert(<String, dynamic>{
              'bucket_name': legalBucket,
              'storage_path': path,
              'original_name': originalName,
              'mime_type': file.mimeType ?? '',
              'size_bytes': bytes.length,
              'uploaded_by': userId,
            })
            .select(
              'id, original_name, bucket_name, storage_path, mime_type, size_bytes, created_at',
            )
            .single();

        final savedFile = LegalFile.fromMap(row);
        await _client.from('legal_document_files').insert(<String, dynamic>{
          'document_id': documentId,
          'file_id': savedFile.id,
          'is_primary': uploaded.isEmpty,
        });
        uploaded.add(savedFile);
      } catch (_) {
        await _client.storage.from(legalBucket).remove(<String>[path]);
        rethrow;
      }
    }

    _notifyLegalChanged('legal_document_files', entityId: documentId);
    unawaited(
      NotificationRepository.add(
        title: 'К документу добавлены файлы',
        body: '${uploaded.length} шт.',
        entityType: 'legal_document_file',
        entityId: documentId,
        targetRole: 'lawyer',
      ),
    );
    return uploaded;
  }

  static Future<void> openFile(LegalFile file) async {
    final url = await _client.storage
        .from(file.bucketName)
        .createSignedUrl(file.storagePath, 60 * 10);
    html.window.open(url, '_blank');
  }
}
