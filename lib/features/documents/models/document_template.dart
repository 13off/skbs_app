class DocumentTemplateVersion {
  final String id;
  final String templateId;
  final String? companyId;
  final int versionNo;
  final String fileName;
  final String mimeType;
  final String sourceKind;
  final String assetPath;
  final String storagePath;
  final Map<String, dynamic> fieldSchema;
  final String notes;
  final bool isApproved;
  final DateTime createdAt;

  const DocumentTemplateVersion({
    required this.id,
    required this.templateId,
    required this.companyId,
    required this.versionNo,
    required this.fileName,
    required this.mimeType,
    required this.sourceKind,
    required this.assetPath,
    required this.storagePath,
    required this.fieldSchema,
    required this.notes,
    required this.isApproved,
    required this.createdAt,
  });

  factory DocumentTemplateVersion.fromMap(Map<String, dynamic> map) {
    return DocumentTemplateVersion(
      id: map['id']?.toString() ?? '',
      templateId: map['template_id']?.toString() ?? '',
      companyId: map['company_id']?.toString(),
      versionNo: int.tryParse(map['version_no']?.toString() ?? '') ?? 1,
      fileName: map['file_name']?.toString() ?? 'document.docx',
      mimeType: map['mime_type']?.toString() ??
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sourceKind: map['source_kind']?.toString() ?? 'asset',
      assetPath: map['asset_path']?.toString() ?? '',
      storagePath: map['storage_path']?.toString() ?? '',
      fieldSchema: map['field_schema'] is Map
          ? Map<String, dynamic>.from(map['field_schema'] as Map)
          : const <String, dynamic>{},
      notes: map['notes']?.toString() ?? '',
      isApproved: map['is_approved'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isAsset => sourceKind == 'asset';
  bool get isStorage => sourceKind == 'storage';

  List<String> get contentControls {
    final value = fieldSchema['content_controls'];
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool get supportsAutoFill => contentControls.isNotEmpty;
}

class DocumentTemplateRecord {
  final String id;
  final String? companyId;
  final String code;
  final String title;
  final String category;
  final String description;
  final String status;
  final String currentVersionId;
  final DateTime updatedAt;
  final List<DocumentTemplateVersion> versions;

  const DocumentTemplateRecord({
    required this.id,
    required this.companyId,
    required this.code,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.currentVersionId,
    required this.updatedAt,
    required this.versions,
  });

  factory DocumentTemplateRecord.fromMap(
    Map<String, dynamic> map, {
    required List<DocumentTemplateVersion> versions,
  }) {
    return DocumentTemplateRecord(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString(),
      code: map['code']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Документ',
      category: map['category']?.toString() ?? 'other',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'review',
      currentVersionId: map['current_version_id']?.toString() ?? '',
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      versions: versions,
    );
  }

  bool get isGlobal => companyId == null || companyId!.isEmpty;
  bool get isActive => status == 'active';
  bool get requiresReview => status == 'review';

  DocumentTemplateVersion? get currentVersion {
    for (final version in versions) {
      if (version.id == currentVersionId) return version;
    }
    return versions.isEmpty ? null : versions.first;
  }

  String get categoryTitle {
    return switch (category) {
      'hr' => 'Кадровые документы',
      'construction' => 'Строительные формы',
      'finance' => 'Финансовые документы',
      _ => 'Другие документы',
    };
  }
}
