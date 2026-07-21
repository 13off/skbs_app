import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/candidate_onboarding_candidate.dart';
import '../models/candidate_onboarding_models.dart';

abstract final class CandidateOnboardingRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String storageBucket = 'recruitment-documents';
  static const int maxSignedFileBytes = 20 * 1024 * 1024;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static void _notify(String applicationId) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.recruitment},
      context: <String, dynamic>{
        'table': 'recruitment_onboarding_forms',
        'entity_id': applicationId,
      },
    );
  }

  static Future<List<CandidateOnboardingCandidate>> fetchCandidates({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <CandidateOnboardingCandidate>[];
    final rows = await _client
        .from('recruitment_applications')
        .select(
          'id, company_id, employee_id, full_name, phone, citizenship, '
          'position_title, status, ready_date, consent_personal_data, objects(name)',
        )
        .eq('company_id', cleanCompanyId)
        .isFilter('archived_at', null)
        .inFilter('status', const <String>[
          'approved',
          'ticket_request',
          'in_transit',
          'arrived',
          'hired',
        ])
        .order('updated_at', ascending: false);
    return rows
        .map<CandidateOnboardingCandidate>(
          (row) => CandidateOnboardingCandidate.fromMap(_map(row)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<CandidateOnboardingForm>> fetchForms({
    required String companyId,
    required String applicationId,
  }) async {
    final rows = await _client
        .from('recruitment_onboarding_forms')
        .select()
        .eq('company_id', companyId.trim())
        .eq('application_id', applicationId.trim())
        .order('form_code');
    return rows
        .map<CandidateOnboardingForm>(
          (row) => CandidateOnboardingForm.fromMap(_map(row)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> recordGenerated({
    required CandidateOnboardingCandidate candidate,
    required Map<String, List<String>> missingFieldsByForm,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final userId = _client.auth.currentUser?.id;
    final rows = candidateOnboardingFormCodes.map((code) {
      return <String, dynamic>{
        'company_id': candidate.companyId,
        'application_id': candidate.id,
        'employee_id': candidate.employeeId.trim().isEmpty
            ? null
            : candidate.employeeId.trim(),
        'form_code': code,
        'status': 'ready_to_print',
        'missing_fields': missingFieldsByForm[code] ?? const <String>[],
        'generated_at': now,
        'updated_at': now,
        'updated_by': userId,
        'created_by': userId,
      };
    }).toList(growable: false);
    await _client.from('recruitment_onboarding_forms').upsert(
          rows,
          onConflict: 'company_id,application_id,form_code',
        );
    _notify(candidate.id);
  }

  static Future<void> markPrinted(CandidateOnboardingForm form) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('recruitment_onboarding_forms')
        .update(<String, dynamic>{
          'status': 'printed',
          'printed_at': now,
          'updated_at': now,
          'updated_by': _client.auth.currentUser?.id,
        })
        .eq('company_id', form.companyId)
        .eq('id', form.id);
    _notify(form.applicationId);
  }

  static Future<void> uploadSigned({
    required CandidateOnboardingForm form,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) throw StateError('Выбран пустой файл');
    if (bytes.length > maxSignedFileBytes) {
      throw StateError('Подписанный файл больше 20 МБ');
    }
    final extension = _safeExtension(fileName, mimeType);
    final path = '${form.companyId}/${form.applicationId}/signed/'
        '${form.formCode}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from(storageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client
          .from('recruitment_onboarding_forms')
          .update(<String, dynamic>{
            'status': 'signed',
            'signed_at': now,
            'storage_bucket': storageBucket,
            'storage_path': path,
            'original_name': fileName.trim(),
            'mime_type': mimeType,
            'size_bytes': bytes.length,
            'updated_at': now,
            'updated_by': _client.auth.currentUser?.id,
          })
          .eq('company_id', form.companyId)
          .eq('id', form.id);
    } catch (_) {
      await _client.storage.from(storageBucket).remove(<String>[path]);
      rethrow;
    }
    _notify(form.applicationId);
  }

  static Future<String> signedUrl(CandidateOnboardingForm form) {
    if (!form.hasSignedFile) {
      throw StateError('Подписанный экземпляр ещё не загружен');
    }
    return _client.storage
        .from(form.storageBucket)
        .createSignedUrl(form.storagePath, 300);
  }

  static Future<void> linkEmployee({
    required CandidateOnboardingCandidate candidate,
    required String employeeId,
  }) async {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) throw StateError('Сотрудник не создан');
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('recruitment_applications')
        .update(<String, dynamic>{
          'employee_id': cleanEmployeeId,
          'status': 'hired',
          'updated_at': now,
        })
        .eq('company_id', candidate.companyId)
        .eq('id', candidate.id);
    await _client
        .from('recruitment_onboarding_forms')
        .update(<String, dynamic>{
          'employee_id': cleanEmployeeId,
          'updated_at': now,
          'updated_by': _client.auth.currentUser?.id,
        })
        .eq('company_id', candidate.companyId)
        .eq('application_id', candidate.id);
    await _client.from('recruitment_status_history').insert(<String, dynamic>{
      'company_id': candidate.companyId,
      'application_id': candidate.id,
      'status': 'hired',
      'source': 'appstroy_onboarding',
      'created_by': _client.auth.currentUser?.id,
    });
    _notify(candidate.id);
  }

  static String _safeExtension(String name, String mimeType) {
    final cleanName = name.trim().toLowerCase();
    final index = cleanName.lastIndexOf('.');
    if (index >= 0 && index < cleanName.length - 1) {
      final ext = cleanName.substring(index + 1).replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (<String>{'pdf', 'jpg', 'jpeg', 'png', 'webp', 'docx'}.contains(ext)) {
        return ext == 'jpeg' ? 'jpg' : ext;
      }
    }
    return switch (mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        'docx',
      _ => 'jpg',
    };
  }
}
